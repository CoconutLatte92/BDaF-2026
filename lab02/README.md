# Lab02 - Peer to Peer Token Trade

P2P ERC20 代幣交易智慧合約，支援限時掛單、交易結算、過期取消與 0.1% 手續費機制。

## 專案結構

```text
lab02/
├── src/
│   ├── AlphaToken.sol    # ERC20 代幣 A
│   ├── BetaToken.sol     # ERC20 代幣 B
│   └── TokenTrade.sol    # 交易合約
├── test/
│   └── TokenTrade.t.sol  # 測試檔案
├── script/
│   ├── Deploy.s.sol           # 部署腳本
│   ├── AliceSetupTrade.s.sol  # Alice 掛單
│   ├── BobSettleTrade.s.sol   # Bob 結算
│   └── OwnerWithdrawFee.s.sol # Owner 提領手續費
├── foundry.toml
├── remappings.txt
└── README.md
```

## 🛠 環境設置

### 1. 安裝 Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 安裝依賴

```bash
forge install
```

### 3. 設置環境變數

請自行建立 `.env` 檔案，填入以下內容：

```bash
PRIVATE_KEY=0x你的Owner私鑰
ALICE_PRIVATE_KEY=0x你的Alice私鑰
BOB_PRIVATE_KEY=0x你的Bob私鑰
RPC_URL=https://garfield-testnet.zircuit.com

ALPHA_TOKEN=0xD71F27AE438F0978f16459780704699d79FD0f51
BETA_TOKEN=0x538AfE4E65183eAD18c103371c62dc4707Bf3311
TRADE_CONTRACT=0xFD4424266C0d80F47D4f7486281f09f573A65F1E
TRADE_ID=0
ETHERSCAN_API_KEY="0"
```

在 WSL / Linux 中載入環境變數：

```bash
set -a
source .env
set +a
```

### 4. 獲取測試 ETH

1. 前往 [Alchemy Sepolia Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
2. 獲取 Sepolia ETH
3. 前往 [Zircuit Bridge](https://bridge.garfield-testnet.zircuit.com/)
4. 將 Sepolia ETH 橋接到 Zircuit Garfield Testnet

---

## 執行測試

```bash
forge test
```

若要顯示更詳細輸出：

```bash
forge test -vvv
```

### 測試清單

| 測試名稱                                 | 說明           |
| ------------------------------------ | ------------ |
| `test_Deployment`                    | 合約正確部署       |
| `test_TokenSupply`                   | 代幣總供應量正確     |
| `test_Constructor_ZeroAddress`       | 零地址建構參數應失敗   |
| `test_Constructor_SameToken`         | 相同代幣地址建構應失敗  |
| `test_SetupTrade`                    | 成功建立交易       |
| `test_SetupTrade_EmitsEvent`         | 建立交易時觸發事件    |
| `test_SetupTrade_InvalidToken`       | 無效代幣應失敗      |
| `test_SetupTrade_ZeroAmount`         | 零數量應失敗       |
| `test_SetupTrade_InvalidExpiry`      | 過期時間無效應失敗    |
| `test_SettleTrade`                   | 成功結算交易       |
| `test_SettleTrade_EmitsEvent`        | 結算時觸發事件      |
| `test_SettleTrade_NotFound`          | 結算不存在的交易應失敗  |
| `test_SettleTrade_AlreadyFulfilled`  | 結算已完成交易應失敗   |
| `test_SettleTrade_Expired`           | 結算過期交易應失敗    |
| `test_CancelExpiredTrade`            | 取消過期交易並取回代幣  |
| `test_CancelExpiredTrade_NotSeller`  | 非賣家不能取消過期交易  |
| `test_CancelExpiredTrade_NotExpired` | 未過期交易不能取消    |
| `test_FeeCalculation`                | 0.1% 手續費計算正確 |
| `test_WithdrawFee`                   | Owner 提領手續費  |
| `test_WithdrawFee_NotOwner`          | 非 Owner 不能提領 |
| `test_AccumulateFees`                | 累積多筆手續費      |
| `test_MultipleTradesIdIncrement`     | 多筆交易 ID 遞增   |
| `test_ReverseTradeDirection`         | 反向交易測試       |

---

## 部署到 Zircuit Garfield Testnet

### 部署合約

```bash
set -a
source .env
set +a

forge script script/Deploy.s.sol:DeployAll \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvvv
```

部署完成後，請記錄三個合約地址。

---

## 代幣分配

由於 `AlphaToken` 與 `BetaToken` 在部署時都先鑄造給部署者（Owner），因此在執行交易流程前，需要先由 Owner 轉代幣給 Alice 與 Bob。

### 轉 ALPHA 給 Alice

```bash
ALICE_ADDR=$(cast wallet address --private-key $ALICE_PRIVATE_KEY)
ALPHA_TO_ALICE=$(cast to-wei 2000 ether)

cast send $ALPHA_TOKEN \
  "transfer(address,uint256)" \
  $ALICE_ADDR \
  $ALPHA_TO_ALICE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### 轉 BETA 給 Bob

```bash
BOB_ADDR=$(cast wallet address --private-key $BOB_PRIVATE_KEY)
BETA_TO_BOB=$(cast to-wei 1000 ether)

cast send $BETA_TOKEN \
  "transfer(address,uint256)" \
  $BOB_ADDR \
  $BETA_TO_BOB \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 執行完整流程

### 步驟 1：Alice 設置交易

```bash
forge script script/AliceSetupTrade.s.sol:AliceSetupTrade \
  --rpc-url $RPC_URL \
  --broadcast -vvvv
```

📌 本次實際交易哈希：

`0x4fbdd1434056aa58ffc6569ac89827dd069dc5827a237f7098b4692fcae19c91`

### 步驟 2：Bob 結算交易

```bash
forge script script/BobSettleTrade.s.sol:BobSettleTrade \
  --rpc-url $RPC_URL \
  --broadcast -vvvv
```

📌 本次實際交易哈希：

`0xed241b26c68c9c6f95963ed95c485f4ffc61e4ba2e1a0a2063f4b9bdc3ae84d2`

### 步驟 3：Owner 提領手續費

```bash
forge script script/OwnerWithdrawFee.s.sol:OwnerWithdrawFee \
  --rpc-url $RPC_URL \
  --broadcast -vvvv
```

📌 本次實際交易哈希：

`0x3b36ed9194f6e653ed8995c83f97f347782d17abe1490d237262f07a802aa454`

---

## 合約地址

* **AlphaToken**: `0xD71F27AE438F0978f16459780704699d79FD0f51`
* **BetaToken**: `0x538AfE4E65183eAD18c103371c62dc4707Bf3311`
* **TokenTrade**: `0xFD4424266C0d80F47D4f7486281f09f573A65F1E`

---

## 合約驗證

本專案使用 **Sourcify** 提交合約驗證。

### 驗證 AlphaToken

```bash
forge verify-contract 0xD71F27AE438F0978f16459780704699d79FD0f51 src/AlphaToken.sol:AlphaToken \
  --chain-id 48898 \
  --verifier sourcify \
  --verifier-url https://sourcify.dev/server
```

### 驗證 BetaToken

```bash
forge verify-contract 0x538AfE4E65183eAD18c103371c62dc4707Bf3311 src/BetaToken.sol:BetaToken \
  --chain-id 48898 \
  --verifier sourcify \
  --verifier-url https://sourcify.dev/server
```

### 驗證 TokenTrade

先編碼 constructor 參數：

```bash
cast abi-encode "constructor(address,address)" \
  0xD71F27AE438F0978f16459780704699d79FD0f51 \
  0x538AfE4E65183eAD18c103371c62dc4707Bf3311
```

本次編碼結果：

```bash
0x000000000000000000000000d71f27ae438f0978f16459780704699d79fd0f51000000000000000000000000538afe4e65183ead18c103371c62dc4707bf3311
```

接著執行驗證：

```bash
forge verify-contract 0xFD4424266C0d80F47D4f7486281f09f573A65F1E src/TokenTrade.sol:TokenTrade \
  --chain-id 48898 \
  --verifier sourcify \
  --verifier-url https://sourcify.dev/server \
  --constructor-args 0x000000000000000000000000d71f27ae438f0978f16459780704699d79fd0f51000000000000000000000000538afe4e65183ead18c103371c62dc4707bf3311
```

### 驗證工作 ID

* AlphaToken: `bd8fbbd0-71ef-436e-a0ff-ffbddf287b5a`
* BetaToken: `f392ca31-af47-4915-a51f-a6ec6af97a5a`
* TokenTrade: `885059a2-f590-41f7-8771-2a571c872f0a`

---

## 手續費機制說明

本專案的手續費邏輯如下：

* 買家收到完整的 `inputToken`
* 賣家收到 `outputToken - 0.1% fee`
* 手續費累積在 `outputToken` 側
* Owner 可透過 `withdrawFee()` 提領所有累積手續費

例如：

* Alice 賣出 `1000 ALPHA`
* 想換得 `500 BETA`
* Bob 結算後：

  * Bob 收到完整 `1000 ALPHA`
  * Alice 收到 `499.5 BETA`
  * 合約累積 `0.5 BETA` 作為 fee

---

## 提交清單

* [x] 三個合約地址

  * AlphaToken: `0xD71F27AE438F0978f16459780704699d79FD0f51`
  * BetaToken: `0x538AfE4E65183eAD18c103371c62dc4707Bf3311`
  * TokenTrade: `0xFD4424266C0d80F47D4f7486281f09f573A65F1E`
* [x] 三個交易哈希

  * Alice sets up trade: `0x4fbdd1434056aa58ffc6569ac89827dd069dc5827a237f7098b4692fcae19c91`
  * Bob settles trade: `0xed241b26c68c9c6f95963ed95c485f4ffc61e4ba2e1a0a2063f4b9bdc3ae84d2`
  * Owner withdraw fee: `0x3b36ed9194f6e653ed8995c83f97f347782d17abe1490d237262f07a802aa454`
* [x] Foundry 測試通過
* [x] 合約已提交驗證

---

## 相關連結

* [Zircuit Garfield Explorer](https://explorer.garfield-testnet.zircuit.com/)
* [Zircuit Bridge](https://bridge.garfield-testnet.zircuit.com/)
* [Alchemy Sepolia Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
