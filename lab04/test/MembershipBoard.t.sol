// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 引入 Foundry 測試框架
import "forge-std/Test.sol";
// 引入待測試的 MembershipBoard 合約
import "../src/MembershipBoard.sol";

/// @title MembershipBoard 測試合約
/// @notice 包含功能測試、Gas 分析及批量大小實驗
contract MembershipBoardTest is Test {
    // 待測試的合約實例
    MembershipBoard public board;
    // 合約擁有者地址（即本測試合約自身）
    address public owner;
    // 非擁有者地址，用於測試權限控制
    address public nonOwner;

    // 從 members.json 載入的 1,000 個會員地址
    address[] public memberAddrs;

    // ============ 重新宣告事件（用於 expectEmit 比對） ============
    event MemberAdded(address indexed member);
    event MerkleRootSet(bytes32 indexed root);

    /// @notice 每個測試案例執行前的初始設定
    function setUp() public {
        // 測試合約本身即為 owner（因為是由它部署 MembershipBoard）
        owner = address(this);
        // 建立一個非擁有者地址
        nonOwner = address(0xBEEF);

        // 部署新的 MembershipBoard 合約
        board = new MembershipBoard();

        // 使用 Foundry 的 vm.readFile 讀取 members.json 檔案
        string memory json = vm.readFile("members.json");
        // 使用 vm.parseJsonAddressArray 解析 JSON 中的 .addresses 陣列
        address[] memory addrs = vm.parseJsonAddressArray(json, ".addresses");
        // 將解析出的地址存入 storage 陣列，供後續測試使用
        for (uint256 i = 0; i < addrs.length; i++) {
            memberAddrs.push(addrs[i]);
        }
    }

    // ============================================================
    // 輔助函式：透過 FFI 呼叫 Node.js 取得 Merkle Root
    // ============================================================
    /// @notice 呼叫 script/merkle.js 取得 Merkle Root
    /// @return Merkle Tree 的根雜湊值（bytes32）
    function _getMerkleRoot() internal returns (bytes32) {
        // 構建 FFI 命令：node script/merkle.js root
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "script/merkle.js";
        cmd[2] = "root";
        // 執行 FFI 命令，取得原始 bytes 輸出
        bytes memory result = vm.ffi(cmd);
        // 將 bytes 轉型為 bytes32（Merkle Root 固定為 32 bytes）
        return bytes32(result);
    }

    // ============================================================
    // 輔助函式：透過 FFI 呼叫 Node.js 取得某地址的 Merkle Proof
    // ============================================================
    /// @notice 呼叫 script/merkle.js 取得指定地址的 Merkle Proof
    /// @param _addr 要取得 proof 的地址
    /// @return proof Merkle 證明路徑（bytes32 陣列）
    function _getMerkleProof(address _addr) internal returns (bytes32[] memory) {
        // 構建 FFI 命令：node script/merkle.js proof <address>
        string[] memory cmd = new string[](4);
        cmd[0] = "node";
        cmd[1] = "script/merkle.js";
        cmd[2] = "proof";
        cmd[3] = vm.toString(_addr); // 將 address 轉為字串傳入
        // 執行 FFI，取得連續的 bytes32 拼接結果
        bytes memory result = vm.ffi(cmd);

        // 計算 proof 長度（每個元素 32 bytes）
        uint256 proofLength = result.length / 32;
        bytes32[] memory proof = new bytes32[](proofLength);
        // 從原始 bytes 中逐個取出 bytes32 元素
        for (uint256 i = 0; i < proofLength; i++) {
            bytes32 element;
            assembly {
                // 從 result 的第 (32 + i*32) 位元組處載入 32 bytes
                // 前 32 bytes 是 Solidity 的 bytes length 前綴，因此要跳過
                element := mload(add(result, add(32, mul(i, 32))))
            }
            proof[i] = element;
        }
        return proof;
    }

    // ============================================================
    // Part 1 測試：addMember（逐一新增）
    // ============================================================

    /// @notice 測試擁有者可以成功新增單一會員
    function test_AddMember_Owner() public {
        // 預期會觸發 MemberAdded 事件，第一個 indexed 參數需匹配
        vm.expectEmit(true, false, false, false);
        emit MemberAdded(memberAddrs[0]);
        // 執行新增會員
        board.addMember(memberAddrs[0]);
        // 驗證該地址已被標記為會員
        assertTrue(board.members(memberAddrs[0]));
    }

    /// @notice 測試非擁有者呼叫 addMember 應被拒絕
    function test_AddMember_NonOwnerReverts() public {
        // 模擬由 nonOwner 發起交易
        vm.prank(nonOwner);
        // 預期 revert，錯誤為 OwnableUnauthorizedAccount
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        board.addMember(memberAddrs[0]);
    }

    /// @notice 測試重複新增同一會員應被拒絕
    function test_AddMember_DuplicateReverts() public {
        // 先新增一次
        board.addMember(memberAddrs[0]);
        // 再次新增相同地址，預期 revert
        vm.expectRevert("Already a member");
        board.addMember(memberAddrs[0]);
    }

    // ============================================================
    // Part 2 測試：batchAddMembers（批量新增）
    // ============================================================

    /// @notice 測試擁有者可以批量新增會員
    function test_BatchAddMembers_Owner() public {
        // 準備 5 個地址的批次
        address[] memory batch = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            batch[i] = memberAddrs[i];
        }
        // 執行批量新增
        board.batchAddMembers(batch);
        // 驗證所有 5 個地址都已成為會員
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(board.members(batch[i]));
        }
    }

    /// @notice 測試非擁有者呼叫 batchAddMembers 應被拒絕
    function test_BatchAddMembers_NonOwnerReverts() public {
        address[] memory batch = new address[](1);
        batch[0] = memberAddrs[0];
        // 模擬由 nonOwner 發起
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        board.batchAddMembers(batch);
    }

    /// @notice 測試批量中包含重複地址應被拒絕
    function test_BatchAddMembers_DuplicateReverts() public {
        // 先新增 memberAddrs[0]
        board.addMember(memberAddrs[0]);
        // 批量中包含已存在的 memberAddrs[0]
        address[] memory batch = new address[](2);
        batch[0] = memberAddrs[1];
        batch[1] = memberAddrs[0]; // 重複
        vm.expectRevert("Already a member");
        board.batchAddMembers(batch);
    }

    /// @notice 測試批量新增全部 1,000 名會員後，抽樣驗證是否正確儲存
    function test_BatchAddMembers_All1000() public {
        // 以每批 250 個地址分批新增
        uint256 batchSize = 250;
        for (uint256 i = 0; i < memberAddrs.length; i += batchSize) {
            uint256 end = i + batchSize;
            if (end > memberAddrs.length) end = memberAddrs.length;
            uint256 len = end - i;
            // 建立本批次的地址陣列
            address[] memory batch = new address[](len);
            for (uint256 j = 0; j < len; j++) {
                batch[j] = memberAddrs[i + j];
            }
            board.batchAddMembers(batch);
        }
        // 抽樣驗證第 1、500、1000 名會員
        assertTrue(board.members(memberAddrs[0]));
        assertTrue(board.members(memberAddrs[499]));
        assertTrue(board.members(memberAddrs[999]));
    }

    // ============================================================
    // Part 3 測試：setMerkleRoot
    // ============================================================

    /// @notice 測試擁有者可以成功設定 Merkle Root
    function test_SetMerkleRoot_Owner() public {
        // 透過 FFI 取得 Merkle Root
        bytes32 root = _getMerkleRoot();
        // 預期觸發 MerkleRootSet 事件
        vm.expectEmit(true, false, false, false);
        emit MerkleRootSet(root);
        // 設定 Merkle Root
        board.setMerkleRoot(root);
        // 驗證鏈上儲存的值與預期一致
        assertEq(board.merkleRoot(), root);
    }

    /// @notice 測試非擁有者呼叫 setMerkleRoot 應被拒絕
    function test_SetMerkleRoot_NonOwnerReverts() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        board.setMerkleRoot(keccak256("fake"));
    }

    // ============================================================
    // Part 4 測試：verifyMemberByMapping
    // ============================================================

    /// @notice 測試已註冊的會員查詢應回傳 true
    function test_VerifyMapping_RegisteredMember() public {
        board.addMember(memberAddrs[0]);
        assertTrue(board.verifyMemberByMapping(memberAddrs[0]));
    }

    /// @notice 測試未註冊的地址查詢應回傳 false
    function test_VerifyMapping_NonMember() public {
        assertFalse(board.verifyMemberByMapping(nonOwner));
    }

    // ============================================================
    // Part 5 測試：verifyMemberByProof
    // ============================================================

    /// @notice 測試使用有效 proof 驗證已註冊會員應回傳 true
    function test_VerifyProof_ValidProof() public {
        // 設定 Merkle Root
        bytes32 root = _getMerkleRoot();
        board.setMerkleRoot(root);
        // 取得 memberAddrs[0] 的 proof
        bytes32[] memory proof = _getMerkleProof(memberAddrs[0]);
        // 驗證應通過
        assertTrue(board.verifyMemberByProof(memberAddrs[0], proof));
    }

    /// @notice 測試使用錯誤的 proof（地址 A 的 proof 驗證地址 B）應回傳 false
    function test_VerifyProof_InvalidProof() public {
        bytes32 root = _getMerkleRoot();
        board.setMerkleRoot(root);
        // 取得 memberAddrs[0] 的 proof，但用來驗證 memberAddrs[1]
        bytes32[] memory proof = _getMerkleProof(memberAddrs[0]);
        assertFalse(board.verifyMemberByProof(memberAddrs[1], proof));
    }

    /// @notice 測試非會員使用空 proof 驗證應回傳 false
    function test_VerifyProof_NonMember() public {
        bytes32 root = _getMerkleRoot();
        board.setMerkleRoot(root);
        // nonOwner 不在 Merkle Tree 中，空 proof 無法通過驗證
        bytes32[] memory emptyProof = new bytes32[](0);
        assertFalse(board.verifyMemberByProof(nonOwner, emptyProof));
    }

    // ============================================================
    // Gas 分析
    // ============================================================

    /// @notice 測量 addMember 單次呼叫的 Gas 消耗
    function test_Gas_AddMemberSingle() public {
        uint256 gasBefore = gasleft();
        board.addMember(memberAddrs[0]);
        uint256 gasUsed = gasBefore - gasleft();
        // 輸出 Gas 數值到測試日誌
        emit log_named_uint(unicode"addMember 單次呼叫 gas", gasUsed);
    }

    /// @notice 測量 batchAddMembers 新增全部 1,000 名會員的總 Gas（每批 250）
    function test_Gas_BatchAddMembers_250() public {
        uint256 batchSize = 250;
        uint256 totalGas = 0;
        for (uint256 i = 0; i < memberAddrs.length; i += batchSize) {
            uint256 end = i + batchSize;
            if (end > memberAddrs.length) end = memberAddrs.length;
            uint256 len = end - i;
            // 建立批次陣列
            address[] memory batch = new address[](len);
            for (uint256 j = 0; j < len; j++) {
                batch[j] = memberAddrs[i + j];
            }
            // 測量本批次的 Gas
            uint256 gasBefore = gasleft();
            board.batchAddMembers(batch);
            uint256 gasUsed = gasBefore - gasleft();
            totalGas += gasUsed;
            // 輸出每批的 Gas
            emit log_named_uint(
                string(abi.encodePacked(unicode"第 ", vm.toString(i / batchSize + 1), " 批 gas（每批 250）")),
                gasUsed
            );
        }
        // 輸出總 Gas
        emit log_named_uint(unicode"batchAddMembers 總 gas（全部 1000 人）", totalGas);
    }

    /// @notice 測量 setMerkleRoot 的 Gas 消耗
    function test_Gas_SetMerkleRoot() public {
        bytes32 root = _getMerkleRoot();
        uint256 gasBefore = gasleft();
        board.setMerkleRoot(root);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("setMerkleRoot gas", gasUsed);
    }

    /// @notice 測量透過 mapping 驗證會員的 Gas 消耗
    function test_Gas_VerifyMemberByMapping() public {
        // 先新增會員，使 mapping 中有資料
        board.addMember(memberAddrs[0]);
        uint256 gasBefore = gasleft();
        board.verifyMemberByMapping(memberAddrs[0]);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("verifyMemberByMapping gas", gasUsed);
    }

    /// @notice 測量透過 Merkle Proof 驗證會員的 Gas 消耗
    function test_Gas_VerifyMemberByProof() public {
        // 先設定 Merkle Root 並取得 proof
        bytes32 root = _getMerkleRoot();
        board.setMerkleRoot(root);
        bytes32[] memory proof = _getMerkleProof(memberAddrs[0]);
        // 測量驗證 Gas
        uint256 gasBefore = gasleft();
        board.verifyMemberByProof(memberAddrs[0], proof);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("verifyMemberByProof gas", gasUsed);
        // 輸出 proof 長度（即 Merkle Tree 深度，log2(1000) ≈ 10）
        emit log_named_uint("proof 長度（樹深度）", proof.length);
    }

    // ============ 批量大小實驗 ============

    /// @notice 以 batch size = 50 測量
    function test_Gas_BatchSize_50() public { _benchBatchSize(50); }
    /// @notice 以 batch size = 100 測量
    function test_Gas_BatchSize_100() public { _benchBatchSize(100); }
    /// @notice 以 batch size = 250 測量
    function test_Gas_BatchSize_250() public { _benchBatchSize(250); }
    /// @notice 以 batch size = 500 測量
    function test_Gas_BatchSize_500() public { _benchBatchSize(500); }

    /// @notice 批量大小實驗的內部實作
    /// @param batchSize 每批新增的會員數量
    /// @dev 每次建立全新的合約實例，避免重複地址衝突
    function _benchBatchSize(uint256 batchSize) internal {
        // 部署全新的合約，確保 mapping 為空
        MembershipBoard freshBoard = new MembershipBoard();
        uint256 totalGas = 0;
        uint256 batchCount = 0;
        for (uint256 i = 0; i < memberAddrs.length; i += batchSize) {
            uint256 end = i + batchSize;
            if (end > memberAddrs.length) end = memberAddrs.length;
            uint256 len = end - i;
            // 建立本批次的地址陣列
            address[] memory batch = new address[](len);
            for (uint256 j = 0; j < len; j++) {
                batch[j] = memberAddrs[i + j];
            }
            // 測量本批次的 Gas
            uint256 gasBefore = gasleft();
            freshBoard.batchAddMembers(batch);
            uint256 gasUsed = gasBefore - gasleft();
            totalGas += gasUsed;
            batchCount++;
        }
        // 計算每位會員的平均 Gas
        uint256 perMember = totalGas / memberAddrs.length;
        // 輸出結果
        emit log_named_uint(string(abi.encodePacked("batchSize=", vm.toString(batchSize), " 總 gas")), totalGas);
        emit log_named_uint(string(abi.encodePacked("batchSize=", vm.toString(batchSize), " 每人 gas")), perMember);
        emit log_named_uint(string(abi.encodePacked("batchSize=", vm.toString(batchSize), " 批次數")), batchCount);
    }
}
