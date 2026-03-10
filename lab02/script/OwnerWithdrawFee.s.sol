// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TokenTrade.sol";

/// @title OwnerWithdrawFee
/// @notice 合約擁有者提領累積手續費的腳本
/// @dev 只有部署 TokenTrade 的地址可以執行
contract OwnerWithdrawFee is Script {

    function run() external {
        // ===== 讀取環境變數 =====

        // Owner 的私鑰（就是部署合約時用的私鑰）
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");

        // TokenTrade 合約地址
        address tradeContract = vm.envAddress("TRADE_CONTRACT");

        // ===== 開始廣播交易 =====
        vm.startBroadcast(ownerPrivateKey);

        // 呼叫 withdrawFee 函數
        // 這會把合約中累積的所有手續費（ALPHA 和 BETA）轉給 owner
        TokenTrade(tradeContract).withdrawFee();

        console.log("Fees withdrawn successfully!");

        vm.stopBroadcast();

        // 執行完成後，記錄交易哈希
    }
}
