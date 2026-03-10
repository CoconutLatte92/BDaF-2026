// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 導入 Foundry 的腳本框架
// Script 提供了 vm.startBroadcast 等功能用於鏈上交易
import "forge-std/Script.sol";

// 導入要部署的合約
import "../src/AlphaToken.sol";
import "../src/BetaToken.sol";
import "../src/TokenTrade.sol";

/// @title DeployAll
/// @notice 一次部署所有合約到 Zircuit Testnet
contract DeployAll is Script {

    /// @notice 執行部署
    /// @dev 使用 forge script 命令執行
    function run() external {
        // 從環境變數讀取私鑰
        // 注意：私鑰應該放在 .env 檔案中，不要直接寫在程式碼裡
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // vm.startBroadcast 開始記錄交易
        // 之後的所有合約部署和函數呼叫都會被發送到區塊鏈
        vm.startBroadcast(deployerPrivateKey);

        // ===== 部署 AlphaToken =====
        // new 關鍵字會部署新合約
        // 部署者會收到 1 億個 ALPHA 代幣
        AlphaToken alpha = new AlphaToken();
        // console.log 會在執行時輸出訊息（方便記錄地址）
        console.log("AlphaToken deployed at:", address(alpha));

        // ===== 部署 BetaToken =====
        BetaToken beta = new BetaToken();
        console.log("BetaToken deployed at:", address(beta));

        // ===== 部署 TokenTrade =====
        // 傳入兩個代幣地址作為建構函數參數
        TokenTrade trade = new TokenTrade(address(alpha), address(beta));
        console.log("TokenTrade deployed at:", address(trade));

        // 停止廣播
        vm.stopBroadcast();

        // 執行完成後，終端會顯示三個合約地址
        // 請記錄下來用於後續步驟
    }
}
