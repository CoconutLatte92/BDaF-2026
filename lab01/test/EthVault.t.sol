// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 導入 Foundry 測試框架
// Test 是 Foundry 的基礎測試合約
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

    // ============ 事件定義 ============
    
    // 需要在測試合約中再定義事件，才能測試
    event Deposit(address indexed sender, uint256 amount);
    event Weethdraw(address indexed to, uint256 amount);
    event UnauthorizedWithdrawAttempt(address indexed caller, uint256 amount);

    // ============ 設置function ============
    
    /// @notice 每個測試function執行前都會調用此設置function
    /// @dev setUp 是 Foundry 的特殊function名，會自動執行
    function setUp() public {
        // 創建測試用地址
        // makeAddr() 是 Foundry 提供的輔助function，創建帶標籤的地址
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 給測試地址一些 ETH
        // vm.deal() 是 Foundry 提供的輔助function，可以直接設定地址的 ETH 餘額
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // 以 owner 身份部署合約
        // vm.prank() 讓下一個調用以指定地址身份執行
        // 這樣就能設定合約的 owner 就會是 owner 地址，而不是測試合約地址
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
        // 這會觸發合約的 receive() function
        (bool success,) = address(vault).call{value: depositAmount}("");
        
        // 確認發送成功
        assertTrue(success, "ETH transfer should succeed");
        
        // 確認合約餘額正確
        assertEq(address(vault).balance, depositAmount, "Contract balance should equal deposit amount");
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
        assertEq(address(vault).balance, expectedBalance, "Balance should equal sum of all deposits");
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
        assertEq(address(vault).balance, deposit1 + deposit2);
    }
    
    /// @notice 測試：存入 0 ETH
    function test_DepositZero() public {
        // 存入 0 ETH 也應該成功並發出事件
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, 0);
        
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 0}("");
        assertTrue(success);
        
        assertEq(address(vault).balance, 0);
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
        
        // 預期發出 Weethdraw 事件
        vm.expectEmit(true, true, false, true);
        emit Weethdraw(owner, withdrawAmount);
        
        // Owner 執行提款
        vm.prank(owner);
        vault.withdraw(withdrawAmount);
        
        // 確認合約餘額減少
        assertEq(address(vault).balance, depositAmount - withdrawAmount, "Contract balance should decrease");
        
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
        assertEq(address(vault).balance, 0, "Contract should be empty");
        
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
        assertEq(address(vault).balance, totalDeposited);
        
        // Owner 提款
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        vault.withdraw(2 ether);
        
        assertEq(address(vault).balance, 2.5 ether);
        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
    }

    // ============ Test Group C: 未授權提款測試 ============
    
    /// @notice 測試：非 Owner 無法提款（不會 revert，但資金不會轉移）
    function test_UnauthorizedWithdrawDoesNotTransfer() public {
        // 先存入 ETH
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 5 ether}("");
        assertTrue(success);
        
        // 記錄合約餘額和 user1 餘額
        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 user1BalanceBefore = user1.balance;
        
        // 預期發出 UnauthorizedWithdrawAttempt 事件
        vm.expectEmit(true, true, false, true);
        emit UnauthorizedWithdrawAttempt(user1, 1 ether);
        
        // 非 owner 嘗試提款（不會 revert，只是不轉帳）
        vm.prank(user1);
        vault.withdraw(1 ether);
        
        // 確認合約餘額未改變
        assertEq(address(vault).balance, vaultBalanceBefore, "Vault balance should not change");
        
        // 確認 user1 餘額未改變
        assertEq(user1.balance, user1BalanceBefore, "User balance should not change");
    }
    
    /// @notice 測試：非 Owner 提款交易成功但不轉移資金
    function test_UnauthorizedWithdrawNoTransfer() public {
        // 存入 ETH
        uint256 depositAmount = 10 ether;
        vm.prank(user1);
        (bool success,) = address(vault).call{value: depositAmount}("");
        assertTrue(success);
        
        // 記錄 user2 的餘額（user2 將嘗試非法提款）
        uint256 user2BalanceBefore = user2.balance;
        uint256 vaultBalanceBefore = address(vault).balance;
        
        // 預期發出 UnauthorizedWithdrawAttempt 事件
        vm.expectEmit(true, true, false, true);
        emit UnauthorizedWithdrawAttempt(user2, 5 ether);
        
        // user2 嘗試提款（交易會成功，但不轉帳）
        vm.prank(user2);
        vault.withdraw(5 ether);
        
        // 確認沒有資金轉移
        assertEq(user2.balance, user2BalanceBefore, "User2 balance should not change");
        assertEq(address(vault).balance, vaultBalanceBefore, "Vault balance should not change");
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
        
        uint256 balanceBefore = address(vault).balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        // Owner 提款 0 ETH（應該成功）
        vm.expectEmit(true, true, false, true);
        emit Weethdraw(owner, 0);
        
        vm.prank(owner);
        vault.withdraw(0);
        
        // 餘額應該不變
        assertEq(address(vault).balance, balanceBefore);
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
    
    /// @notice 測試：透過 fallback 存款（帶 data）
    function test_DepositViaFallback() public {
        // 發送帶有 data 的交易（觸發 fallback 而非 receive）
        uint256 depositAmount = 1 ether;
        
        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, depositAmount);
        
        vm.prank(user1);
        // 發送帶有任意 data 的交易
        (bool success,) = address(vault).call{value: depositAmount}("some random data");
        assertTrue(success);
        
        assertEq(address(vault).balance, depositAmount);
    }
    
    /// @notice 測試：fallback 帶 data 但 0 ETH（不應發出 Deposit 事件）
    function test_FallbackWithZeroEth() public {
        // 發送帶 data 但 0 ETH 的交易
        // 因為 msg.value = 0，不應該發出 Deposit 事件
        
        vm.prank(user1);
        (bool success,) = address(vault).call{value: 0}("some data");
        assertTrue(success);
        
        // 餘額應該是 0
        assertEq(address(vault).balance, 0);
    }

    // ============ Test Group E: 重入攻擊測試 ============
    
    /// @notice 測試：重入攻擊應該被阻擋
    /// @dev 創建一個惡意合約嘗試重入攻擊，驗證 nonReentrant 修飾符有效
    function test_ReentrancyGuardBlocksAttack() public {
        // 創建惡意攻擊合約
        ReentrantAttacker attacker = new ReentrantAttacker();
        
        // 以攻擊者身份部署一個新的 vault（攻擊者成為 owner）
        vm.prank(address(attacker));
        EthVault attackerVault = new EthVault();
        
        // 設定攻擊者要攻擊的 vault
        attacker.setVault(attackerVault);
        
        // 存入資金到 vault
        uint256 depositAmount = 5 ether;
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool depositSuccess,) = address(attackerVault).call{value: depositAmount}("");
        assertTrue(depositSuccess);
        
        // 確認初始餘額
        assertEq(address(attackerVault).balance, depositAmount);
        
        // 預期外層提款會成功並發出 Weethdraw 事件
        vm.expectEmit(true, true, false, true, address(attackerVault));
        emit Weethdraw(address(attacker), 1 ether);
        
        // 攻擊者執行提款（會在 receive 中嘗試重入）
        attacker.attack(1 ether);
        
        // 驗證：攻擊者確實嘗試了重入
        assertTrue(attacker.attemptedReentry(), "Attacker should have attempted reentry");
        
        // 驗證：重入被阻擋，錯誤訊息正確
        bytes memory expectedError = abi.encodeWithSelector(EthVault.Reentrancy.selector);
        assertEq(attacker.reentryError(), expectedError, "Should revert with Reentrancy error");
        
        // 驗證：vault 餘額只減少一次（1 ether），而不是被多次提款
        assertEq(address(attackerVault).balance, depositAmount - 1 ether, "Only one withdrawal should succeed");
    }

}

/// @title ReentrantAttacker - 模擬重入攻擊的惡意合約
/// @notice 用於測試 EthVault 的重入保護機制
/// @dev 這個合約會在收到 ETH 時嘗試再次呼叫 withdraw
contract ReentrantAttacker {
    
    /// @notice 要攻擊的 vault 合約
    EthVault public vault;
    
    /// @notice 是否已嘗試重入
    bool public attemptedReentry;
    
    /// @notice 重入時收到的錯誤訊息
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
    
    /// @notice 接收 ETH 時嘗試重入攻擊
    /// @dev 當 vault 轉帳給這個合約時，會觸發這個function
    ///      我們在這裡嘗試再次呼叫 withdraw
    receive() external payable {
        // 只嘗試一次重入，避免無限迴圈
        if (!attemptedReentry) {
            attemptedReentry = true;
            
            // 嘗試重入攻擊
            try vault.withdraw(1 wei) {
                // 如果成功，表示重入保護失效
            } catch (bytes memory reason) {
                // 記錄錯誤訊息
                reentryError = reason;
            }
        }
    }
}
