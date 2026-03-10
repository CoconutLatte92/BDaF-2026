// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AlphaToken.sol";
import "../src/TokenTrade.sol";

/// @title AliceSetupTrade
/// @notice Alice 建立交易掛單的腳本
/// @dev 執行前需要設定環境變數
contract AliceSetupTrade is Script {

    function run() external {
        // ===== 讀取環境變數 =====

        // Alice 的私鑰（用於簽署交易）
        uint256 alicePrivateKey = vm.envUint("ALICE_PRIVATE_KEY");

        // 已部署的合約地址（從 Deploy.s.sol 的輸出取得）
        address alphaToken = vm.envAddress("ALPHA_TOKEN");
        address tradeContract = vm.envAddress("TRADE_CONTRACT");

        // ===== 設定交易參數 =====

        // Alice 要賣出 1000 個 ALPHA
        uint256 inputAmount = 1000 ether;
        // Alice 想換 500 個 BETA
        uint256 outputAmount = 500 ether;
        // 過期時間：1 天後
        uint256 expiry = block.timestamp + 1 days;

        // ===== 開始廣播交易 =====
        vm.startBroadcast(alicePrivateKey);

        // 步驟 1: 授權 TokenTrade 合約可以動用 Alice 的 ALPHA
        // 這是必要的，因為 ERC20 需要先 approve 才能讓其他合約 transferFrom
        AlphaToken(alphaToken).approve(tradeContract, inputAmount);
        console.log("Approved TokenTrade to spend", inputAmount);

        // 步驟 2: 建立交易掛單
        uint256 tradeId = TokenTrade(tradeContract).setupTrade(
            alphaToken,     // 要賣的代幣
            inputAmount,    // 賣出數量
            outputAmount,   // 想換的數量
            expiry          // 過期時間
        );
        console.log("Trade created with ID:", tradeId);

        vm.stopBroadcast();

        // 執行完成後，記錄：
        // 1. 交易哈希（在終端輸出中找）
        // 2. Trade ID（用於 Bob 結算）
    }
}
