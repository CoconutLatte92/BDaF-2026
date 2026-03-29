// 此腳本用於在鏈下生成 Merkle Tree 的 root 和 proof
// Foundry 測試透過 FFI（vm.ffi）呼叫此腳本

const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// 讀取 members.json 中的 1,000 個地址
const membersData = JSON.parse(fs.readFileSync("members.json", "utf8"));
const addresses = membersData.addresses;

// 使用 OpenZeppelin StandardMerkleTree 構建 Merkle Tree
// 每個葉節點格式為 [address]，編碼方式為 ["address"]
// 內部會自動進行雙重 keccak256 雜湊（防止 second preimage attack）
const values = addresses.map((addr) => [addr]);
const tree = StandardMerkleTree.of(values, ["address"]);

// 根據命令列參數決定輸出內容
const command = process.argv[2];

if (command === "root") {
  // 輸出 Merkle Root（bytes32 格式的十六進位字串）
  process.stdout.write(tree.root);
} else if (command === "proof") {
  // 輸出指定地址的 Merkle Proof
  const targetAddr = process.argv[3];
  const proof = tree.getProof([targetAddr]);
  // 將 proof 陣列中的每個 bytes32 去掉 0x 前綴後拼接成連續的十六進位字串
  // Foundry 測試中會將其解析為 bytes32[] 陣列
  const encoded = proof.map((p) => p.slice(2)).join("");
  process.stdout.write("0x" + encoded);
} else if (command === "dump") {
  // 輸出完整的 root 和所有地址的 proof 到 merkle_data.json
  // 可用於除錯或手動驗證
  const output = {
    root: tree.root,
    proofs: {},
  };
  for (const [i, v] of tree.entries()) {
    const addr = v[0];
    output.proofs[addr.toLowerCase()] = tree.getProof(i);
  }
  fs.writeFileSync("merkle_data.json", JSON.stringify(output, null, 2));
  console.log("已將 merkle_data.json 寫入，包含 root 及所有 proof");
} else {
  console.error("用法：node script/merkle.js [root|proof <address>|dump]");
  process.exit(1);
}
