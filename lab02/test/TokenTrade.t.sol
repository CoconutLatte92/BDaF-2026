// SPDX-License-Identifier: MIT
// 指定本測試檔採用 MIT 授權
pragma solidity ^0.8.20;
// 指定 Solidity 編譯器版本

import "forge-std/Test.sol";
// 匯入 Foundry 標準測試基底合約 Test，提供 assertEq、vm、expectRevert 等功能

import "../src/AlphaToken.sol";
// 匯入 AlphaToken 合約

import "../src/BetaToken.sol";
// 匯入 BetaToken 合約

import "../src/TokenTrade.sol";
// 匯入 TokenTrade 合約

/// @title TokenTradeTest
/// @notice 用來測試 AlphaToken、BetaToken 與 TokenTrade 是否符合題目要求
contract TokenTradeTest is Test {
    AlphaToken public alpha;
    // 宣告 AlphaToken 實例變數

    BetaToken public beta;
    // 宣告 BetaToken 實例變數

    TokenTrade public trade;
    // 宣告 TokenTrade 實例變數

    address public owner = address(this);
    // 測試合約自己視為部署者 owner
    // 因為在 setUp 中由本測試合約部署 TokenTrade

    address public alice = address(0xA11CE);
    // 模擬 Alice 地址，作為賣家

    address public bob = address(0xB0B);
    // 模擬 Bob 地址，作為買家

    // =========================
    // 事件宣告
    // =========================
    // 為了在測試中使用 expectEmit 比對事件，需要在測試檔中宣告相同事件

    event TradeCreated(
        uint256 indexed tradeId,
        address indexed seller,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount,
        uint256 expiry
    );
    // 交易建立事件

    event TradeSettled(
        uint256 indexed tradeId,
        address indexed buyer,
        address indexed seller,
        uint256 buyerReceivedAmount,
        uint256 sellerReceivedAmount,
        uint256 fee
    );
    // 交易完成事件
    // buyerReceivedAmount = 買家收到的 inputToken 數量
    // sellerReceivedAmount = 賣家收到的 outputToken 數量（已扣 fee）

    event FeeWithdrawn(
        address indexed token,
        uint256 amount
    );
    // 手續費提領事件

    // =========================
    // 初始化
    // =========================

    function setUp() public {
        alpha = new AlphaToken();
        // 部署 AlphaToken 合約

        beta = new BetaToken();
        // 部署 BetaToken 合約

        trade = new TokenTrade(address(alpha), address(beta));
        // 部署 TokenTrade，並指定支援的兩種代幣

        alpha.transfer(alice, 10_000 ether);
        // 轉 10,000 ALPHA 給 Alice，方便她建立掛單

        beta.transfer(bob, 10_000 ether);
        // 轉 10,000 BETA 給 Bob，方便他後續結算交易

        alpha.transfer(bob, 10_000 ether);
        // 額外轉一些 ALPHA 給 Bob，方便反向交易測試

        beta.transfer(alice, 10_000 ether);
        // 額外轉一些 BETA 給 Alice，方便反向交易測試
    }

    // =========================
    // 內部輔助函式
    // =========================

    /// @notice 幫指定使用者 approve 並建立交易
    /// @param seller 建立交易的人
    /// @param inputTokenForSale 要賣出的 token 地址
    /// @param inputAmount 賣出的數量
    /// @param outputAmount 希望換得的數量
    /// @param expiry 到期時間
    /// @return tradeId 新建立的交易編號
    function _approveAndSetupTrade(
        address seller,
        address inputTokenForSale,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 expiry
    ) internal returns (uint256 tradeId) {
        vm.startPrank(seller);
        // 模擬 seller 身分開始操作

        if (inputTokenForSale == address(alpha)) {
            alpha.approve(address(trade), inputAmount);
            // 若賣出的是 ALPHA，先 approve 給交易合約
        } else {
            beta.approve(address(trade), inputAmount);
            // 若賣出的是 BETA，先 approve 給交易合約
        }

        tradeId = trade.setupTrade(
            inputTokenForSale,
            inputAmount,
            outputAmount,
            expiry
        );
        // 呼叫 setupTrade 建立交易

        vm.stopPrank();
        // 結束 seller 身分模擬
    }

    /// @notice 幫指定買家 approve 並結算交易
    /// @param buyer 買家地址
    /// @param outputToken 要支付的 token 地址
    /// @param outputAmount 要支付的數量（含 fee 前的完整對價）
    /// @param tradeId 交易編號
    function _approveAndSettle(
        address buyer,
        address outputToken,
        uint256 outputAmount,
        uint256 tradeId
    ) internal {
        vm.startPrank(buyer);
        // 模擬 buyer 身分開始操作

        if (outputToken == address(alpha)) {
            alpha.approve(address(trade), outputAmount);
            // 若買家要支付 ALPHA，先 approve 給交易合約
        } else {
            beta.approve(address(trade), outputAmount);
            // 若買家要支付 BETA，先 approve 給交易合約
        }

        trade.settleTrade(tradeId);
        // 呼叫 settleTrade 完成交易

        vm.stopPrank();
        // 結束 buyer 身分模擬
    }

    // =========================
    // 基本部署與代幣測試
    // =========================

    function test_Deployment() public {
        assertEq(trade.owner(), owner);
        // 驗證 trade 的 owner 是否為部署者（本測試合約）

        assertEq(trade.tokenA(), address(alpha));
        // 驗證 tokenA 是否正確設定為 AlphaToken

        assertEq(trade.tokenB(), address(beta));
        // 驗證 tokenB 是否正確設定為 BetaToken
    }

    function test_TokenSupply() public {
        assertEq(alpha.totalSupply(), 100_000_000 ether);
        // 驗證 AlphaToken 總供應量是否為 100,000,000 * 10^18

        assertEq(beta.totalSupply(), 100_000_000 ether);
        // 驗證 BetaToken 總供應量是否為 100,000,000 * 10^18
    }

    function test_Constructor_ZeroAddress() public {
        vm.expectRevert(TokenTrade.ZeroAddress.selector);
        // 預期傳入零地址會回退

        new TokenTrade(address(0), address(beta));
        // 測試 tokenA 為零地址的情況
    }

    function test_Constructor_SameToken() public {
        vm.expectRevert(TokenTrade.SameToken.selector);
        // 預期傳入相同 token 地址會回退

        new TokenTrade(address(alpha), address(alpha));
        // 測試 tokenA 與 tokenB 為同一地址的情況
    }

    // =========================
    // setupTrade 測試
    // =========================

    function test_SetupTrade() public {
        uint256 inputAmount = 1000 ether;
        // 設定 Alice 要賣出 1000 ALPHA

        uint256 outputAmount = 500 ether;
        // 設定 Alice 希望換得 500 BETA

        uint256 expiry = block.timestamp + 1 days;
        // 設定交易一天後過期

        uint256 aliceBalanceBefore = alpha.balanceOf(alice);
        // 記錄 Alice 建立交易前的 ALPHA 餘額

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            outputAmount,
            expiry
        );
        // 讓 Alice approve 並建立交易

        (
            address seller,
            address inputToken,
            uint256 storedInputAmount,
            address outputToken,
            uint256 storedOutputAmount,
            uint256 storedExpiry,
            bool fulfilled
        ) = trade.trades(tradeId);
        // 讀出鏈上儲存的交易資料

        assertEq(seller, alice);
        // 驗證 seller 是否為 Alice

        assertEq(inputToken, address(alpha));
        // 驗證 inputToken 是否為 ALPHA

        assertEq(storedInputAmount, inputAmount);
        // 驗證儲存的賣出數量是否正確

        assertEq(outputToken, address(beta));
        // 驗證 outputToken 是否自動設為 BETA

        assertEq(storedOutputAmount, outputAmount);
        // 驗證儲存的想換得數量是否正確

        assertEq(storedExpiry, expiry);
        // 驗證儲存的過期時間是否正確

        assertEq(fulfilled, false);
        // 驗證新交易初始狀態應為尚未完成

        assertEq(alpha.balanceOf(alice), aliceBalanceBefore - inputAmount);
        // 驗證 Alice 的 ALPHA 已被鎖進合約

        assertEq(alpha.balanceOf(address(trade)), inputAmount);
        // 驗證交易合約是否收到並鎖定這些 ALPHA
    }

    function test_SetupTrade_EmitsEvent() public {
        uint256 inputAmount = 1000 ether;
        // Alice 賣出 1000 ALPHA

        uint256 outputAmount = 500 ether;
        // Alice 希望換得 500 BETA

        uint256 expiry = block.timestamp + 1 days;
        // 設定一天後過期

        vm.startPrank(alice);
        // 模擬 Alice 身分

        alpha.approve(address(trade), inputAmount);
        // 先 approve 讓交易合約可轉走她的 ALPHA

        vm.expectEmit(true, true, true, true);
        // 預期接下來會發出完全匹配的事件

        emit TradeCreated(
            0,
            alice,
            address(alpha),
            inputAmount,
            address(beta),
            outputAmount,
            expiry
        );
        // 預期第一筆交易 tradeId = 0

        trade.setupTrade(address(alpha), inputAmount, outputAmount, expiry);
        // 建立交易並觸發事件

        vm.stopPrank();
        // 結束 Alice 身分模擬
    }

    function test_SetupTrade_InvalidToken() public {
        address fakeToken = address(0x1234);
        // 準備一個不在允許清單中的假 token 地址

        vm.startPrank(alice);
        // 模擬 Alice 身分

        vm.expectRevert(TokenTrade.InvalidToken.selector);
        // 預期會因無效 token 而回退

        trade.setupTrade(
            fakeToken,
            1000 ether,
            500 ether,
            block.timestamp + 1 days
        );
        // 嘗試使用非法 token 建立交易

        vm.stopPrank();
        // 結束 Alice 模擬
    }

    function test_SetupTrade_ZeroAmount() public {
        vm.startPrank(alice);
        // 模擬 Alice 身分

        vm.expectRevert(TokenTrade.InvalidAmount.selector);
        // 預期賣出數量為 0 時回退

        trade.setupTrade(
            address(alpha),
            0,
            500 ether,
            block.timestamp + 1 days
        );
        // inputAmount 為 0

        vm.expectRevert(TokenTrade.InvalidAmount.selector);
        // 預期想換得數量為 0 時也回退

        trade.setupTrade(
            address(alpha),
            1000 ether,
            0,
            block.timestamp + 1 days
        );
        // outputAmount 為 0

        vm.stopPrank();
        // 結束 Alice 模擬
    }

    function test_SetupTrade_InvalidExpiry() public {
        vm.startPrank(alice);
        // 模擬 Alice 身分

        vm.expectRevert(TokenTrade.InvalidExpiry.selector);
        // 預期 expiry 若等於現在，會回退

        trade.setupTrade(
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp
        );

        vm.expectRevert(TokenTrade.InvalidExpiry.selector);
        // 預期 expiry 若早於現在，也會回退

        trade.setupTrade(
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp - 1
        );

        vm.stopPrank();
        // 結束 Alice 模擬
    }

    // =========================
    // settleTrade 測試
    // =========================

    function test_SettleTrade() public {
        uint256 inputAmount = 1000 ether;
        // Alice 賣出 1000 ALPHA

        uint256 outputAmount = 500 ether;
        // Alice 希望換得 500 BETA

        uint256 expiry = block.timestamp + 1 days;
        // 一天後到期

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            outputAmount,
            expiry
        );
        // Alice 建立交易

        uint256 aliceBetaBefore = beta.balanceOf(alice);
        // 記錄 Alice 結算前持有的 BETA

        uint256 bobBetaBefore = beta.balanceOf(bob);
        // 記錄 Bob 結算前持有的 BETA

        _approveAndSettle(bob, address(beta), outputAmount, tradeId);
        // Bob approve 並結算交易
        // 他支付的是 outputToken = BETA

        uint256 fee = outputAmount / 1000;
        // 手續費改從 outputAmount 這側收取
        // 500 / 1000 = 0.5 BETA

        uint256 sellerReceives = outputAmount - fee;
        // Alice 實際收到的 BETA

        assertEq(alpha.balanceOf(bob), 10_000 ether + inputAmount);
        // 驗證 Bob 收到完整的 1000 ALPHA
        // 他原本在 setUp 中就有 10,000 ALPHA，所以要加總後驗證

        assertEq(beta.balanceOf(alice), aliceBetaBefore + sellerReceives);
        // 驗證 Alice 收到的是 BETA 扣除 fee 後的數量

        assertEq(beta.balanceOf(bob), bobBetaBefore - outputAmount);
        // 驗證 Bob 扣掉的是完整 outputAmount
        // 因為 fee 與 seller 收到的部分，合計就是 outputAmount

        assertEq(trade.accumulatedFees(address(beta)), fee);
        // 驗證手續費是否正確累積在 BETA
    }

    function test_SettleTrade_EmitsEvent() public {
        uint256 inputAmount = 1000 ether;
        // Alice 賣出 1000 ALPHA

        uint256 outputAmount = 500 ether;
        // Alice 希望換得 500 BETA

        uint256 fee = outputAmount / 1000;
        // fee = 0.5 BETA

        uint256 sellerReceives = outputAmount - fee;
        // Alice 實際收到的數量

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            outputAmount,
            block.timestamp + 1 days
        );
        // Alice 建立交易

        vm.startPrank(bob);
        // 模擬 Bob 結算

        beta.approve(address(trade), outputAmount);
        // Bob 先 approve 完整 outputAmount 給交易合約

        vm.expectEmit(true, true, true, true);
        // 預期接下來發出的事件完全匹配

        emit TradeSettled(
            tradeId,
            bob,
            alice,
            inputAmount,
            sellerReceives,
            fee
        );
        // 預期買家收到完整 inputAmount
        // 賣家收到 outputAmount 扣 fee 後的數量

        trade.settleTrade(tradeId);
        // 執行結算

        vm.stopPrank();
        // 結束 Bob 模擬
    }

    function test_SettleTrade_NotFound() public {
        vm.prank(bob);
        // 模擬 Bob 身分

        vm.expectRevert(TokenTrade.TradeNotFound.selector);
        // 預期不存在的交易編號會回退

        trade.settleTrade(999);
        // 嘗試結算不存在的交易
    }

    function test_SettleTrade_AlreadyFulfilled() public {
        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp + 1 days
        );
        // 建立交易

        _approveAndSettle(bob, address(beta), 500 ether, tradeId);
        // 先成功結算一次

        vm.startPrank(bob);
        // 再次模擬 Bob 結算同一筆

        beta.approve(address(trade), 500 ether);
        // 即便 approve 了，也不應該成功

        vm.expectRevert(TokenTrade.TradeAlreadyFulfilled.selector);
        // 預期因已完成而回退

        trade.settleTrade(tradeId);
        // 第二次結算同一筆交易

        vm.stopPrank();
        // 結束 Bob 模擬
    }

    function test_SettleTrade_Expired() public {
        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp + 1 hours
        );
        // 建立一筆一小時後到期的交易

        vm.warp(block.timestamp + 1 hours + 1);
        // 將區塊時間快轉到過期之後

        vm.startPrank(bob);
        // 模擬 Bob 結算

        beta.approve(address(trade), 500 ether);
        // 先 approve

        vm.expectRevert(TokenTrade.TradeExpired.selector);
        // 預期因交易過期而回退

        trade.settleTrade(tradeId);
        // 嘗試結算已過期交易

        vm.stopPrank();
        // 結束 Bob 模擬
    }

    // =========================
    // cancelExpiredTrade 測試
    // =========================

    function test_CancelExpiredTrade() public {
        uint256 inputAmount = 1000 ether;
        // Alice 賣出 1000 ALPHA

        uint256 expiry = block.timestamp + 1 hours;
        // 一小時後到期

        uint256 aliceBalanceBefore = alpha.balanceOf(alice);
        // 紀錄 Alice 建立交易前的 ALPHA 餘額

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            500 ether,
            expiry
        );
        // Alice 建立交易

        assertEq(alpha.balanceOf(alice), aliceBalanceBefore - inputAmount);
        // 驗證建立掛單後，ALPHA 已先被鎖進合約

        vm.warp(expiry + 1);
        // 將時間快轉到過期之後

        vm.prank(alice);
        // 只有 Alice 本人可以取消過期交易

        trade.cancelExpiredTrade(tradeId);
        // Alice 取消過期交易並取回代幣

        assertEq(alpha.balanceOf(alice), aliceBalanceBefore);
        // 驗證 Alice 已取回全部 ALPHA
    }

    function test_CancelExpiredTrade_NotSeller() public {
        uint256 expiry = block.timestamp + 1 hours;
        // 設定交易一小時後過期

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            expiry
        );
        // Alice 建立交易

        vm.warp(expiry + 1);
        // 快轉到過期後

        vm.prank(bob);
        // 模擬 Bob 來取消別人的過期交易

        vm.expectRevert(TokenTrade.NotSeller.selector);
        // 預期因 Bob 不是 seller 而回退

        trade.cancelExpiredTrade(tradeId);
        // Bob 嘗試取消 Alice 的交易
    }

    function test_CancelExpiredTrade_NotExpired() public {
        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp + 1 days
        );
        // 建立一筆尚未到期的交易

        vm.prank(alice);
        // 模擬 Alice 自己來取消

        vm.expectRevert(TokenTrade.InvalidExpiry.selector);
        // 預期因尚未過期而回退

        trade.cancelExpiredTrade(tradeId);
        // 嘗試提前取消
    }

    // =========================
    // fee 與 withdraw 測試
    // =========================

    function test_FeeCalculation() public {
        uint256 inputAmount = 10_000 ether;
        // Alice 賣出 10,000 ALPHA

        uint256 outputAmount = 5_000 ether;
        // Alice 希望換得 5,000 BETA

        uint256 expectedFee = outputAmount / 1000;
        // 手續費依 outputAmount 計算
        // 5,000 / 1000 = 5 BETA

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            outputAmount,
            block.timestamp + 1 days
        );
        // Alice 建立交易

        _approveAndSettle(bob, address(beta), outputAmount, tradeId);
        // Bob 完成交易

        assertEq(trade.accumulatedFees(address(beta)), expectedFee);
        // 驗證 fee 是否正確累積在 BETA
    }

    function test_WithdrawFee() public {
        uint256 inputAmount = 1000 ether;
        // Alice 賣出 1000 ALPHA

        uint256 outputAmount = 500 ether;
        // Alice 希望換得 500 BETA

        uint256 tradeId = _approveAndSetupTrade(
            alice,
            address(alpha),
            inputAmount,
            outputAmount,
            block.timestamp + 1 days
        );
        // 建立交易

        _approveAndSettle(bob, address(beta), outputAmount, tradeId);
        // 完成交易，產生可提領 fee

        uint256 fee = outputAmount / 1000;
        // fee = 0.5 BETA

        uint256 ownerBalanceBefore = beta.balanceOf(owner);
        // 記錄 owner 提領前的 BETA 餘額

        vm.expectEmit(true, false, false, true);
        // 預期 FeeWithdrawn 事件
        // 只精確比對 indexed token 與 amount 即可

        emit FeeWithdrawn(address(beta), fee);
        // 預期提領的是 BETA 的手續費

        trade.withdrawFee();
        // owner 提領所有累積 fee

        assertEq(beta.balanceOf(owner), ownerBalanceBefore + fee);
        // 驗證 owner 的 BETA 增加了正確 fee

        assertEq(trade.accumulatedFees(address(beta)), 0);
        // 驗證 BETA fee 池已歸零
    }

    function test_WithdrawFee_NotOwner() public {
        vm.prank(alice);
        // 模擬非 owner 的 Alice

        vm.expectRevert(TokenTrade.NotOwner.selector);
        // 預期非 owner 呼叫 withdrawFee 會回退

        trade.withdrawFee();
        // Alice 嘗試提領手續費
    }

    function test_AccumulateFees() public {
        uint256 expiry = block.timestamp + 1 days;
        // 設定兩筆交易都在一天後到期

        uint256 tradeId1 = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            expiry
        );
        // 第一筆交易：1000 ALPHA 換 500 BETA

        _approveAndSettle(bob, address(beta), 500 ether, tradeId1);
        // Bob 完成第一筆交易

        uint256 tradeId2 = _approveAndSetupTrade(
            alice,
            address(alpha),
            2000 ether,
            1000 ether,
            expiry
        );
        // 第二筆交易：2000 ALPHA 換 1000 BETA

        _approveAndSettle(bob, address(beta), 1000 ether, tradeId2);
        // Bob 完成第二筆交易

        // 第一筆 fee = 500 / 1000 = 0.5 BETA
        // 第二筆 fee = 1000 / 1000 = 1 BETA
        // 總 fee = 1.5 BETA
        assertEq(trade.accumulatedFees(address(beta)), 1.5 ether);
        // 驗證 fee 是否正確累積
    }

    // =========================
    // 其他情境測試
    // =========================

    function test_MultipleTradesIdIncrement() public {
        uint256 id1 = _approveAndSetupTrade(
            alice,
            address(alpha),
            1000 ether,
            500 ether,
            block.timestamp + 1 days
        );
        // 建立第一筆交易

        uint256 id2 = _approveAndSetupTrade(
            alice,
            address(alpha),
            2000 ether,
            1000 ether,
            block.timestamp + 2 days
        );
        // 建立第二筆交易

        assertEq(id1, 0);
        // 第一筆交易編號應為 0

        assertEq(id2, 1);
        // 第二筆交易編號應為 1

        assertEq(trade.tradeCounter(), 2);
        // 建立兩筆後，tradeCounter 應為 2
    }

    function test_ReverseTradeDirection() public {
        uint256 inputAmount = 1000 ether;
        // 這次改成 Bob 賣出 1000 BETA

        uint256 outputAmount = 500 ether;
        // Bob 希望換得 500 ALPHA

        uint256 expiry = block.timestamp + 1 days;
        // 一天後過期

        uint256 tradeId = _approveAndSetupTrade(
            bob,
            address(beta),
            inputAmount,
            outputAmount,
            expiry
        );
        // Bob 建立交易：賣 BETA 換 ALPHA

        uint256 bobAlphaBefore = alpha.balanceOf(bob);
        // 記錄 Bob 結算前的 ALPHA 餘額

        uint256 aliceAlphaBefore = alpha.balanceOf(alice);
        // 記錄 Alice 結算前的 ALPHA 餘額

        _approveAndSettle(alice, address(alpha), outputAmount, tradeId);
        // Alice 支付 ALPHA 結算交易

        uint256 fee = outputAmount / 1000;
        // fee 從 outputToken = ALPHA 這側收
        // 500 / 1000 = 0.5 ALPHA

        uint256 sellerReceives = outputAmount - fee;
        // Bob 實際收到的 ALPHA

        assertEq(beta.balanceOf(alice), 10_000 ether + inputAmount);
        // Alice 收到完整的 BETA
        // 她原本在 setUp 中已有 10,000 BETA，所以需加總驗證

        assertEq(alpha.balanceOf(bob), bobAlphaBefore + sellerReceives);
        // 驗證 Bob 收到的是 ALPHA 扣 fee 後的數量

        assertEq(alpha.balanceOf(alice), aliceAlphaBefore - outputAmount);
        // 驗證 Alice 扣掉的是完整 outputAmount 的 ALPHA

        assertEq(trade.accumulatedFees(address(alpha)), fee);
        // 驗證 fee 正確累積在 ALPHA
    }
}