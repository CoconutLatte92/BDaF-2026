// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/PermitToken.sol";

/// @title  PermitToken 測試套件
/// @notice 驗證 Signature-Based Permit 的所有核心邏輯，涵蓋 Lab 規定的最低測試要求
contract PermitTokenTest is Test {
    // 受測合約實例
    PermitToken public token;

    // 測試帳號地址（由私鑰推導）
    address public alice; // 代幣持有人，負責產生簽名
    address public bob;   // 被授權者，負責提交 permit 並執行 transferFrom

    // 測試用私鑰（僅用於 forge 本地測試，切勿在真實環境使用）
    uint256 public alicePrivKey   = 0xA11CE;   // alice 的私鑰
    uint256 public charliePrivKey = 0xC4A111E; // 冒充者 charlie 的私鑰

    // 預設 deadline，在 setUp 中設定為「當前區塊時間 + 1 小時」
    uint256 public deadline;

    // -------------------------------------------------------
    // 輔助函式：產生符合合約格式的 permit 簽名
    // -------------------------------------------------------

    /// @dev 使用指定私鑰對 permit 訊息進行簽名，回傳 65-byte 簽名（abi.encodePacked(r, s, v)）
    /// @param privKey   簽名者的私鑰
    /// @param owner     permit 的 owner 地址（放入雜湊中）
    /// @param spender   permit 的 spender 地址
    /// @param value     授權額度
    /// @param nonce     使用的 nonce
    /// @param _deadline 有效截止時間戳
    function _signPermit(
        uint256 privKey,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 _deadline
    ) internal view returns (bytes memory) {
        // 呼叫合約的 getPermitHash()，確保測試與合約使用完全相同的雜湊邏輯
        bytes32 hash = token.getPermitHash(owner, spender, value, nonce, _deadline);

        // 手動包裝成 Ethereum Signed Message 格式（與合約內 toEthSignedMessageHash() 等效）
        bytes32 message = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );

        // 使用 forge cheatcode vm.sign() 以私鑰簽名，回傳 (v, r, s) 三個分量
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, message);

        // 按照 ECDSA 慣例將 r、s、v 依序打包成 65 bytes 回傳
        return abi.encodePacked(r, s, v);
    }

    // -------------------------------------------------------
    // 初始化：每個測試函式執行前都會先呼叫 setUp()
    // -------------------------------------------------------

    function setUp() public {
        // 由私鑰推導地址
        alice = vm.addr(alicePrivKey);
        bob   = makeAddr("bob"); // bob 不需要簽名，用 makeAddr 即可

        // 部署全新合約（部署者為 address(this)，持有全部初始供應量）
        token = new PermitToken();

        // 從部署者轉 1000 PMT 給 alice，作為測試用餘額
        assertTrue(token.transfer(alice, 1000 * 1e18));

        // 設定預設有效期限為 1 小時後
        deadline = block.timestamp + 1 hours;
    }

    // -------------------------------------------------------
    // 群組一：Signature Verification（簽名驗證）
    // -------------------------------------------------------

    /// @notice [PASS 預期] 有效簽名應成功執行 permit，並將 allowance 更新為指定值
    function test_ValidSignature_PermitSucceeds() public {
        uint256 value = 500 * 1e18;
        uint256 nonce = token.nonces(alice); // 讀取 alice 當前 nonce

        // alice 簽署授權給 bob 的 permit 訊息
        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonce, deadline);

        // 模擬由 bob 提交 permit 交易
        vm.prank(bob);
        token.permit(alice, bob, value, nonce, deadline, sig);

        // 驗證 allowance 已正確更新
        assertEq(token.allowance(alice, bob), value, "allowance should be updated");
    }

    /// @notice [REVERT 預期] 冒充者 charlie 用自己私鑰簽名，但聲稱 owner 是 alice，應被拒絕
    function test_WrongSigner_PermitFails() public {
        uint256 value = 500 * 1e18;
        uint256 nonce = token.nonces(alice);

        // charlie 用自己的私鑰簽，但 permit() 呼叫時 owner 填 alice
        // 合約 recover 出 charlie 的地址，與 alice 不符，觸發 InvalidSignature
        bytes memory sig = _signPermit(charliePrivKey, alice, bob, value, nonce, deadline);

        vm.prank(bob);
        vm.expectRevert(PermitToken.InvalidSignature.selector);
        token.permit(alice, bob, value, nonce, deadline, sig);
    }

    // -------------------------------------------------------
    // 群組二：Nonce Protection（Nonce 保護）
    // -------------------------------------------------------

    /// @notice [PASS 預期] 成功執行 permit 後，alice 的 nonce 應從 0 遞增為 1
    function test_NonceIncrementsAfterPermit() public {
        uint256 nonceBefore = token.nonces(alice); // 應為 0
        uint256 value = 100 * 1e18;

        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonceBefore, deadline);
        token.permit(alice, bob, value, nonceBefore, deadline, sig);

        // nonce 應遞增 1
        assertEq(token.nonces(alice), nonceBefore + 1, "nonce should increment");
    }

    /// @notice [REVERT 預期] 重放攻擊：第一次成功後，用相同簽名再次提交應失敗
    function test_ReplayAttack_SameSignatureFails() public {
        uint256 value = 100 * 1e18;
        uint256 nonce = token.nonces(alice);

        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonce, deadline);

        // 第一次提交：nonce 相符，成功執行
        token.permit(alice, bob, value, nonce, deadline, sig);

        // 第二次重放：nonce=0 已被消耗，鏈上現為 1
        // InvalidNonce 帶有參數，必須用 abi.encodeWithSelector 完整編碼才能匹配
        vm.expectRevert(abi.encodeWithSelector(PermitToken.InvalidNonce.selector, 0, 1));
        token.permit(alice, bob, value, nonce, deadline, sig);
    }

    // -------------------------------------------------------
    // 群組三：Expiry（期限檢查）
    // -------------------------------------------------------

    /// @notice [REVERT 預期] 使用已過期的 deadline 應觸發 PermitExpired
    function test_ExpiredSignature_Fails() public {
        uint256 value       = 100 * 1e18;
        uint256 expiredDeadline = block.timestamp - 1; // 設為當前時間的 1 秒前，確保已過期
        uint256 nonce       = token.nonces(alice);

        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonce, expiredDeadline);

        vm.expectRevert(PermitToken.PermitExpired.selector);
        token.permit(alice, bob, value, nonce, expiredDeadline, sig);
    }

    // -------------------------------------------------------
    // 群組四：Allowance & TransferFrom（授權與轉帳）
    // -------------------------------------------------------

    /// @notice [PASS 預期] permit 成功後，allowance 應精確等於授權值
    function test_AllowanceCorrectAfterPermit() public {
        uint256 value = 300 * 1e18;
        uint256 nonce = token.nonces(alice);
        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonce, deadline);

        token.permit(alice, bob, value, nonce, deadline, sig);

        assertEq(token.allowance(alice, bob), value);
    }

    /// @notice [PASS 預期] permit 後 bob 可執行 transferFrom，餘額與 allowance 皆應正確變動
    function test_TransferFromSucceedsAfterPermit() public {
        uint256 value = 200 * 1e18;
        uint256 nonce = token.nonces(alice);
        bytes memory sig = _signPermit(alicePrivKey, alice, bob, value, nonce, deadline);

        token.permit(alice, bob, value, nonce, deadline, sig);

        // bob 執行 transferFrom，將 alice 的代幣轉給自己
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, value));

        // 驗證三方狀態
        assertEq(token.balanceOf(alice),    1000 * 1e18 - value, "alice balance should decrease");
        assertEq(token.allowance(alice, bob), 0,                 "allowance should be consumed");
        assertEq(token.balanceOf(bob),      value,               "bob should receive tokens");
    }

    /// @notice [REVERT 預期] 未執行 permit 時，bob 的 allowance 為 0，transferFrom 應失敗
    function test_TransferFromFailsWithoutPermit() public {
        uint256 value = 100 * 1e18;

        vm.prank(bob);
        vm.expectRevert(); // 預期觸發 ERC20InsufficientAllowance
        token.transferFrom(alice, bob, value);
    }
}
