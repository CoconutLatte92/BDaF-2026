# 🪙 BDaF 2026 Lab03 — Signature-Based Token Approval

## 專案結構

```
lab03/
├── src/
│   └── PermitToken.sol        # ERC20 合約（含 permit、nonce、deadline）
├── test/
│   └── PermitToken.t.sol      # 8 個測試案例（Foundry）
├── script/
│   └── Deploy.s.sol           # 部署腳本 + 完整流程示範
├── foundry.toml               # Foundry 專案設定
├── remappings.txt             # 路徑對應（修正 VS Code 紅線）
└── .env.example               # 環境變數範本
```

---

## 快速開始

```bash
# 1. 安裝 OpenZeppelin 依賴
forge install OpenZeppelin/openzeppelin-contracts

# 2. 執行測試
forge test -vv

# 3. 部署（填寫 .env 後）
cp .env.example .env
# 編輯 .env，填入私鑰與 RPC
source .env
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

---

## 合約說明

### PermitToken（PMT）

| 項目 | 內容 |
|------|------|
| 代幣名稱 | PermitToken |
| 代幣符號 | PMT |
| 總供應量 | 100,000,000 PMT |
| 精度 | 18 decimals |
| 標準 | ERC20（OpenZeppelin v5） |

**核心函式：**

```solidity
// 以鏈下簽名更新授權額度
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
) public

// 計算 permit 訊息雜湊（供鏈下簽名使用）
function getPermitHash(
    address owner, address spender,
    uint256 value, uint256 nonce, uint256 deadline
) public view returns (bytes32)

// 查詢地址當前 nonce
mapping(address => uint256) public nonces;
```

---

## 測試案例

執行 `forge test -vv` 應全數通過：

| 測試函式 | 測試目的 |
|---------|---------|
| `test_ValidSignature_PermitSucceeds` | 有效簽名成功執行 permit |
| `test_WrongSigner_PermitFails` | 錯誤簽署者（冒充）被拒絕 |
| `test_NonceIncrementsAfterPermit` | permit 後 nonce 遞增 |
| `test_ReplayAttack_SameSignatureFails` | 重放舊簽名失敗 |
| `test_ExpiredSignature_Fails` | 過期簽名失敗 |
| `test_AllowanceCorrectAfterPermit` | allowance 正確更新 |
| `test_TransferFromSucceedsAfterPermit` | permit 後 transferFrom 成功 |
| `test_TransferFromFailsWithoutPermit` | 無 permit 時 transferFrom 失敗 |

---

## Write-up

### 1. Why are signatures useful in Ethereum applications?

在 Ethereum 中，簽名機制讓使用者可以在off-chain時對訊息進行數位簽名，再由其他人代為提交上鏈。主要優點包括：無需持有 ETH 的使用者也能授權操作（gasless transaction）、減少鏈上交易數量節省成本，以及提供更好的用戶體驗（僅需簽名，無需等待鏈上確認）。

---

### 2. What is a replay attack?

重送攻擊是指攻擊者截取一個他人的簽名，並在不同時間或不同情境下重複使用，達到攻擊的效果。例如，Alice 簽署授權後，若合約無防護機制，任何人拿到這份簽名都可以無限重複執行授權，或在不同合約地址上重放同一份簽名（跨合約重放）。

---

### 3. How does your contract prevent replay attacks?

本合約使用三種機制:首先在每次成功 permit 後 nonces[owner]++ ，舊簽名因 nonce 不同而 revert，再來是hash 包含 address(this)，使簽名只對此合約有效，避免跨合約重送，最後讓簽名包含有效期限，過期後即使 nonce 正確也無法執行。

