// SPDX-License-Identifier: MIT
// 聲明開源授權類型為 MIT

pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本

/// @title EthVault 
/// @notice 這是一個簡單的 ETH 存取合約，只有 owner 可以提款
/// @dev 實作了存款事件、提款功能、未授權存取處理和重入保護
contract EthVault {
    
    // ============ 狀態變數 ============
    
    /// @notice 合約擁有者地址，只有此地址可以提款
    /// @dev 使用 immutable ，表示只在建構function中設定一次，之後無法更改
    ///      immutable 變數存儲在合約 bytecode 中，讀取時不需要 SLOAD，更省 gas
    address public immutable OWNER;

    /// @dev 重入保護狀態
    ///      1 = 未進入（NOT_ENTERED）
    ///      2 = 已進入（ENTERED）
    uint256 private _status;

    // ============ 常數 ============
    
    /// @dev 重入保護：未進入狀態
    uint256 private constant NOT_ENTERED = 1;
    
    /// @dev 重入保護：已進入狀態
    uint256 private constant ENTERED = 2;

    // ============ 事件定義 ============
    
    /// @notice 當有人存入 ETH 時觸發此事件
    /// @param sender 存款人地址（indexed 讓此欄位可被過濾）
    /// @param amount 存入的 ETH 數量
    event Deposit(address indexed sender, uint256 amount);

    /// @notice 當 owner 成功提款時觸發此事件
    /// @param to 收款人地址（即 owner）
    /// @param amount 提取的 ETH 數量
    event Weethdraw(address indexed to, uint256 amount);

    /// @notice 當非 owner 嘗試提款時觸發此事件
    /// @param caller 嘗試提款的地址
    /// @param amount 嘗試提取的數量
    /// @dev 這個事件用於記錄未授權的提款嘗試
    event UnauthorizedWithdrawAttempt(address indexed caller, uint256 amount);

    // ============ 自定義錯誤 ============
    
    /// @notice 當提款金額超過合約餘額時警告
    /// @param requested 請求提取的金額
    /// @param available 合約實際可用餘額
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice 當 ETH 轉帳失敗時警告
    error EthTransferFailed();

    /// @notice 當偵測到重入攻擊時警告
    error Reentrancy();

    // ============ 檢查 ============
    
    /// @notice 防止重入攻擊
    /// @dev 使用狀態變數 _status 來判斷function是否正在執行
    ///      如果function正在執行中又被呼叫，會 revert
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /// @dev 進入function前的檢查
    ///      如果 _status == ENTERED，表示正在重入，revert
    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert Reentrancy();
        }
        _status = ENTERED;
    }

    /// @dev 離開function後重置狀態
    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }

    // ============ 建構function ============
    
    /// @notice 合約建構function，設定 owner 和初始化重入保護狀態
    /// @dev 部署時會將部署者設為 owner
    ///      msg.sender 是部署此合約的地址
    constructor() {
        // 將部署者設為 owner
        OWNER = msg.sender;
        
        // 初始化重入保護狀態為「未進入」
        _status = NOT_ENTERED;
    }

    // ============ 接收 ETH function ============
    
    /// @notice 接收 ETH 的function
    /// @dev receive() 在合約收到純 ETH 轉帳（不帶任何 data）時自動使用
    receive() external payable {
        // 發出 Deposit 事件，記錄誰存了多少 ETH
        // msg.sender = 發送 ETH 的地址
        // msg.value = 發送的 ETH 數量
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 接收 ETH 時同時處理 data
    /// @dev fallback() 在合約收到 ETH 轉帳(可能為0)時附帶了 data
    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // ============ 提款 ETH function ============
    
    /// @notice 提取合約中的 ETH
    /// @param amount 要提取的 ETH 數量
    /// @dev 只有 owner 可以成功提款
    ///      非 owner 調用不會 revert，但會進入 UnauthorizedWithdrawAttempt 事件並直接返回
    ///      使用 nonReentrant 避免重入攻擊
    function withdraw(uint256 amount) external nonReentrant {
        // 檢查調用者是否為 owner
        if (msg.sender != OWNER) {
            // 非 owner：發出未授權事件並直接返回
            emit UnauthorizedWithdrawAttempt(msg.sender, amount);
            return;
        }

        // === 進入 owner 的提款部分 ===
        
        // 暫存合約餘額到記憶體
        uint256 bal = address(this).balance;
        
        // 檢查合約餘額是否足夠
        if (amount > bal) {
            // 餘額不足
            revert InsufficientBalance(amount, bal);
        }

        // 執行 ETH 轉帳
        // success接收布林值確認有無轉帳成功
        (bool success, ) = OWNER.call{value: amount}("");
        
        // 當轉帳未成功發出警告
        if (!success) {
            revert EthTransferFailed();
        }

        // 當轉帳成功後發出提款事件
        emit Weethdraw(OWNER, amount);
    }

}
