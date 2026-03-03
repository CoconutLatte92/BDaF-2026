// SPDX-License-Identifier: MIT
// 聲明授權類型為 MIT

pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本

// 導入 Foundry 測試框架
// Test 合約提供測試用的斷言函式（如 assertEq）和作弊碼（如 vm.prank）
import {Test} from "forge-std/Test.sol";

// 導入要測試的合約
import {EthVault} from "../src/EthVault.sol";

/// @title EthVault 測試合約
/// @notice 測試 EthVault 的所有功能
contract EthVaultTest is Test {
    
    // ============ 狀態變數 ============
    
    // 被測試的 EthVault 合約實例
    // internal = 只有這個合約和繼承它的合約可以存取
    EthVault internal vault;
    
    // 模擬的 owner 地址
    address internal owner;
    
    // 模擬的普通用戶地址
    address internal user1;
    
    // 另一個模擬用戶地址
    address internal user2;

    // ============ 事件定義 ============
    // 需要在測試合約中重新定義事件，才能使用 emit 測試
    
    event Deposit(address indexed sender, uint256 amount);
    event Weethdraw(address indexed to, uint256 amount);
    event UnauthorizedWithdrawAttempt(address indexed caller, uint256 amount);

    // ============ 設置函式 ============
    
    /// @notice 每個測試函式執行前都會自動調用此設置函式
    /// @dev setUp 是 Foundry 的特殊函式名，會在每個 test_ 函式前執行
    function setUp() public {
        // makeAddr("標籤") 創建一個帶標籤的測試地址
        // 標籤在 debug 時會顯示，方便識別
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // vm.deal(地址, 金額) 是 Foundry 的「作弊碼」
        // 直接設定該地址的 ETH 餘額，不需要真的轉帳
        // 1 ether = 1e18 wei = 1,000,000,000,000,000,000 wei
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // vm.prank(地址) 讓「下一行」程式碼以該地址身份執行
        // 這樣部署出來的合約，OWNER 就會是 owner 地址
        vm.prank(owner);
        
        // new EthVault() 部署一個新的 EthVault 合約
        // 因為上一行用了 vm.prank(owner)，所以 msg.sender = owner
        vault = new EthVault();
    }

    // ============ Extra 函式 ============
    // Extra 函式用來簡化重複的程式碼
    // 以底線 _ 開頭表示是內部使用的輔助函式
    
    /// @dev 執行存款的輔助函式
    /// @param from 存款人地址
    /// @param amount 存款金額（wei）
    function _deposit(address from, uint256 amount) internal {
        // 以 from 地址身份執行下一行
        vm.prank(from);
        
        // 使用低階 call 發送 ETH 到 vault 合約
        // address(vault) = vault 合約的地址
        // {value: amount} = 發送 amount wei
        // ("") = 不帶任何呼叫資料（會觸發 receive 或 fallback）
        // 回傳 (bool 是否成功, bytes 回傳資料)
        (bool ok, ) = address(vault).call{value: amount}("");
        
        // assertTrue(條件) 確認條件為 true，否則測試失敗
        assertTrue(ok);
    }
    
    /// @dev 預期會發出 Deposit 事件的輔助函式
    /// @param from 預期的存款人地址
    /// @param amount 預期的存款金額
    function _expectDeposit(address from, uint256 amount) internal {
        // vm.expectEmit(checkTopic1, checkTopic2, checkTopic3, checkData)
        // 設定「下一個呼叫」應該發出的事件
        // true = 要檢查這個欄位
        vm.expectEmit(true, true, false, true);
        
        // 發出預期的事件內容（使用測試合約中定義的事件）
        emit Deposit(from, amount);
    }
    
    /// @dev 預期會發出 Weethdraw 事件的輔助函式
    /// @param to 預期的收款人地址
    /// @param amount 預期的提款金額
    function _expectWithdraw(address to, uint256 amount) internal {
        vm.expectEmit(true, true, false, true);
        emit Weethdraw(to, amount);
    }
    
    /// @dev 預期會發出 UnauthorizedWithdrawAttempt 事件的輔助函式
    /// @param caller 預期的呼叫者地址
    /// @param amount 預期的嘗試提款金額
    function _expectUnauthorized(address caller, uint256 amount) internal {
        vm.expectEmit(true, true, false, true);
        emit UnauthorizedWithdrawAttempt(caller, amount);
    }

    // ============ Test Group A: 存款測試 ============
    // 測試作業要求的存款功能
    
    /// @notice 測試：單次存款應該成功
    function test_SingleDeposit() public {
        // ===== Arrange（準備）=====
        // 設定測試所需的變數和初始狀態
        
        uint256 amount = 1 ether;  // 要存入的金額
        uint256 vaultBefore = address(vault).balance;  // 記錄存款前的合約餘額
        
        // ===== Expect（預期）=====
        // 設定預期會發生的事件
        
        _expectDeposit(user1, amount);  // 預期會發出 Deposit 事件
        
        // ===== Act（執行）=====
        // 執行要測試的動作
        
        _deposit(user1, amount);  // user1 存入 1 ETH
        
        // ===== Assert（驗證）=====
        // 驗證結果是否符合預期
        
        // assertEq(實際值, 預期值) 確認兩個值相等
        // 合約餘額應該增加 amount
        assertEq(address(vault).balance, vaultBefore + amount);
    }
    
    /// @notice 測試：多次存款應該累加
    function test_MultipleDeposits() public {
        // ===== Arrange =====
        uint256 deposit1 = 1 ether;
        uint256 deposit2 = 2 ether;
        uint256 deposit3 = 0.5 ether;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Act =====
        // 連續存款三次
        _deposit(user1, deposit1);
        _deposit(user1, deposit2);
        _deposit(user1, deposit3);
        
        // ===== Assert =====
        // 總餘額應該等於三次存款的總和
        uint256 expectedBalance = deposit1 + deposit2 + deposit3;
        assertEq(address(vault).balance, vaultBefore + expectedBalance);
    }
    
    /// @notice 測試：不同發送者的存款
    function test_DepositsFromDifferentSenders() public {
        // ===== Arrange =====
        uint256 deposit1 = 1 ether;
        uint256 deposit2 = 2 ether;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect + Act (user1) =====
        _expectDeposit(user1, deposit1);  // 預期 user1 的存款事件
        _deposit(user1, deposit1);         // user1 存款
        
        // ===== Expect + Act (user2) =====
        _expectDeposit(user2, deposit2);  // 預期 user2 的存款事件
        _deposit(user2, deposit2);         // user2 存款
        
        // ===== Assert =====
        // 不管誰存的，總餘額應該正確累加
        assertEq(address(vault).balance, vaultBefore + deposit1 + deposit2);
    }
    
    /// @notice 測試：存入 0 ETH
    function test_DepositZero() public {
        // ===== Arrange =====
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        // 即使存 0 ETH，也應該發出 Deposit 事件
        _expectDeposit(user1, 0);
        
        // ===== Act =====
        _deposit(user1, 0);
        
        // ===== Assert =====
        // 餘額應該不變
        assertEq(address(vault).balance, vaultBefore);
    }

    // ============ Test Group B: Owner 提款測試 ============
    // 測試作業要求的 Owner 提款功能
    
    /// @notice 測試：Owner 可以提取部分餘額
    function test_OwnerPartialWithdraw() public {
        // ===== Arrange =====
        uint256 depositAmount = 10 ether;
        uint256 withdrawAmount = 3 ether;
        
        // 先存入一些 ETH
        _deposit(user1, depositAmount);
        
        // 記錄提款前的餘額
        uint256 ownerBefore = owner.balance;      // owner 的 ETH 餘額
        uint256 vaultBefore = address(vault).balance;  // 合約的 ETH 餘額
        
        // ===== Expect =====
        _expectWithdraw(owner, withdrawAmount);  // 預期會發出 Weethdraw 事件
        
        // ===== Act =====
        vm.prank(owner);  // 以 owner 身份執行
        vault.withdraw(withdrawAmount);  // 提取 3 ETH
        
        // ===== Assert =====
        // 合約餘額應該減少
        assertEq(address(vault).balance, vaultBefore - withdrawAmount);
        // owner 餘額應該增加
        assertEq(owner.balance, ownerBefore + withdrawAmount);
    }
    
    /// @notice 測試：Owner 可以提取全部餘額
    function test_OwnerFullWithdraw() public {
        // ===== Arrange =====
        uint256 depositAmount = 5 ether;
        _deposit(user1, depositAmount);
        
        uint256 ownerBefore = owner.balance;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        _expectWithdraw(owner, vaultBefore);  // 提取全部
        
        // ===== Act =====
        vm.prank(owner);
        vault.withdraw(vaultBefore);
        
        // ===== Assert =====
        assertEq(address(vault).balance, 0);  // 合約應該清空
        assertEq(owner.balance, ownerBefore + vaultBefore);  // owner 收到全部
    }
    
    /// @notice 測試：多次存款後 Owner 提款
    function test_WithdrawAfterMultipleDeposits() public {
        // ===== Arrange =====
        // 多人多次存款
        _deposit(user1, 1 ether);
        _deposit(user2, 2 ether);
        _deposit(user1, 1.5 ether);
        // 總共 4.5 ETH
        
        uint256 withdrawAmount = 2 ether;
        uint256 ownerBefore = owner.balance;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        _expectWithdraw(owner, withdrawAmount);
        
        // ===== Act =====
        vm.prank(owner);
        vault.withdraw(withdrawAmount);
        
        // ===== Assert =====
        assertEq(address(vault).balance, vaultBefore - withdrawAmount);
        assertEq(owner.balance, ownerBefore + withdrawAmount);
    }

    // ============ Test Group C: 未授權提款測試 ============
    // 測試非 Owner 嘗試提款時的行為
    
    /// @notice 測試：非 Owner 無法提款（不會 revert，但資金不會轉移）
    function test_UnauthorizedWithdrawDoesNotTransfer() public {
        // ===== Arrange =====
        uint256 depositAmount = 5 ether;
        _deposit(user1, depositAmount);
        
        // 記錄提款前的餘額
        uint256 user1Before = user1.balance;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        // 預期會發出 UnauthorizedWithdrawAttempt 事件
        _expectUnauthorized(user1, 1 ether);
        
        // ===== Act =====
        // user1 不是 owner，嘗試提款
        vm.prank(user1);
        vault.withdraw(1 ether);  // 這不會 revert，但也不會轉帳
        
        // ===== Assert =====
        // 合約餘額應該不變
        assertEq(address(vault).balance, vaultBefore);
        // user1 餘額也應該不變
        assertEq(user1.balance, user1Before);
    }
    
    /// @notice 測試：非 Owner 提款交易成功但不轉移資金
    function test_UnauthorizedWithdrawNoTransfer() public {
        // ===== Arrange =====
        uint256 depositAmount = 10 ether;
        _deposit(user1, depositAmount);
        
        // user2 將嘗試非法提款
        uint256 user2Before = user2.balance;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        _expectUnauthorized(user2, 5 ether);
        
        // ===== Act =====
        vm.prank(user2);  // user2 不是 owner
        vault.withdraw(5 ether);
        
        // ===== Assert =====
        // 沒有任何資金轉移
        assertEq(user2.balance, user2Before);
        assertEq(address(vault).balance, vaultBefore);
    }

    // ============ Test Group D: 邊界情況測試 ============
    // 測試各種邊界情況
    
    /// @notice 測試：提款超過餘額應該 revert
    function test_WithdrawMoreThanBalance() public {
        // ===== Arrange =====
        uint256 depositAmount = 1 ether;
        _deposit(user1, depositAmount);
        
        uint256 requestAmount = 2 ether;  // 想提 2 ETH，但只有 1 ETH
        
        // ===== Expect =====
        // vm.expectRevert() 預期下一個呼叫會 revert
        // abi.encodeWithSelector() 編碼自定義錯誤和參數
        vm.expectRevert(
            abi.encodeWithSelector(
                EthVault.InsufficientBalance.selector,  // 錯誤類型
                requestAmount,  // 請求金額
                depositAmount   // 實際餘額
            )
        );
        
        // ===== Act =====
        vm.prank(owner);
        vault.withdraw(requestAmount);  // 這會 revert
        
        // 注意：revert 後不需要 Assert，因為交易已經失敗
    }
    
    /// @notice 測試：提款 0 ETH
    function test_WithdrawZero() public {
        // ===== Arrange =====
        uint256 depositAmount = 1 ether;
        _deposit(user1, depositAmount);
        
        uint256 vaultBefore = address(vault).balance;
        uint256 ownerBefore = owner.balance;
        
        // ===== Expect =====
        // 提款 0 ETH 應該成功，並發出事件
        _expectWithdraw(owner, 0);
        
        // ===== Act =====
        vm.prank(owner);
        vault.withdraw(0);
        
        // ===== Assert =====
        // 餘額都不變
        assertEq(address(vault).balance, vaultBefore);
        assertEq(owner.balance, ownerBefore);
    }
    
    /// @notice 測試：從空合約提款應該 revert
    function test_WithdrawFromEmptyContract() public {
        // ===== Arrange =====
        // 不存款，合約餘額為 0
        uint256 requestAmount = 1 ether;
        
        // ===== Expect =====
        vm.expectRevert(
            abi.encodeWithSelector(
                EthVault.InsufficientBalance.selector,
                requestAmount,  // 想提 1 ETH
                0               // 但餘額是 0
            )
        );
        
        // ===== Act =====
        vm.prank(owner);
        vault.withdraw(requestAmount);
    }
    
    /// @notice 測試：Owner 地址正確設定
    function test_OwnerIsSetCorrectly() public view {
        // view 函式不修改狀態，所以可以加 view 修飾符
        
        // ===== Assert =====
        // vault.OWNER() 呼叫合約的 OWNER getter 函式
        assertEq(vault.OWNER(), owner);
    }
    
    /// @notice 測試：透過 fallback 存款（帶 data）
    function test_DepositViaFallback() public {
        // ===== Arrange =====
        uint256 amount = 1 ether;
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Expect =====
        _expectDeposit(user1, amount);
        
        // ===== Act =====
        vm.prank(user1);
        // 發送帶有 data 的交易，這會觸發 fallback() 而非 receive()
        // "some random data" 是任意的 calldata
        (bool success,) = address(vault).call{value: amount}("some random data");
        assertTrue(success);
        
        // ===== Assert =====
        assertEq(address(vault).balance, vaultBefore + amount);
    }
    
    /// @notice 測試：fallback 帶 data 但 0 ETH（不應發出 Deposit 事件）
    function test_FallbackWithZeroEth() public {
        // ===== Arrange =====
        uint256 vaultBefore = address(vault).balance;
        
        // ===== Act =====
        vm.prank(user1);
        // 發送 0 ETH 但帶有 data
        // 根據合約邏輯，msg.value == 0 時不會發出 Deposit 事件
        (bool success,) = address(vault).call{value: 0}("some data");
        assertTrue(success);
        
        // ===== Assert =====
        // 餘額不變
        assertEq(address(vault).balance, vaultBefore);
    }

    // ============ Test Group E: 重入攻擊測試 ============
    // 測試 Bonus 的重入保護功能
    
    /// @notice 測試：重入攻擊應該被阻擋
    function test_ReentrancyGuardBlocksAttack() public {
        // ===== Arrange =====
        
        // 創建一個惡意攻擊合約
        ReentrantAttacker attacker = new ReentrantAttacker();
        
        // 以攻擊者身份部署一個新的 vault
        // 這樣攻擊者就是這個 vault 的 owner
        vm.prank(address(attacker));
        EthVault attackerVault = new EthVault();
        
        // 告訴攻擊合約要攻擊哪個 vault
        attacker.setVault(attackerVault);
        
        // 存入資金到 vault（由 user1 存入）
        uint256 depositAmount = 5 ether;
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool depositSuccess,) = address(attackerVault).call{value: depositAmount}("");
        assertTrue(depositSuccess);
        
        // ===== Expect =====
        // 第一次提款應該成功，發出 Weethdraw 事件
        vm.expectEmit(true, true, false, true, address(attackerVault));
        emit Weethdraw(address(attacker), 1 ether);
        
        // ===== Act =====
        // 攻擊者執行提款
        // 攻擊者的 receive() 會嘗試重入
        attacker.attack(1 ether);
        
        // ===== Assert =====
        
        // 確認攻擊者確實嘗試了重入
        assertTrue(attacker.attemptedReentry());
        
        // 確認重入被阻擋，收到 Reentrancy 錯誤
        bytes memory expectedError = abi.encodeWithSelector(EthVault.Reentrancy.selector);
        assertEq(attacker.reentryError(), expectedError);
        
        // 確認餘額只減少一次（重入沒有成功）
        // 如果重入成功，餘額會減少更多
        assertEq(address(attackerVault).balance, depositAmount - 1 ether);
    }
}

// ============ 惡意合約 ============

/// @title ReentrantAttacker - 模擬重入攻擊的惡意合約
/// @notice 這個合約用於測試 EthVault 的重入保護
/// @dev 當收到 ETH 時，會嘗試再次呼叫 withdraw（重入攻擊）
contract ReentrantAttacker {
    
    // 要攻擊的 vault 合約
    EthVault public vault;
    
    // 是否已嘗試重入
    bool public attemptedReentry;
    
    // 重入時收到的錯誤訊息
    bytes public reentryError;
    
    /// @notice 設定要攻擊的 vault
    /// @param _vault 目標 vault 合約
    function setVault(EthVault _vault) external {
        vault = _vault;
    }
    
    /// @notice 發起攻擊
    /// @param amount 第一次提款金額
    function attack(uint256 amount) external {
        vault.withdraw(amount);
    }
    
    /// @notice 接收 ETH 時自動觸發
    /// @dev 這裡是重入攻擊的關鍵：
    ///      當 vault 轉帳給這個合約時，會觸發 receive()
    ///      我們在這裡嘗試再次呼叫 withdraw()
    receive() external payable {
        // 只嘗試一次重入，避免無限迴圈
        if (!attemptedReentry) {
            attemptedReentry = true;
            
            // try-catch 語法：嘗試執行，如果失敗則捕獲錯誤
            try vault.withdraw(1 wei) {
                // 如果成功進入這裡，表示重入保護失效！
            } catch (bytes memory reason) {
                // 如果失敗，記錄錯誤訊息
                // 預期會收到 Reentrancy() 錯誤
                reentryError = reason;
            }
        }
    }
}
