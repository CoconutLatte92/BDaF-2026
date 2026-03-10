// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BetaToken.sol";
import "../src/TokenTrade.sol";

/// @title BobSettleTrade
/// @notice Bob 結算交易的腳本
/// @dev 執行前需要設定環境變數，包括 TRADE_ID
contract BobSettleTrade is Script {

    function run() external {
        // ===== 讀取環境變數 =====

        // Bob 的私鑰
        uint256 bobPrivateKey = vm.envUint("BOB_PRIVATE_KEY");

        // 已部署的合約地址
        address betaToken = vm.envAddress("BETA_TOKEN");
        address tradeContract = vm.envAddress("TRADE_CONTRACT");

        // 要結算的交易 ID（從 Alice 建立交易時取得）
        uint256 tradeId = vm.envUint("TRADE_ID");

        // ===== 開始廣播交易 =====
        vm.startBroadcast(bobPrivateKey);

        // 步驟 1: 查詢交易詳情
        // 這樣可以知道需要支付多少 BETA
        TokenTrade.Trade memory tradeInfo = TokenTrade(tradeContract).getTrade(tradeId);

        console.log("Settling trade ID:", tradeId);
        console.log("Output amount required:", tradeInfo.outputAmount);

        // 步驟 2: 授權 TokenTrade 合約可以動用 Bob 的 BETA
        BetaToken(betaToken).approve(tradeContract, tradeInfo.outputAmount);
        console.log("Approved TokenTrade to spend Beta tokens");

        // 步驟 3: 結算交易
        // 這會：
        // - 從 Bob 轉 outputAmount 的 BETA 給 Alice
        // - 從合約轉 inputAmount（扣除 0.1% 手續費）的 ALPHA 給 Bob
        TokenTrade(tradeContract).settleTrade(tradeId);
        console.log("Trade settled successfully!");

        vm.stopBroadcast();

        // 執行完成後，記錄交易哈希
    }
}
