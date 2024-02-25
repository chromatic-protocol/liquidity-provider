// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OpenPositionInfo, CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {LogUtil, Taker} from "./Helper.sol";
import {LPHelper} from "./LPHelper.sol";

import "forge-std/console.sol";

contract ChromaticLPTest is LPHelper, LogUtil {
    using Math for uint256;

    ChromaticLP lp;

    // from IChromaticAccount
    event ClaimPosition(
        address indexed marketAddress,
        uint256 indexed positionId,
        uint256 entryPrice,
        uint256 exitPrice,
        int256 realizedPnl,
        uint256 interest,
        bytes4 cause
    );

    function setUp() public override {
        super.setUp();

        lp = deployLP(
            ChromaticLPStorageCore.ConfigParam({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 200,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: 1 ether,
                minHoldingValueToRebalance: 2 ether
            })
        );
    }

    function testAddLiquidity() public {
        assertEq(lp.totalSupply(), 0);
        logInfo(lp);

        address user1 = makeAddr("user1");

        // assertEq(ctst.balanceOf(address(this)), 1000000 ether);

        uint256 amount = 1000 ether;

        ChromaticLPReceipt memory receipt = addLiquidity(lp, amount, user1);
        console.log("ChromaticLPReceipt:", receipt.id);

        uint256[] memory receiptIds = lp.getReceiptIdsOf(user1);

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);
        assertEq(receipt.amount, amount);

        logInfo(receipt);
        logInfo(lp);

        vm.expectRevert();
        lp.settle(receipt.id);

        uint256 tokenBalanceBefore = lp.balanceOf(user1);

        bool canExec = lp.checkSettle(receipt.id);
        assertEq(false, canExec);

        increaseVersion();

        canExec = lp.checkSettle(receipt.id);
        assertEq(true, canExec);

        expectSettleAdd(lp, receipt);

        uint256 tokenBalanceAfter = lp.balanceOf(user1);
        assertEq(tokenBalanceBefore, 0);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
        console.log("totalSupply:", lp.totalSupply());
        assertEq(lp.totalSupply(), receipt.amount); // because no other tx exists

        // check whether there are no pending receipts
        receiptIds = lp.getReceiptIdsOf(user1);
        assertEq(0, receiptIds.length);

        // check flag of settlement
        receipt = lp.getReceipt(receipt.id);
        assertEq(false, receipt.needSettle);
    }

    function testRemoveLiquidity() public {
        (address user1, ChromaticLPReceipt memory receipt) = setupLiquidity(1000 ether);

        uint256 lptoken = lp.balanceOf(user1); // 1000 ether
        receipt = removeLiquidity(lp, lptoken, user1, receipt.id + 1);

        uint256[] memory receiptIds = lp.getReceiptIdsOf(user1);

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);

        vm.expectRevert();
        lp.settle(receipt.id);

        uint256 tokenBalanceBefore = ctst.balanceOf(user1);

        expectSettleRemove(lp, receipt);

        uint256 tokenBalanceAfter = ctst.balanceOf(user1);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
    }

    function setupLiquidity(uint256 amount) public returns (address, ChromaticLPReceipt memory) {
        address user1 = makeAddr("user1");

        ChromaticLPReceipt memory receipt = addLiquidity(lp, amount, user1);
        expectSettleAdd(lp, receipt);

        return (user1, receipt);
    }

    function testLossRemoveLiquidity() public {
        (address user1, ChromaticLPReceipt memory receipt) = setupLiquidity(1000 ether);
        // logCLB(lp);

        Taker taker = new Taker(router);
        taker.createAccount();
        ctst.transfer(taker.getAccount(), 100 ether);

        uint256 balanceBefore = ctst.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        logInfo(openinfo);

        bool canExec = lp.checkRebalance();
        assertEq(canExec, false);

        int256 entryPrice = 1 ether;
        int256 exitPrice = 1.5 ether;

        oracleProvider.increaseVersion(entryPrice);
        market.settleAll();

        taker.closePosition(address(market), openinfo.id);

        oracleProvider.increaseVersion(exitPrice);
        canExec = lp.checkRebalance();
        assertEq(canExec, false);

        market.settleAll();

        vm.expectEmit(true, true, false, true, taker.getAccount());
        emit ClaimPosition(
            address(market),
            openinfo.id,
            uint256(entryPrice),
            uint256(exitPrice),
            (openinfo.qty * (exitPrice - entryPrice)) / 10 ** 18,
            0,
            CLAIM_USER
        );
        taker.claimPosition(address(market), openinfo.id);

        uint256 balanceAfter = ctst.balanceOf(taker.getAccount());
        console.log(
            "taker balance before and after",
            balanceBefore / 10 ** 18,
            balanceAfter / 10 ** 18
        );
        canExec = lp.checkRebalance();
        assertEq(canExec, true);

        vm.expectEmit(true, false, false, false);
        emit RebalanceAddLiquidity(3, 5, 1 ether /* don't care */, 1111 /* don't care */);

        // vm.expectEmit(true, false, false, false);
        // emit RebalanceRemoveLiquidity(3, 5, 1111 /* don't care */);
        mockRebalance(lp, receipt.id + 1);
    }

    function testTradeRemoveLiquidity() public {
        (address user1, ChromaticLPReceipt memory receipt) = setupLiquidity(1000 ether);
        logInfo(lp, "after initial addLiquidity");

        Taker taker = new Taker(router);
        taker.createAccount();
        ctst.transfer(taker.getAccount(), 100 ether);
        uint256 balanceBefore = ctst.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        logInfo(openinfo);

        bool canExec = lp.checkRebalance();
        assertEq(canExec, false);

        int256 entryPrice = 1 ether;
        int256 exitPrice = 1.2 ether;

        oracleProvider.increaseVersion(entryPrice);
        market.settleAll();

        // uint256 lptoken = lp.balanceOf(user1);
        // bool canRebalance = false;

        uint256 lptoken = lp.balanceOf(user1) / 2;
        bool canRebalance = true;

        console.log("LP token: %d ether", lptoken / 10 ** 18);

        oracleProvider.increaseVersion(entryPrice);

        uint256 lpTokenBefore = lp.balanceOf(user1);
        uint256 usdcTokenBefore = ctst.balanceOf(user1);

        logInfo(lp, "before removeLiquidity");
        receipt = removeLiquidity(lp, lptoken, user1, receipt.id + 1);
        // receipt = lp.removeLiquidity(lptoken, user1);

        oracleProvider.increaseVersion(entryPrice);
        // vm.expectEmit();
        lp.settle(receipt.id);
        logInfo(lp, "after removeLiquidity settled");

        // uint256 lpTokenAfter = lp.balanceOf(address(this));

        // console.log(
        //     "LP token \n - before: %d\n - after remove: %d",
        //     lpTokenBefore / 10 ** 18,
        //     lpTokenAfter / 10 ** 18
        // );
        // console.log(
        //     "Settlement token \n - before: %d\n - after remove: %d",
        //     usdcTokenBefore / 10 ** 18,
        //     ctst.balanceOf(address(this)) / 10 ** 18
        // );
        // // logInfo(lp);

        taker.closePosition(address(market), openinfo.id);

        oracleProvider.increaseVersion(exitPrice);
        canExec = lp.checkRebalance();
        assertEq(canExec, canRebalance);

        market.settleAll();

        vm.expectEmit(true, true, false, true, taker.getAccount());
        emit ClaimPosition(
            address(market),
            openinfo.id,
            uint256(entryPrice),
            uint256(exitPrice),
            (openinfo.qty * (exitPrice - entryPrice)) / 10 ** 18,
            0,
            CLAIM_USER
        );
        taker.claimPosition(address(market), openinfo.id);

        uint256 balanceAfter = ctst.balanceOf(taker.getAccount());
        console.log(
            "taker balance before and after",
            balanceBefore / 10 ** 18,
            balanceAfter / 10 ** 18
        );

        logInfo(lp, "before rebalancing");

        assertEq(canRebalance, lp.checkRebalance());

        if (canRebalance) {
            mockRebalance(lp, receipt.id + 1);

            // bytes32 rebalanceTaskId = automateLP.getRebalanceTaskId(lp);
            // console.log(string(abi.encodePacked(rebalanceTaskId)));

            // increaseVersion();
            // lp.settle(receipt.id + 1);

            logInfo(lp, "after rebalancing");
            assertEq(lp.utilizationTargetBPS(), lp.utilization());
        }
    }
}
