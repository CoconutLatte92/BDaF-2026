# Homework1 - EthVault

## 📝 專案描述

EthVault 是一個簡單的以太坊智能合約，實現了 ETH 保險庫功能：

- ✅ 接受任何人的 ETH 存款
- ✅ 記錄每筆存款事件
- ✅ 只允許 owner 提款
- ✅ 記錄未授權的提款嘗試

## 🛠️ 技術規格

| 項目 | 說明 |
|------|------|
| Framework | Foundry |
| Solidity Version | ^0.8.20 |
| 測試框架 | forge-std |

## 📁 專案結構

```
Homework1/
├── src/
│   └── EthVault.sol      # 主合約
├── test/
│   └── EthVault.t.sol    # 測試檔案
├── foundry.toml          # Foundry 配置
└── README.md             # 本文件
```

## 🚀 快速開始

### 前置需求

確保已安裝 Foundry：

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 安裝依賴

```bash
# 進入專案目錄
cd Homework1

# 安裝 forge-std（如果是新環境）
forge install foundry-rs/forge-std --no-commit
```

### 編譯合約

```bash
forge build
```

### 執行測試

```bash
# 執行所有測試
forge test

# 顯示詳細輸出
forge test -vv

# 顯示 gas 報告
forge test --gas-report

# 執行特定測試
forge test --match-test test_SingleDeposit -vvv
```

## 📋 合約功能

### 事件

| 事件名稱 | 參數 | 說明 |
|---------|------|------|
| `Deposit` | `sender`, `amount` | ETH 存入時觸發 |
| `Withdraw` | `to`, `amount` | Owner 提款時觸發 |
| `UnauthorizedWithdrawAttempt` | `caller`, `amount` | 非 Owner 嘗試提款時觸發 |

### 函式

| 函式 | 說明 |
|------|------|
| `receive()` | 接收純 ETH 轉帳 |
| `fallback()` | 處理帶 data 的 ETH 轉帳 |
| `withdraw(uint256)` | Owner 提款 |
| `getBalance()` | 查詢合約餘額 |
| `owner()` | 查詢 owner 地址 |

## ✅ 測試覆蓋

- **Test Group A**: 存款測試
  - 單次存款
  - 多次存款
  - 不同發送者存款
  - 零金額存款

- **Test Group B**: Owner 提款測試
  - 部分提款
  - 全額提款
  - 多次存款後提款

- **Test Group C**: 未授權提款測試
  - 非 Owner 提款被拒絕
  - 事件正確發出
  - 資金未被轉移

- **Test Group D**: 邊界情況
  - 超額提款
  - 零金額提款
  - 空合約提款

## 👤 作者

[Your Name]

## 📄 授權

MIT License
