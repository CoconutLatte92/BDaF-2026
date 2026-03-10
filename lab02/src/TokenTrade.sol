// SPDX-License-Identifier: MIT
// 指定此合約使用 MIT 授權條款
pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本為 0.8.20 以上、0.9.0 以下

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 匯入 ERC20 標準介面，讓合約可以呼叫 transfer、transferFrom、balanceOf 等功能

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// 匯入 SafeERC20 工具，避免某些 ERC20 實作不完全時造成轉帳失敗卻不報錯的問題

/// @title TokenTrade
/// @notice 一個支援兩種 ERC20 代幣互換的 P2P 交易合約
/// @dev 支援限時掛單、交易結算、過期取消、0.1% 手續費提領
contract TokenTrade {
    // 宣告對 IERC20 類型啟用 SafeERC20 的安全轉帳函式
    using SafeERC20 for IERC20;

    // =========================
    // 狀態變數
    // =========================

    address public owner;
    // 紀錄合約擁有者，部署者即為 owner，只有 owner 可以提領手續費

    address public tokenA;
    // 紀錄此交易合約支援的第一種代幣地址

    address public tokenB;
    // 紀錄此交易合約支援的第二種代幣地址

    uint256 public tradeCounter;
    // 交易流水號計數器，每建立一筆新交易就加一，用來產生唯一 tradeId

    struct Trade {
        address seller;
        // 建立掛單的賣家地址

        address inputToken;
        // 賣家要賣出的代幣地址

        uint256 inputAmount;
        // 賣家鎖進合約、準備賣出的代幣數量

        address outputToken;
        // 賣家想換得的另一種代幣地址

        uint256 outputAmount;
        // 賣家希望收到的對價代幣數量（未扣手續費前）

        uint256 expiry;
        // 交易到期時間，使用 Unix timestamp

        bool fulfilled;
        // 紀錄交易是否已完成或已被取消，用來防止重複結算
    }

    mapping(uint256 => Trade) public trades;
    // 以 tradeId 對應到交易內容的映射表

    mapping(address => uint256) public accumulatedFees;
    // 紀錄每種代幣在合約中已累積多少手續費
    // 例如 accumulatedFees[tokenA] 表示 tokenA 累積的 fee

    // =========================
    // 事件
    // =========================

    event TradeCreated(
        uint256 indexed tradeId,
        // 交易編號，設為 indexed 方便查詢

        address indexed seller,
        // 建立交易的賣家地址，設為 indexed 方便查詢

        address inputToken,
        // 賣家賣出的代幣地址

        uint256 inputAmount,
        // 賣家賣出的代幣數量

        address outputToken,
        // 賣家希望換得的代幣地址

        uint256 outputAmount,
        // 賣家希望換得的代幣數量

        uint256 expiry
        // 交易到期時間
    );

    event TradeSettled(
        uint256 indexed tradeId,
        // 已完成結算的交易編號

        address indexed buyer,
        // 完成交易的買家地址

        address indexed seller,
        // 原始掛單的賣家地址

        uint256 buyerReceivedAmount,
        // 買家實際收到的 inputToken 數量
        // 在本版本中，買家拿到完整 inputAmount

        uint256 sellerReceivedAmount,
        // 賣家實際收到的 outputToken 數量
        // 在本版本中，為 outputAmount 扣除手續費後的數量

        uint256 fee
        // 本次交易收取的手續費數量
    );

    event FeeWithdrawn(
        address indexed token,
        // 被提領的手續費是屬於哪一種代幣

        uint256 amount
        // 提領的手續費數量
    );

    // =========================
    // 自訂錯誤
    // =========================

    error InvalidToken();
    // 當傳入的代幣地址不是 tokenA 或 tokenB 時拋出

    error InvalidAmount();
    // 當數量為 0 或不合法時拋出

    error InvalidExpiry();
    // 當 expiry 不在未來，或取消時尚未過期，拋出此錯誤

    error TradeNotFound();
    // 當指定的 tradeId 找不到對應交易時拋出

    error TradeExpired();
    // 當交易已過期卻仍嘗試結算時拋出

    error TradeAlreadyFulfilled();
    // 當交易已經完成或已取消，卻又再次操作時拋出

    error NotOwner();
    // 當非 owner 嘗試呼叫 onlyOwner 函式時拋出

    error ZeroAddress();
    // 當建構子收到零地址時拋出

    error SameToken();
    // 當建構子收到相同的兩個 token 地址時拋出

    error NotSeller();
    // 當非原賣家嘗試取消過期交易時拋出

    // =========================
    // 修飾器
    // =========================

    modifier onlyOwner() {
        // 限制只有 owner 可以執行被修飾的函式
        if (msg.sender != owner) revert NotOwner();
        // 若呼叫者不是 owner，直接回退
        _;
        // 若檢查通過，繼續執行原函式內容
    }

    // =========================
    // 建構函式
    // =========================

    /// @notice 部署合約時設定可交易的兩種代幣
    /// @param _tokenA 第一種代幣地址
    /// @param _tokenB 第二種代幣地址
    constructor(address _tokenA, address _tokenB) {
        // 檢查 tokenA 是否為零地址
        if (_tokenA == address(0)) revert ZeroAddress();

        // 檢查 tokenB 是否為零地址
        if (_tokenB == address(0)) revert ZeroAddress();

        // 檢查兩個 token 是否為相同地址
        if (_tokenA == _tokenB) revert SameToken();

        owner = msg.sender;
        // 將部署者設為 owner

        tokenA = _tokenA;
        // 設定第一種支援的代幣地址

        tokenB = _tokenB;
        // 設定第二種支援的代幣地址
    }

    // =========================
    // 外部函式
    // =========================

    /// @notice 建立一筆交易掛單，並將賣家的 inputToken 鎖進合約
    /// @param inputTokenForSale 要賣出的代幣地址
    /// @param inputTokenAmount 要賣出的代幣數量
    /// @param outputTokenAsk 希望換得的另一種代幣數量
    /// @param expiry 此交易的到期時間
    /// @return tradeId 新建立交易的編號
    function setupTrade(
        address inputTokenForSale,
        uint256 inputTokenAmount,
        uint256 outputTokenAsk,
        uint256 expiry
    ) external returns (uint256 tradeId) {
        // 檢查賣出的代幣必須是 tokenA 或 tokenB 其中之一
        if (inputTokenForSale != tokenA && inputTokenForSale != tokenB) {
            revert InvalidToken();
        }

        // 檢查賣出數量與想換得數量都不能為 0
        if (inputTokenAmount == 0 || outputTokenAsk == 0) {
            revert InvalidAmount();
        }

        // 檢查到期時間必須晚於目前區塊時間
        if (expiry <= block.timestamp) {
            revert InvalidExpiry();
        }

        address outputToken = (inputTokenForSale == tokenA) ? tokenB : tokenA;
        // 若賣出的是 tokenA，則想換得的必然是 tokenB
        // 若賣出的是 tokenB，則想換得的必然是 tokenA

        IERC20(inputTokenForSale).safeTransferFrom(
            msg.sender,
            address(this),
            inputTokenAmount
        );
        // 將賣家的 inputToken 轉進合約鎖定
        // 呼叫前，賣家必須先 approve 此合約足夠額度

        tradeId = tradeCounter;
        // 先取目前的流水號當作本次交易編號

        tradeCounter += 1;
        // 建立完交易後，計數器加 1，供下一筆交易使用

        trades[tradeId] = Trade({
            seller: msg.sender,
            inputToken: inputTokenForSale,
            inputAmount: inputTokenAmount,
            outputToken: outputToken,
            outputAmount: outputTokenAsk,
            expiry: expiry,
            fulfilled: false
        });
        // 將這筆新交易完整存進 trades 映射表中

        emit TradeCreated(
            tradeId,
            msg.sender,
            inputTokenForSale,
            inputTokenAmount,
            outputToken,
            outputTokenAsk,
            expiry
        );
        // 發出交易建立事件，方便前端與區塊鏈瀏覽器追蹤
    }

    /// @notice 結算指定交易，由買家呼叫
    /// @param id 要結算的交易編號
    function settleTrade(uint256 id) external {
        Trade storage trade = trades[id];
        // 從 storage 中取出指定 id 的交易資料
        // 使用 storage 代表後續修改會直接寫回鏈上

        if (trade.seller == address(0)) revert TradeNotFound();
        // 若 seller 為零地址，代表此交易不存在

        if (trade.fulfilled) revert TradeAlreadyFulfilled();
        // 若交易已完成或已取消，就不能再次操作

        if (block.timestamp > trade.expiry) revert TradeExpired();
        // 若目前時間已超過到期時間，代表此交易已過期，不能再結算

        trade.fulfilled = true;
        // 先將交易標記為已完成
        // 這樣可以降低重入攻擊或重複結算風險

        uint256 fee = trade.outputAmount / 1000;
        // 計算 0.1% 手續費
        // 本版本改成從買家支付給賣家的 outputToken 那一側收費
        // 0.1% = 1 / 1000

        uint256 sellerReceives = trade.outputAmount - fee;
        // 計算賣家實際會收到多少 outputToken
        // 賣家收到的是總 outputAmount 扣掉 fee

        accumulatedFees[trade.outputToken] += fee;
        // 將本次手續費累積到 outputToken 對應的 fee 池中

        if (fee > 0) {
            IERC20(trade.outputToken).safeTransferFrom(
                msg.sender,
                address(this),
                fee
            );
            // 先把 fee 從買家帳戶轉進合約
            // 因此買家需要先對 outputToken approve 給本合約足夠額度
        }

        IERC20(trade.outputToken).safeTransferFrom(
            msg.sender,
            trade.seller,
            sellerReceives
        );
        // 再將扣掉手續費後的 outputToken 從買家轉給賣家

        IERC20(trade.inputToken).safeTransfer(
            msg.sender,
            trade.inputAmount
        );
        // 最後由合約把完整的 inputToken 轉給買家
        // 本版本中，買家拿到完整數量，不從這一側扣費

        emit TradeSettled(
            id,
            msg.sender,
            trade.seller,
            trade.inputAmount,
            sellerReceives,
            fee
        );
        // 發出交易完成事件
        // buyerReceivedAmount = 完整 inputAmount
        // sellerReceivedAmount = outputAmount 扣 fee 後的數量
    }

    /// @notice 取消已過期交易，並將鎖定代幣退回原賣家
    /// @param id 要取消的交易編號
    function cancelExpiredTrade(uint256 id) external {
        Trade storage trade = trades[id];
        // 讀取指定交易

        if (trade.seller == address(0)) revert TradeNotFound();
        // 若交易不存在則回退

        if (trade.fulfilled) revert TradeAlreadyFulfilled();
        // 若交易早已結算或取消，則不可再次取消

        if (block.timestamp <= trade.expiry) revert InvalidExpiry();
        // 若目前時間尚未超過 expiry，代表還沒過期，不能取消

        if (msg.sender != trade.seller) revert NotSeller();
        // 限制只有原賣家本人可以取消過期交易並取回代幣

        trade.fulfilled = true;
        // 標記為已完成，防止重複取消

        IERC20(trade.inputToken).safeTransfer(trade.seller, trade.inputAmount);
        // 將原本鎖在合約中的 inputToken 全數退回給賣家
    }

    /// @notice 提領合約中累積的所有手續費
    /// @dev 只有 owner 可呼叫
    function withdrawFee() external onlyOwner {
        uint256 feeA = accumulatedFees[tokenA];
        // 讀取 tokenA 累積的手續費數量

        uint256 feeB = accumulatedFees[tokenB];
        // 讀取 tokenB 累積的手續費數量

        if (feeA > 0) {
            accumulatedFees[tokenA] = 0;
            // 先將 tokenA 的 fee 紀錄歸零，避免重入或重複提領

            IERC20(tokenA).safeTransfer(owner, feeA);
            // 將 tokenA 的累積手續費轉給 owner

            emit FeeWithdrawn(tokenA, feeA);
            // 發出 tokenA 手續費提領事件
        }

        if (feeB > 0) {
            accumulatedFees[tokenB] = 0;
            // 先將 tokenB 的 fee 紀錄歸零

            IERC20(tokenB).safeTransfer(owner, feeB);
            // 將 tokenB 的累積手續費轉給 owner

            emit FeeWithdrawn(tokenB, feeB);
            // 發出 tokenB 手續費提領事件
        }
    }

    // =========================
    // 查詢函式
    // =========================

    /// @notice 取得指定交易的完整內容
    /// @param id 交易編號
    /// @return 該筆交易的 Trade 結構內容
    function getTrade(uint256 id) external view returns (Trade memory) {
        return trades[id];
        // 回傳對應 tradeId 的交易資訊
    }
}