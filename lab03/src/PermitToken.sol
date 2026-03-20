// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 引入 OpenZeppelin 標準 ERC20 實作
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 引入 ECDSA 工具庫，用於從簽名中還原簽署者地址
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// 引入 MessageHashUtils，用於將原始 hash 包裝成 Ethereum Signed Message 格式
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title  PermitToken — ERC20 代幣，支援鏈下簽名授權（Permit-like approval）
/// @notice 依本次 Lab 規格實作簽名授權，持有人可離線簽署授權訊息，由他人代為提交上鏈
contract PermitToken is ERC20 {
    // 將 ECDSA 函式附加到 bytes32 型別，可直接呼叫 hash.recover(sig)
    using ECDSA for bytes32;
    // 將 MessageHashUtils 函式附加到 bytes32 型別，可直接呼叫 hash.toEthSignedMessageHash()
    using MessageHashUtils for bytes32;

    /// @notice 每個地址的當前 nonce，每次成功 permit 後遞增，防止簽名被重複使用（重放攻擊）
    mapping(address => uint256) public nonces;

    /// @dev 當 permit 的 deadline 已過期時拋出
    error PermitExpired();

    /// @dev 當還原出的簽署者地址與 owner 不符時拋出
    error InvalidSignature();

    /// @dev 當傳入的 nonce 與鏈上當前 nonce 不符時拋出，附帶提供值與期望值方便除錯
    error InvalidNonce(uint256 provided, uint256 expected);

    /// @notice 部署時鑄造 1 億顆代幣給部署者
    constructor() ERC20("PermitToken", "PMT") {
        // decimals() 預設為 18，因此實際鑄造量為 100,000,000 * 10^18 個最小單位
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }

    /// @notice 以持有人的鏈下簽名更新 spender 的授權額度（無需 owner 自行送出交易）
    /// @param owner     代幣持有人，也是簽名的產生者
    /// @param spender   被授權可動用 owner 代幣的地址
    /// @param value     本次授權的代幣數量（含 decimals）
    /// @param nonce     簽名時使用的 nonce，必須與鏈上 nonces[owner] 當前值相符
    /// @param deadline  簽名的有效截止時間戳（Unix timestamp），超過後簽名失效
    /// @param signature owner 對本次授權訊息的 65-byte ECDSA 簽名（r, s, v）
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public {
        // 步驟 1：檢查期限，若當前區塊時間已超過 deadline 則直接 revert
        if (block.timestamp > deadline) revert PermitExpired();

        // 步驟 2：呼叫 getPermitHash 計算待驗證的訊息雜湊
        //         雜湊內容包含 owner、spender、value、nonce、deadline、address(this)
        //         加入 address(this) 是為了防止相同訊息在不同合約間被重放（跨合約重放攻擊）
        bytes32 hash = getPermitHash(owner, spender, value, nonce, deadline);

        // 步驟 3：將原始 hash 包裝成標準 Ethereum Signed Message 格式後，從簽名中還原簽署者地址
        //         toEthSignedMessageHash() 會加上 "\x19Ethereum Signed Message:\n32" 前綴
        //         recover() 使用橢圓曲線數學從簽名 (r, s, v) 還原出公鑰對應的地址
        address signer = hash.toEthSignedMessageHash().recover(signature);

        // 步驟 4a：驗證 nonce — 提供的 nonce 必須等於鏈上當前值，避免舊簽名被重放
        if (nonce != nonces[owner]) revert InvalidNonce(nonce, nonces[owner]);

        // 步驟 4b：驗證簽署者 — 還原出的地址必須是 owner 本人，確保授權確實由 owner 發出
        if (signer != owner) revert InvalidSignature();

        // 步驟 5：消耗 nonce，使此簽名永久失效，防止被再次提交（重放攻擊防護核心）
        nonces[owner]++;

        // 步驟 6：呼叫 ERC20 內部函式更新 owner -> spender 的授權額度
        _approve(owner, spender, value);
    }

    /// @notice 計算 permit 訊息的 keccak256 雜湊，供鏈下簽名與鏈上驗證共用
    /// @dev    將 address(this) 納入雜湊，確保此簽名只對本合約有效
    /// @param owner    代幣持有人地址
    /// @param spender  被授權地址
    /// @param value    授權數量
    /// @param nonce    使用的 nonce 值
    /// @param deadline 有效截止時間戳
    /// @return 由上述欄位緊密編碼（encodePacked）後的 keccak256 雜湊值
    function getPermitHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                owner,        // 簽署者（代幣持有人）
                spender,      // 被授權者
                value,        // 授權額度
                nonce,        // 防重放計數器
                deadline,     // 有效期限
                address(this) // 合約地址，防跨合約重放
            )
        );
    }
}
