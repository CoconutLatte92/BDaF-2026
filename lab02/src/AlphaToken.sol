// SPDX-License-Identifier: MIT
// 聲明授權協議為 MIT，這是開源常用的授權方式
pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本，^0.8.20 表示可以用 0.8.20 以上的版本編譯

// 從 OpenZeppelin 導入標準的 ERC20 合約
// ERC20 是以太坊上最常見的代幣標準
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title AlphaToken
/// @notice 這是第一個 ERC20 代幣，用於 P2P 交易平台
contract AlphaToken is ERC20 {
    // AlphaToken 繼承自 ERC20，自動獲得所有 ERC20 的功能
    // 包括：transfer, approve, transferFrom, balanceOf 等

    /// @notice 建構函數，部署合約時執行一次
    constructor() ERC20("AlphaToken", "ALPHA") {
        // 呼叫父合約 ERC20 的建構函數
        // 第一個參數 "AlphaToken" 是代幣名稱
        // 第二個參數 "ALPHA" 是代幣符號（類似股票代號）

        // _mint 是內部函數，用於鑄造代幣
        // msg.sender 是部署合約的地址（會收到所有代幣）
        // 100_000_000 * 10 ** 18 = 1億個代幣（乘以 10^18 是因為 ERC20 預設 18 位小數）
        _mint(msg.sender, 100_000_000 * 10 ** 18);
    }
}
