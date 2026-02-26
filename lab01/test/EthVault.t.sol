// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 導入 Foundry 測試框架
// Test 是 Foundry 的基礎測試合約，提供各種斷言和作弊碼
import {Test} from "forge-std/Test.sol";

// 導入要測試的合約
import {EthVault} from "../src/EthVault.sol";

/// @title EthVault 測試合約
/// @notice 測試 EthVault 的所有功能
/// @dev 繼承 Test 合約以獲得測試功能
contract EthVaultTest is Test {
    
    // ============ 狀態變數 ============
    
    /// @notice 被測試的 EthVault 合約實例
    EthVault public vault;
    
    /// @notice 模擬的 owner 地址
    /// @dev 使用 makeAddr() 創建一個有標籤的地址，方便調試
    address public owner;
    
    /// @notice 模擬的普通用戶地址
    address public user1;
    
    /// @notice 另一個模擬用戶地址
    address public user2;

    // ============ 事件定義（用於測試事件發出）============
    
    // 需要在測試合約中重新定義事件，才能使用 vm.expectEmit 測試
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event UnauthorizedWithdrawAttempt(address indexed caller, uint256 amount);

    // ============ 設置函式 ============
    
    /// @notice 每個測試函式執行前都會調用此設置函式
    /// @dev setUp 是 Foundry 的特殊函式名，會自動執行
    function setUp() public {
        // 創建測試用地址
        // makeAddr() 是 Foundry 提供的輔助函式，創建帶標籤的地址
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 給測試地址一些 ETH
        // vm.deal() 是 Foundry 的「作弊碼」，可以直接設定地址的 ETH 餘額
        // 1 ether = 1e18 wei
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // 以 owner 身份部署合約
        // vm.prank() 讓下一個調用以指定地址身份執行
        // 這樣合約的 owner 就會是 owner 地址，而不是測試合約地址
        vm.prank(owner);
        vault = new EthVault();
    }

    // ============ Test Group A: 存款測試 ============
    
    /// @notice 測試：單次存款應該成功
    function test_SingleDeposit() public {
        // 記錄存款金額
        uint256 depositAmount = 1 ether;
        
        // 預期會發出 Deposit 事件
        // vm.expectEmit() 設定期望的事件
        // 參數說明：(checkTopic1, checkTopic2, checkTopic3, checkData)
        // true 表示要檢查該項目
        vm.expectEmit(true, true, false, true);
        
        // 發出預期的事件（必須在實際調用前）
        emit Deposit(user1, depositAmount);
        
        // 以 user1 身份發送 ETH 到合約
        // vm.prank() 只影響下一個調用
        vm.prank(user1);
        
        // 使用低階 call 發送 ETH
        // 這會觸發合約的 receive() 函式
        (bool success,) = address(vault).call{value: depositAmount}("");
        
        // 確認發送成功
        assertTrue(success, "ETH transfer should succeed");
        
        // 確認合約餘額正確
        assertEq(vault.getBalance(), depositAmount, "Contract balance should equal deposit amount");
    }
    
    /// @notice 測試：多次存款應該累加
    function test_MultipleDeposits() public {
        uint256 deposit1 = 1 ether;
        uint256 deposit2 = 2 ether;
        uint256 deposit3 = 0.5 ether;
        
        // 第一次存款
        vm.prank(user1);
        (bool success1,) = address(vault).call{value: deposit1}("");
        assertTrue(success1);
        
        // 第二次存款
        vm.prank(user1);
        (bool success2,) = address(vault).call{value: deposit2}("");
        assertTrue(success2);
        
        // 第三次存款
        vm.prank(user1);
        (bool success3,) = address(vault).call{value: deposit3}("");
        assertTrue(success3);
        
        // 確認總餘額正確
        uint256 expectedBalance = deposit1 + deposit2 + deposit3;
        assertEq(vault.getBalance(), expectedBalance, "Balance should equal sum of all deposits");
    }
    
    /// @notice 測試：不同發送者的存款
    function test_DepositsFromDifferentSenders() public {
        uint256 deposit1 = 1 ether;
        uint256 deposit2 = 2 ether;
        
        // user1 存款
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, deposit1);
        vm.prank(user1);
        (bool success1,) = address(vault).call{value: deposit1}("");
        assertTrue(success1);
        
        // user2 存款
        vm.expectEmit(true, true, false, true);
        emit Deposit(user2, deposit2);
        vm.prank(user2);
        (bool success2,) = address(vault).call{value: deposit2}("");
        assertTrue(success2);
        
        // 確認總餘額
        assertEq(vault.getBalance(), deposit1 + deposit2);
    }
    
    /// @notice 測試：存入 0 ETH
    function test_DepositZero() public {
        // 存入 0 ETH 也應該成功並發出事件
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, 0);
        
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 0}("");
        assertTrue(success);
        
        assertEq(vault.getBalance(), 0);
    }

    // ============ Test Group B: Owner 提款測試 ============
    
    /// @notice 測試：Owner 可以提取部分餘額
    function test_OwnerPartialWithdraw() public {
        // 先存入一些 ETH
        uint256 depositAmount = 10 ether;
        vm.prank(user1);
        (bool depositSuccess,) = address(vault).call{value: depositAmount}("");
        assertTrue(depositSuccess);
        
        // Owner 提取部分
        uint256 withdrawAmount = 3 ether;
        
        // 記錄 owner 提款前的餘額
        uint256 ownerBalanceBefore = owner.balance;
        
        // 預期發出 Withdraw 事件
        vm.expectEmit(true, true, false, true);
        emit Withdraw(owner, withdrawAmount);
        
        // Owner 執行提款
        vm.prank(owner);
        vault.withdraw(withdrawAmount);
        
        // 確認合約餘額減少
        assertEq(vault.getBalance(), depositAmount - withdrawAmount, "Contract balance should decrease");
        
        // 確認 owner 餘額增加
        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount, "Owner balance should increase");
    }
    
    /// @notice 測試：Owner 可以提取全部餘額
    function test_OwnerFullWithdraw() public {
        // 存入 ETH
        uint256 depositAmount = 5 ether;
        vm.prank(user1);
        (bool success,) = address(vault).call{value: depositAmount}("");
        assertTrue(success);
        
        // 記錄 owner 初始餘額
        uint256 ownerBalanceBefore = owner.balance;
        
        // Owner 提取全部
        vm.prank(owner);
        vault.withdraw(depositAmount);
        
        // 確認合約餘額為 0
        assertEq(vault.getBalance(), 0, "Contract should be empty");
        
        // 確認 owner 收到所有 ETH
        assertEq(owner.balance, ownerBalanceBefore + depositAmount);
    }
    
    /// @notice 測試：多次存款後 Owner 提款
    function test_WithdrawAfterMultipleDeposits() public {
        // 多次存款
        vm.prank(user1);
        (bool s1,) = address(vault).call{value: 1 ether}("");
        vm.prank(user2);
        (bool s2,) = address(vault).call{value: 2 ether}("");
        vm.prank(user1);
        (bool s3,) = address(vault).call{value: 1.5 ether}("");
        
        assertTrue(s1 && s2 && s3);
        
        uint256 totalDeposited = 4.5 ether;
        assertEq(vault.getBalance(), totalDeposited);
        
        // Owner 提款
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        vault.withdraw(2 ether);
        
        assertEq(vault.getBalance(), 2.5 ether);
        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
    }

    // ============ Test Group C: 未授權提款測試 ============
    
    /// @notice 測試：非 Owner 無法提款
    function test_UnauthorizedWithdrawReverts() public {
        // 先存入 ETH
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 5 ether}("");
        assertTrue(success);
        
        // 記錄合約餘額
        uint256 balanceBefore = vault.getBalance();
        
        // 預期發出 UnauthorizedWithdrawAttempt 事件
        vm.expectEmit(true, true, false, true);
        emit UnauthorizedWithdrawAttempt(user1, 1 ether);
        
        // 預期 revert
        // vm.expectRevert() 表示下一個調用應該 revert
        vm.expectRevert("Unauthorized");
        
        // 非 owner 嘗試提款
        vm.prank(user1);
        vault.withdraw(1 ether);
        
        // 確認餘額未改變
        assertEq(vault.getBalance(), balanceBefore, "Balance should not change");
    }
    
    /// @notice 測試：非 Owner 提款不會轉移資金
    function test_UnauthorizedWithdrawNoTransfer() public {
        // 存入 ETH
        uint256 depositAmount = 10 ether;
        vm.prank(user1);
        (bool success,) = address(vault).call{value: depositAmount}("");
        assertTrue(success);
        
        // 記錄 user2 的餘額（user2 將嘗試非法提款）
        uint256 user2BalanceBefore = user2.balance;
        uint256 vaultBalanceBefore = vault.getBalance();
        
        // user2 嘗試提款（應該 revert）
        vm.expectRevert("Unauthorized");
        vm.prank(user2);
        vault.withdraw(5 ether);
        
        // 確認沒有資金轉移
        assertEq(user2.balance, user2BalanceBefore, "User2 balance should not change");
        assertEq(vault.getBalance(), vaultBalanceBefore, "Vault balance should not change");
    }

    // ============ Test Group D: 邊界情況測試 ============
    
    /// @notice 測試：提款超過餘額應該 revert
    function test_WithdrawMoreThanBalance() public {
        // 存入 1 ETH
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 1 ether}("");
        assertTrue(success);
        
        // Owner 嘗試提取 2 ETH（超過餘額）
        // 預期 revert with InsufficientBalance error
        vm.expectRevert(
            abi.encodeWithSelector(
                EthVault.InsufficientBalance.selector,
                2 ether,    // requested
                1 ether     // available
            )
        );
        
        vm.prank(owner);
        vault.withdraw(2 ether);
    }
    
    /// @notice 測試：提款 0 ETH
    function test_WithdrawZero() public {
        // 存入一些 ETH
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 balanceBefore = vault.getBalance();
        uint256 ownerBalanceBefore = owner.balance;
        
        // Owner 提款 0 ETH（應該成功）
        vm.expectEmit(true, true, false, true);
        emit Withdraw(owner, 0);
        
        vm.prank(owner);
        vault.withdraw(0);
        
        // 餘額應該不變
        assertEq(vault.getBalance(), balanceBefore);
        assertEq(owner.balance, ownerBalanceBefore);
    }
    
    /// @notice 測試：從空合約提款應該 revert
    function test_WithdrawFromEmptyContract() public {
        // 合約是空的，嘗試提款
        vm.expectRevert(
            abi.encodeWithSelector(
                EthVault.InsufficientBalance.selector,
                1 ether,
                0
            )
        );
        
        vm.prank(owner);
        vault.withdraw(1 ether);
    }
    
    /// @notice 測試：Owner 地址正確設定
    function test_OwnerIsSetCorrectly() public view {
        // 確認 owner 是部署時指定的地址
        assertEq(vault.OWNER(), owner, "Owner should be set correctly");
    }
    
    /// @notice 測試：透過 fallback 存款
    function test_DepositViaFallback() public {
        // 發送帶有 data 的交易（觸發 fallback 而非 receive）
        uint256 depositAmount = 1 ether;
        
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, depositAmount);
        
        vm.prank(user1);
        // 發送帶有任意 data 的交易
        (bool success,) = address(vault).call{value: depositAmount}("some random data");
        assertTrue(success);
        
        assertEq(vault.getBalance(), depositAmount);
    }

    // ============ Fuzz 測試（額外加分）============
    
    /// @notice Fuzz 測試：任意金額存款
    /// @param amount 隨機生成的存款金額
    /// @dev Foundry 會自動生成多個隨機值來測試
    function testFuzz_Deposit(uint256 amount) public {
        // 限制金額範圍，避免 overflow 或餘額不足
        // vm.assume() 會跳過不符合條件的測試案例
        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);
        
        vm.prank(user1);
        (bool success,) = address(vault).call{value: amount}("");
        assertTrue(success);
        
        assertEq(vault.getBalance(), amount);
    }
    
    /// @notice Fuzz 測試：存款後提款
    function testFuzz_DepositAndWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        // 設定合理的測試範圍
        vm.assume(depositAmount <= 50 ether && depositAmount > 0);
        vm.assume(withdrawAmount <= depositAmount);
        
        // 存款
        vm.prank(user1);
        (bool success,) = address(vault).call{value: depositAmount}("");
        assertTrue(success);
        
        // Owner 提款
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        vault.withdraw(withdrawAmount);
        
        // 驗證
        assertEq(vault.getBalance(), depositAmount - withdrawAmount);
        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount);
    }
}
