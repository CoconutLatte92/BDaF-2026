// SPDX-License-Identifier: MIT
// 聲明授權類型為 MIT，這是開源授權的一種

pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本，^0.8.20 表示 >=0.8.20 且 <0.9.0

/// @title EthVault - ETH 保險庫合約
/// @author Your Name
/// @notice 這是一個簡單的 ETH 存取合約，只有 owner 可以提款
/// @dev 實作了存款事件、提款功能和未授權存取處理
contract EthVault {
    
    // ============ 狀態變數 ============
    
    /// @notice 合約擁有者地址，只有此地址可以提款
    /// @dev 使用 immutable 關鍵字，表示只能在建構函式中設定一次，之後無法更改
    ///      immutable 比 constant 更靈活（constant 必須在編譯時確定值）
    ///      immutable 變數存儲在合約 bytecode 中，讀取時不需要 SLOAD，更省 gas
    address public immutable OWNER;

    // ============ 事件定義 ============
    
    /// @notice 當有人存入 ETH 時觸發此事件
    /// @param sender 存款人地址（indexed 讓此欄位可被搜尋/過濾）
    /// @param amount 存入的 ETH 數量（以 wei 為單位）
    /// @dev indexed 參數會被存入 log 的 topics 中，方便鏈下索引查詢
    event Deposit(address indexed sender, uint256 amount);

    /// @notice 當 owner 成功提款時觸發此事件
    /// @param to 收款人地址（即 owner）
    /// @param amount 提取的 ETH 數量（以 wei 為單位）
    event Withdraw(address indexed to, uint256 amount);

    /// @notice 當非 owner 嘗試提款時觸發此事件
    /// @param caller 嘗試提款的地址
    /// @param amount 嘗試提取的數量
    /// @dev 這個事件用於記錄未授權的提款嘗試，方便監控和審計
    event UnauthorizedWithdrawAttempt(address indexed caller, uint256 amount);

    // ============ 自定義錯誤 ============
    
    /// @notice 當提款金額超過合約餘額時拋出
    /// @param requested 請求提取的金額
    /// @param available 合約實際可用餘額
    /// @dev 使用自定義錯誤比 require + string 更省 gas
    error InsufficientBalance(uint256 requested, uint256 available);

    // ============ 建構函式 ============
    
    /// @notice 合約建構函式，設定 owner
    /// @dev 部署時會將部署者設為 owner
    ///      msg.sender 是部署此合約的地址
    constructor() {
        // 將部署者設為 owner
        // msg.sender 在建構函式中是部署合約的地址
        OWNER = msg.sender;
    }

    // ============ 接收 ETH 函式 ============
    
    /// @notice 接收 ETH 的特殊函式
    /// @dev receive() 在合約收到純 ETH 轉帳時自動調用（沒有 calldata 時）
    ///      - 必須是 external 和 payable
    ///      - 當有人直接向合約發送 ETH（不帶任何 data）時觸發
    ///      - 例如：使用錢包直接轉帳給合約地址
    receive() external payable {
        // 發出 Deposit 事件，記錄誰存了多少 ETH
        // msg.sender = 發送 ETH 的地址
        // msg.value = 發送的 ETH 數量（wei）
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 備用函式，處理帶有 data 但不匹配任何函式的調用
    /// @dev fallback() 在以下情況被調用：
    ///      1. 調用了合約中不存在的函式
    ///      2. 發送 ETH 時附帶了 data，且沒有 receive() 函式
    ///      這裡我們也讓它接收 ETH 並發出事件
    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // ============ 提款函式 ============
    
    /// @notice 提取合約中的 ETH
    /// @param amount 要提取的 ETH 數量（以 wei 為單位）
    /// @dev 只有 owner 可以成功提款
    ///      非 owner 調用會 revert 並發出 UnauthorizedWithdrawAttempt 事件
    function withdraw(uint256 amount) external {
        // 檢查調用者是否為 owner
        if (msg.sender != OWNER) {
            // 非 owner：發出未授權事件並 revert
            // 先發出事件，記錄這次未授權嘗試
            emit UnauthorizedWithdrawAttempt(msg.sender, amount);
            // 然後 revert 交易
            // 注意：根據作業要求，非 owner 需要 revert
            revert("Unauthorized");
        }

        // === 以下是 owner 的提款邏輯 ===
        
        // 檢查合約餘額是否足夠
        // address(this).balance 取得此合約的 ETH 餘額
        if (amount > address(this).balance) {
            // 使用自定義錯誤，提供更多資訊且更省 gas
            revert InsufficientBalance(amount, address(this).balance);
        }

        // 發出提款事件（在轉帳前發出 - Checks-Effects-Interactions 模式）
        // 這樣可以防止重入攻擊
        emit Withdraw(OWNER, amount);

        // 執行 ETH 轉帳
        // 使用低階 call 方法，這是目前推薦的 ETH 轉帳方式
        // call 會轉發所有可用 gas（可以指定 gas 限制）
        // 返回值：(bool success, bytes memory data)
        (bool success, ) = OWNER.call{value: amount}("");
        
        // 確保轉帳成功
        // 如果失敗（例如接收方合約的 receive 函式 revert），整筆交易會回滾
        require(success, "Transfer failed");
    }

    // ============ 輔助函式 ============
    
    /// @notice 查詢合約當前的 ETH 餘額
    /// @return 合約的 ETH 餘額（以 wei 為單位）
    /// @dev 這是一個 view 函式，不消耗 gas（當外部調用時）
    ///      pure 函式不讀取狀態，view 函式只讀取狀態但不修改
    function getBalance() external view returns (uint256) {
        // address(this) 是此合約的地址
        // .balance 是該地址的 ETH 餘額
        return address(this).balance;
    }
}
