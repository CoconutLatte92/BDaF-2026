// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PermitToken.sol";

/// @notice 部署 PermitToken 並示範完整 permit 流程：
///         1. 部署合約，轉代幣給 Alice
///         2. Alice 離線簽署 permit（不廣播，純本地計算）
///         3. Bob 提交 permit 上鏈（廣播）
///         4. Bob 執行 transferFrom（廣播）
///
/// 執行方式：
///   source .env
///   forge script script/Deploy.s.sol \
///     --rpc-url $RPC_URL \
///     --broadcast \
///     --private-key $PRIVATE_KEY
contract DeployScript is Script {

    /// @dev 輔助函式：使用指定私鑰對 permit hash 產生 ECDSA 簽名
    /// @param token    已部署的 PermitToken 合約（用來呼叫 getPermitHash）
    /// @param aliceKey Alice 的私鑰（vm.sign 使用）
    /// @param alice    Alice 地址（owner）
    /// @param bob      Bob 地址（spender）
    /// @param value    授權額度
    /// @param nonce    當前 nonce
    /// @param deadline 有效期限
    /// @return 65-byte 簽名（abi.encodePacked(r, s, v)）
    function _signPermit(
        PermitToken token,
        uint256 aliceKey,
        address alice,
        address bob,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        // 呼叫合約的 getPermitHash，確保與鏈上驗證邏輯完全一致
        bytes32 hash = token.getPermitHash(alice, bob, value, nonce, deadline);

        // 包裝成 Ethereum Signed Message 格式
        bytes32 message = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );

        // 用 vm.sign 以私鑰簽名，取得 (v, r, s)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, message);

        // 打包成 65 bytes 回傳
        return abi.encodePacked(r, s, v);
    }

    function run() external {
        // ── 讀取環境變數（私鑰從 .env 載入，避免硬編碼） ──────────────
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");       // 部署者私鑰
        uint256 aliceKey    = vm.envUint("ALICE_PRIVATE_KEY"); // Alice 私鑰（用於離線簽名）
        uint256 bobKey      = vm.envUint("BOB_PRIVATE_KEY");   // Bob 私鑰（用於提交交易）

        // 由私鑰推導地址
        address alice = vm.addr(aliceKey);
        address bob   = vm.addr(bobKey);

        // ── 步驟 1：部署合約，並轉代幣給 Alice ────────────────────────
        vm.startBroadcast(deployerKey); // 開始廣播（後續交易由 deployer 簽署送出）

        PermitToken token = new PermitToken(); // 部署合約，鑄造 1 億 PMT 給 deployer
        console.log("PermitToken deployed at:", address(token));

        token.transfer(alice, 1000 * 1e18); // Alice 收到 1000 PMT（步驟 1 示範交易）
        console.log("Transferred 1000 PMT to Alice:", alice);

        vm.stopBroadcast(); // 結束 deployer 廣播

        // ── 步驟 2：Alice 離線簽署 permit（不廣播，純本地運算）─────────
        uint256 permitValue = 500 * 1e18;                  // 授權 Bob 使用 500 PMT
        uint256 nonce       = token.nonces(alice);          // 讀取 Alice 當前 nonce（應為 0）
        uint256 deadline    = block.timestamp + 1 hours;   // 簽名有效期 1 小時

        // Alice 本地計算簽名（vm.sign 不廣播，不消耗 gas）
        bytes memory signature = _signPermit(
            token, aliceKey, alice, bob, permitValue, nonce, deadline
        );

        console.log("Alice signed permit off-chain");
        console.log("spender : Bob");
        console.log("value   : 500 PMT");
        console.log("nonce   :", nonce);
        console.log("deadline:", deadline);

        // ── 步驟 3 & 4：Bob 提交 permit，然後執行 transferFrom ────────
        vm.startBroadcast(bobKey); // 開始廣播（後續交易由 Bob 簽署送出）

        // 步驟 3：Bob 提交 Alice 的簽名上鏈，更新 allowance
        token.permit(alice, bob, permitValue, nonce, deadline, signature);
        console.log("Bob submitted permit tx");
        console.log("Alice's allowance for Bob:", token.allowance(alice, bob));

        // 步驟 4：Bob 利用剛才更新的 allowance 執行 transferFrom
        token.transferFrom(alice, bob, permitValue);
        console.log("Bob called transferFrom - transferred 500 PMT from Alice");
        console.log("Bob final balance:", token.balanceOf(bob));

        vm.stopBroadcast(); // 結束 Bob 廣播
    }
}
