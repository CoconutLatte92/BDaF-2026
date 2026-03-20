# 🪙 BDaF 2026 Lab03 — Signature-Based Token Approval

> 實作簡化版 EIP-2612 簽名授權機制，讓代幣持有人可**離線簽署授權**，由第三方代為提交上鏈。

---

## 📁 專案結構

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

## ⚡ 快速開始

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

## 📜 合約說明

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

## 🧪 測試案例

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

## 📝 Write-up

### 1. Why are signatures useful in Ethereum applications?

在 Ethereum 中，大部分操作都需要使用者親自送出交易並支付 gas。但簽名機制讓使用者可以**在鏈下（off-chain）對訊息進行數位簽名**，再由他人代為提交上鏈。

這帶來幾個重要優點：

- **無需持有 ETH 的使用者也能授權操作**：例如，只持有 ERC20 代幣但沒有 ETH 的用戶，可以簽署 permit 授權，由有 ETH 的第三方幫忙提交，實現「無 gas 費用體驗」（gasless transaction）。
- **節省交易成本**：可將多步操作合併（approve + transferFrom → permit + transferFrom），減少鏈上交易數量。
- **更好的用戶體驗**：DApp 可讓用戶只需簽名（MetaMask popup），無需等待鏈上確認，後端或 relayer 再統一上鏈。

---

### 2. What is a replay attack?

重放攻擊（Replay Attack）是指攻擊者**截取一個合法的簽名，並在不同時間或不同情境下重複使用**，達到非預期的效果。

舉例來說，若 Alice 簽署了「授權 Bob 使用 500 PMT」的訊息，Bob 在執行一次後，如果合約沒有防護機制，Bob 可以再次提交同一份簽名來重複獲得授權。此外，若簽名內容未包含合約地址，同一份簽名可能在不同地址的同名合約上都有效，造成**跨合約重放**。

---

### 3. How does your contract prevent replay attacks?

本合約使用三種機制防止重放攻擊：

**① Nonce（一次性使用計數器）**

合約維護 `mapping(address => uint256) public nonces`。每次成功執行 `permit()` 後，`nonces[owner]++`。簽名內容包含 `nonce` 欄位，合約要求 `nonce == nonces[owner]`——一旦舊 nonce 的簽名被使用，再次提交相同簽名會因 nonce 不符而 revert，徹底防止重放。

**② 合約地址綁定（address(this)）**

簽名的 hash 中包含 `address(this)`，使簽名只對**這個特定合約**有效。即使相同邏輯的合約部署在不同地址，簽名也無法跨合約使用。

**③ Deadline（有效期限）**

簽名包含 `deadline`，合約驗證 `block.timestamp <= deadline`。過期的簽名即使 nonce 正確也無法執行，降低簽名外洩的風險窗口。

