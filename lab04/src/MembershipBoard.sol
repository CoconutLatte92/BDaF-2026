// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 引入 OpenZeppelin 的 Ownable 合約，提供 onlyOwner 修飾符與擁有者管理功能
import "@openzeppelin/contracts/access/Ownable.sol";
// 引入 OpenZeppelin 的 MerkleProof 工具庫，用於鏈上驗證 Merkle 證明
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title MembershipBoard — 會員管理合約
/// @notice 透過三種方式（逐一新增、批量新增、Merkle Root）管理會員，並比較 Gas 成本
contract MembershipBoard is Ownable {
    // ============ 狀態變數 ============

    /// @notice 以 mapping 儲存會員資格，address => 是否為會員
    mapping(address => bool) public members;

    /// @notice 儲存 Merkle Tree 的根雜湊值，用於鏈上驗證會員資格
    bytes32 public merkleRoot;

    // ============ 事件 ============

    /// @notice 當新會員被加入時觸發
    event MemberAdded(address indexed member);

    /// @notice 當 Merkle Root 被更新時觸發
    event MerkleRootSet(bytes32 indexed root);

    // ============ 建構函式 ============

    /// @notice 部署時將 msg.sender 設為合約擁有者
    constructor() Ownable(msg.sender) {}

    // ============ Part 1：逐一新增會員 ============

    /// @notice 新增單一會員到 mapping 中
    /// @param _member 要新增的會員地址
    /// @dev 僅限擁有者呼叫；若地址已是會員則 revert
    function addMember(address _member) external onlyOwner {
        // 檢查該地址是否已經是會員，若是則回退交易
        require(!members[_member], "Already a member");
        // 將該地址標記為會員（寫入 storage，觸發 SSTORE 操作）
        members[_member] = true;
        // 發出 MemberAdded 事件
        emit MemberAdded(_member);
    }

    // ============ Part 2：批量新增會員 ============

    /// @notice 一次新增多個會員到 mapping 中
    /// @param _members 要新增的會員地址陣列（使用 calldata 節省 gas）
    /// @dev 僅限擁有者呼叫；若任何地址已是會員則 revert
    function batchAddMembers(address[] calldata _members) external onlyOwner {
        // 迴圈遍歷所有待新增的地址
        for (uint256 i = 0; i < _members.length; i++) {
            // 逐一檢查是否重複
            require(!members[_members[i]], "Already a member");
            // 寫入 storage
            members[_members[i]] = true;
            // 為每個新增的會員發出事件
            emit MemberAdded(_members[i]);
        }
    }

    // ============ Part 3：設定 Merkle Root ============

    /// @notice 設定 Merkle Tree 的根雜湊值（鏈下計算，鏈上僅儲存 root）
    /// @param _root 由 1,000 個會員地址構建的 Merkle Tree 根
    /// @dev 僅限擁有者呼叫；只需一次 SSTORE，Gas 成本極低
    function setMerkleRoot(bytes32 _root) external onlyOwner {
        // 將 Merkle Root 寫入 storage（僅佔一個 slot = 32 bytes）
        merkleRoot = _root;
        // 發出 MerkleRootSet 事件
        emit MerkleRootSet(_root);
    }

    // ============ Part 4：透過 Mapping 驗證會員 ============

    /// @notice 透過 mapping 查詢某地址是否為會員
    /// @param _member 待查詢的地址
    /// @return 是否為會員（true/false）
    /// @dev 只需一次 SLOAD，O(1) 時間複雜度
    function verifyMemberByMapping(address _member) external view returns (bool) {
        return members[_member];
    }

    // ============ Part 5：透過 Merkle Proof 驗證會員 ============

    /// @notice 透過 Merkle Proof 驗證某地址是否為會員
    /// @param _member 待驗證的地址
    /// @param _proof 該地址對應的 Merkle 證明路徑（bytes32 陣列）
    /// @return 驗證結果（true/false）
    /// @dev 使用雙重 keccak256 雜湊（防止 second preimage attack），
    ///      與 OpenZeppelin StandardMerkleTree 相容
    function verifyMemberByProof(
        address _member,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        // 計算葉節點雜湊：先 abi.encode 地址，再做兩次 keccak256
        // 第一次 keccak256：對 abi.encode(_member) 取雜湊
        // 第二次 keccak256：對第一次的結果再取雜湊（bytes.concat 將 bytes32 轉為 bytes）
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_member))));
        // 使用 OpenZeppelin 的 MerkleProof.verify 驗證 proof 是否能推導出 merkleRoot
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }
}
