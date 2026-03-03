# EthVault -- Lab01

## 📝 專案描述

EthVault 是一個使用 Solidity 編寫的 ETH 保險庫智能合約。

此合約允許任何用戶存入 ETH，但只有合約的 OWNER（部署者）可以提款。
包含事件記錄、自定義錯誤和重入保護機制。

---

## 🛠️ 技術規格

| 項目 | 說明 |
|------|------|
| Solidity 版本 | ^0.8.20 |
| 開發框架 | Foundry |
| 測試工具 | forge-std |

---

## 📁 專案結構

```
lab01/
├── src/
│    └── EthVault.sol      # 主合約
├── test/
│    └── EthVault.t.sol    # 測試檔案
├── foundry.toml           # Foundry 配置
└── README.md              # 本文件
```

---

## 🚀 安裝與執行

### 下載專案

```bash
git clone https://github.com/CoconutLatte92/BDaF-2026.git
cd BDaF-2026/lab01
forge install
forge build
forge test
```

### 執行測試

```bash
# 執行所有測試
forge test

# 顯示詳細輸出
forge test -vvv

# 顯示 Gas 報告
forge test --gas-report
```

---

## ✅ 測試覆蓋詳情

共 **16 個測試**，分為 5 個群組：

---

### Group A — 存款測試（4 個）

驗證 ETH 接收行為：

| # | 測試名稱 | 說明 |
|---|----------|------|
| 1 | `test_SingleDeposit` | 單次存款成功，發出 Deposit 事件，餘額正確增加 |
| 2 | `test_MultipleDeposits` | 多次存款累加，每次都發出事件 |
| 3 | `test_DepositsFromDifferentSenders` | 不同地址存款都被接受，事件正確記錄發送者 |
| 4 | `test_DepositZero` | 存入 0 ETH 也成功並發出事件 |

---

### Group B — Owner 提款測試（3 個）

驗證 Owner 提款行為：

| # | 測試名稱 | 說明 |
|---|----------|------|
| 5 | `test_OwnerPartialWithdraw` | Owner 可以提取部分餘額，發出 Weethdraw 事件 |
| 6 | `test_OwnerFullWithdraw` | Owner 可以提取全部餘額，合約餘額歸零 |
| 7 | `test_WithdrawAfterMultipleDeposits` | 多次存款後提款，餘額正確減少 |

---

### Group C — 未授權提款測試（2 個）

驗證非 Owner 行為：

| # | 測試名稱 | 說明 |
|---|----------|------|
| 8 | `test_UnauthorizedWithdrawDoesNotTransfer` | 非 Owner 提款不會 revert，但資金不轉移 |
| 9 | `test_UnauthorizedWithdrawNoTransfer` | 發出 UnauthorizedWithdrawAttempt 事件，餘額不變 |

---

### Group D — 邊界情況測試（6 個）

驗證各種邊界情況：

| # | 測試名稱 | 說明 |
|---|----------|------|
| 10 | `test_WithdrawMoreThanBalance` | 提款超過餘額會 revert，拋出 InsufficientBalance 錯誤 |
| 11 | `test_WithdrawZero` | 提款 0 ETH 成功，發出事件，餘額不變 |
| 12 | `test_WithdrawFromEmptyContract` | 從空合約提款會 revert |
| 13 | `test_OwnerIsSetCorrectly` | Owner 地址在部署時正確設定 |
| 14 | `test_DepositViaFallback` | 帶 data 的轉帳觸發 fallback，正確發出 Deposit 事件 |
| 15 | `test_FallbackWithZeroEth` | fallback 帶 data 但 0 ETH，交易成功 |

---

### Group E — 重入攻擊測試（1 個）

驗證重入保護機制：

| # | 測試名稱 | 說明 |
|---|----------|------|
| 16 | `test_ReentrancyGuardBlocksAttack` | 惡意合約嘗試重入攻擊被阻擋，拋出 Reentrancy 錯誤，餘額只減少一次 |

---

## 🎁 Bonus 實作

| 項目 | 狀態 |
|------|------|
| 重入保護 (Reentrancy protection) | ✅ 已實作 |
| 自定義錯誤 (Custom errors) | ✅ 已實作 |
| Gas 優化 (Gas optimizations) | ✅ 已實作 |
| NatSpec 註解 (NatSpec comments) | ✅ 已實作 |
| ≥90% 測試覆蓋率 (Test coverage) | ✅ 已實作 |

---

## 📄 授權

MIT License
