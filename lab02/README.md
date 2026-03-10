# 🔄 Lab02 - Peer to Peer Token Trade

P2P ERC20 代幣交易智能合約，支援限時掛單與 0.1% 手續費機制。

## 📁 專案結構

```
lab02-token-trade/
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
│   └── OwnerWithdrawFee.s.sol # 提領手續費
├── foundry.toml
└── .env.example
```

## 🛠 環境設置

### 1. 安裝 Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 安裝依賴

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### 3. 設置環境變數

```bash
cp .env.example .env
# 編輯 .env 填入你的私鑰
```

### 4. 獲取測試 ETH

1. 前往 [Alchemy Sepolia Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
2. 獲取 Sepolia ETH
3. 前往 [Zircuit Bridge](https://bridge.garfield-testnet.zircuit.com/) 
4. 將 Sepolia ETH 橋接到 Zircuit Testnet

## 🧪 執行測試

```bash
forge test -vvv
```

### 測試清單

| 測試名稱 | 說明 |
|---------|------|
| `test_Deployment` | 合約正確部署 |
| `test_TokenSupply` | 代幣總供應量正確 |
| `test_SetupTrade` | 成功建立交易 |
| `test_SetupTrade_InvalidToken` | 無效代幣應失敗 |
| `test_SetupTrade_ZeroAmount` | 零數量應失敗 |
| `test_SetupTrade_InvalidExpiry` | 過期時間無效應失敗 |
| `test_SettleTrade` | 成功結算交易 |
| `test_SettleTrade_EmitsEvent` | 結算時觸發事件 |
| `test_SettleTrade_NotFound` | 結算不存在的交易應失敗 |
| `test_SettleTrade_AlreadyFulfilled` | 結算已完成交易應失敗 |
| `test_SettleTrade_Expired` | 結算過期交易應失敗 |
| `test_FeeCalculation` | 0.1% 手續費計算正確 |
| `test_WithdrawFee` | Owner 提領手續費 |
| `test_WithdrawFee_NotOwner` | 非 Owner 不能提領 |
| `test_CancelExpiredTrade` | 取消過期交易並取回代幣 |
| `test_CancelExpiredTrade_NotExpired` | 未過期交易不能取消 |
| `test_MultipleTradesIdIncrement` | 多筆交易 ID 遞增 |
| `test_AccumulateFees` | 累積多筆手續費 |
| `test_ReverseTradeDirection` | 反向交易測試 |

## 🚀 部署到 Zircuit Testnet

### 部署合約

```bash
source .env

forge script script/Deploy.s.sol:DeployAll \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --broadcast \
  -vvvv
```

記錄部署的合約地址：
- AlphaToken: `0x...`
- BetaToken: `0x...`
- TokenTrade: `0x...`

### 驗證合約

```bash
# 驗證 AlphaToken
forge verify-contract <ALPHA_ADDRESS> src/AlphaToken.sol:AlphaToken \
  --chain-id 48899 \
  --verifier-url https://explorer.garfield-testnet.zircuit.com/api \
  --verifier blockscout

# 驗證 BetaToken
forge verify-contract <BETA_ADDRESS> src/BetaToken.sol:BetaToken \
  --chain-id 48899 \
  --verifier-url https://explorer.garfield-testnet.zircuit.com/api \
  --verifier blockscout

# 驗證 TokenTrade
forge verify-contract <TRADE_ADDRESS> src/TokenTrade.sol:TokenTrade \
  --chain-id 48899 \
  --verifier-url https://explorer.garfield-testnet.zircuit.com/api \
  --verifier blockscout \
  --constructor-args $(cast abi-encode "constructor(address,address)" <ALPHA_ADDRESS> <BETA_ADDRESS>)
```

## 📝 執行完整流程

### 準備工作

設置環境變數：

```bash
export ALPHA_TOKEN=<你的 AlphaToken 地址>
export BETA_TOKEN=<你的 BetaToken 地址>
export TRADE_CONTRACT=<你的 TokenTrade 地址>
```

### 步驟 1: 分配代幣給 Alice 和 Bob

```bash
# 轉 Alpha 給 Alice
cast send $ALPHA_TOKEN "transfer(address,uint256)" <ALICE_ADDRESS> 10000000000000000000000 \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --private-key $PRIVATE_KEY

# 轉 Beta 給 Bob
cast send $BETA_TOKEN "transfer(address,uint256)" <BOB_ADDRESS> 10000000000000000000000 \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --private-key $PRIVATE_KEY
```

### 步驟 2: Alice 設置交易

```bash
export ALICE_PRIVATE_KEY=<Alice 的私鑰>

forge script script/AliceSetupTrade.s.sol:AliceSetupTrade \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --broadcast \
  -vvvv
```

📌 記錄交易哈希：`0x...`

### 步驟 3: Bob 結算交易

```bash
export BOB_PRIVATE_KEY=<Bob 的私鑰>
export TRADE_ID=0

forge script script/BobSettleTrade.s.sol:BobSettleTrade \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --broadcast \
  -vvvv
```

📌 記錄交易哈希：`0x...`

### 步驟 4: Owner 提領手續費

```bash
forge script script/OwnerWithdrawFee.s.sol:OwnerWithdrawFee \
  --rpc-url https://zircuit1-testnet.p2pify.com \
  --broadcast \
  -vvvv
```

📌 記錄交易哈希：`0x...`

## 📋 提交清單

- [ ] 三個合約地址
  - AlphaToken: `0x...`
  - BetaToken: `0x...`
  - TokenTrade: `0x...`
- [ ] 三個交易哈希
  - Alice sets up trade: `0x...`
  - Bob settles trade: `0x...`
  - Owner withdraw fee: `0x...`
- [ ] 所有合約已驗證

## 🔗 相關連結

- [Zircuit Explorer](https://explorer.garfield-testnet.zircuit.com/)
- [Zircuit Bridge](https://bridge.garfield-testnet.zircuit.com/)
- [Alchemy Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
