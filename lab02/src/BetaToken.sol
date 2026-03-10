// SPDX-License-Identifier: MIT
// 聲明授權協議為 MIT
pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本

// 從 OpenZeppelin 導入標準的 ERC20 合約
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title BetaToken
/// @notice 這是第二個 ERC20 代幣，用於 P2P 交易平台
/// @dev 與 AlphaToken 結構相同，只是名稱不同
contract BetaToken is ERC20 {
    // BetaToken 同樣繼承自 ERC20

    /// @notice 建構函數
    constructor() ERC20("BetaToken", "BETA") {
        // 代幣名稱為 "BetaToken"，符號為 "BETA"
        // 同樣鑄造 1 億個代幣給部署者
        _mint(msg.sender, 100_000_000 * 10 ** 18);
    }
}
