# BDaF 2026 Lab04 — 會員管理看板：Storage vs. Merkle Trees

## 📦 專案簡介

本專案實作了一個 **MembershipBoard** 合約，使用三種方式管理 1,000 名會員，並比較其 Gas 成本：
1. **逐一新增** (`addMember`) — 使用 mapping 逐個寫入 storage
2. **批量新增** (`batchAddMembers`) — 使用 mapping 批量寫入
3. **Merkle Root** (`setMerkleRoot`) — 鏈下構建 Merkle Tree，鏈上僅儲存一個 root

---

## 🛠️ 編譯與測試方式

```bash
# 1. 安裝 Foundry 依賴（forge-std + OpenZeppelin）
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts

# 2. 安裝 npm 依賴（Merkle Tree 鏈下生成用）
npm install

# 3. 編譯合約
forge build

# 4. 執行測試（含 Gas 日誌輸出）
forge test -vv --ffi

# 5. 生成 Gas Report 表格
forge test --gas-report --ffi
```

> ⚠️ 測試需加上 `--ffi` 參數，因為 Merkle Proof 是透過 FFI 呼叫 `node script/merkle.js` 在鏈下生成的。
> 請確保已安裝 Node.js 並執行過 `npm install`。

---

## ⛽ Gas 分析結果

以下數據透過 `forge test -vv --ffi` 中的 `gasleft()` 測量取得。

| 操作 | Gas 消耗 |
|------|----------|
| `addMember`（單次呼叫） | 35,483 |
| `addMember` × 1000（執行 gas 估算） | 35,483,000 |
| `addMember` × 1000（含 21k base/筆，總估算） | 56,483,000 |
| `batchAddMembers`（全部 1,000 人，4 批 × 250） | 24,443,951 |
| `setMerkleRoot` | 30,692 |
| `verifyMemberByMapping` | 1,484 |
| `verifyMemberByProof` | 5,762 |

> Merkle Proof 長度（樹深度）：10 層（log₂(1000) ≈ 10）

---

## 📊 批量大小實驗

| Batch Size | 批次數 | 總 Gas | 每人 Gas |
|------------|--------|--------|----------|
| 50 | 20 | 24,456,027 | 24,456 |
| 100 | 10 | 24,443,821 | 24,443 |
| 250 | 4 | 24,436,944 | 24,436 |
| 500 | 2 | 24,435,435 | 24,435 |

---

## ❓ 問題回答

### Q1：儲存成本比較 — 三種方式註冊 1,000 名會員的 Gas 比較

- **`addMember` × 1000：** 最昂貴。每次呼叫需支付 21,000 base transaction cost + 約 35,483 執行 gas。1,000 筆獨立交易總計約 **56,483,000 gas**。
- **`batchAddMembers`：** 較為便宜。每個會員的 `SSTORE` 成本不變（cold slot write 約 22,100），但僅需 4 筆交易（batch size 250），節省了大量的 21,000 base cost。總計約 **24,443,951 gas**。
- **`setMerkleRoot`：** 最便宜。整個操作只寫入 1 個 storage slot（32 bytes 的 root），僅需約 **30,692 gas**。所有會員的計算工作完全在鏈下完成。

**原因：** EVM 中 `SSTORE`（寫入新的 storage slot）是最昂貴的操作之一，每次需約 22,100 gas。Mapping 方式需寫入 1,000 個 slot；而 Merkle Root 方式將所有會員資訊壓縮為一個 32 bytes 的雜湊值，極大地降低了鏈上儲存需求。

---

### Q2：驗證成本比較 — Mapping 驗證 vs Merkle Proof 驗證

- **`verifyMemberByMapping`：** 約 1,484 gas。僅需一次 `SLOAD`（cold read 約 2,100 gas）加少量返回操作。O(1) 時間複雜度。
- **`verifyMemberByProof`：** 約 5,762 gas。需計算雙重 keccak256（防止 second preimage attack），並遍歷約 10 層 proof（log₂(1000) ≈ 10），每層一次雜湊運算。O(log n) 時間複雜度。

**Mapping 驗證較便宜**，因為是直接的 storage 查詢。但 Merkle Proof 驗證雖然稍貴，仍然非常高效且可擴展——即便會員數增長至百萬級，proof 也只多幾層雜湊運算。

---

### Q3：權衡分析 — 何時使用 Mapping，何時使用 Merkle Tree？

| 考量因素 | 適合 Mapping | 適合 Merkle Tree |
|----------|-------------|-----------------|
| **誰支付驗證 gas** | 合約內部頻繁查詢（如權限檢查），gas 由協議承擔 | 使用者自行提交 proof，驗證 gas 由使用者支付 |
| **會員列表變更頻率** | 頻繁增減會員（每次僅需 add/remove 一個 slot） | 會員列表穩定（每次變更需重建整棵樹並更新 root） |
| **隱私需求** | 列表完全公開（鏈上所有 member 皆可查詢） | 可隱藏完整列表（鏈上僅有 root，使用者自行持有 proof） |
| **註冊成本敏感度** | 會員數量少，註冊成本可接受 | 會員數量龐大（如萬人白名單），需最小化鏈上成本 |
| **典型應用場景** | DAO 投票權、角色管理、存取控制 | NFT 白名單 mint、空投資格驗證、snapshot 投票 |

**總結：**
- Merkle Tree 適合「一次寫入、多次驗證」且會員列表較少變動的場景
- Mapping 適合「頻繁讀寫、動態變更」的場景
- 兩者的核心權衡在於：**鏈上儲存成本 vs 鏈下計算 + 資料可用性**

---

### Q4：批量大小實驗 — 不同 batch size 對每人 gas 的影響

從實驗數據中觀察到的趨勢：

1. **Batch size 越大，每人平均 gas 越低**，因為 21,000 transaction base cost 和函式呼叫開銷被更多會員分攤。
2. **從 50 → 250 的改善較為顯著**（24,456 → 24,436），但 250 → 500 的邊際效益遞減（24,436 → 24,435）——因為每人的 `SSTORE` 成本是固定的，能優化的僅有固定開銷。
3. **甜蜜點大約在 200～300 之間** — 在不超過 block gas limit（30M）的前提下，能有效分攤固定成本，又不至於單筆交易過大而有失敗風險。
4. Batch size 500 時每批約消耗約 12,200,000 gas，在 30M limit 下仍然安全；但若一次提交 1,000 筆則可能接近上限。

---

## 📁 專案結構

```
lab04/
├── src/
│   └── MembershipBoard.sol      # 主合約（5 個函式，含完整中文註解）
├── test/
│   └── MembershipBoard.t.sol    # Foundry 測試套件 + Gas 分析
├── script/
│   └── merkle.js                # 鏈下 Merkle Tree 生成腳本（FFI 呼叫用）
├── members.json                 # 1,000 個預先生成的地址
├── generate_members.js          # 地址生成腳本
├── foundry.toml                 # Foundry 設定檔
├── remappings.txt               # 依賴路徑映射
├── package.json                 # npm 依賴設定
└── README.md
```
