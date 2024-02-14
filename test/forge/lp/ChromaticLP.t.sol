// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OpenPositionInfo, CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {AutomateLP} from "~/automation/gelato/AutomateLP.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {LogUtil, Taker} from "./Helper.sol";
import {LPHelper} from "./LPHelper.sol";

import "forge-std/console.sol";

contract ChromaticLPTest is LPHelper, LogUtil, IChromaticLPEvents {
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
                rebalanceBPS: 500,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: 1 ether,
                minHoldingValueToRebalance: 2 ether
            })
        );
    }

    function testAddLiquidity() public {
        assertEq(lp.totalSupply(), 0);
        logInfo(lp);

        // by super.setUp()
        assertEq(ctst.balanceOf(address(this)), 1000000 ether);
        oracleProvider.increaseVersion(3 ether);
        // approve first
        ctst.approve(address(lp), 1000000 ether);

        vm.expectEmit(true, true, false, true, address(lp));
        uint256 amount = 1000 ether;
        emit AddLiquidity(
            2,
            address(this),
            address(this),
            oracleProvider.currentVersion().version,
            amount
        );

        ChromaticLPReceipt memory receipt = lp.addLiquidity(amount, address(this));
        console.log("ChromaticLPReceipt:", receipt.id);

        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);
        assertEq(receipt.amount, amount);

        logInfo(receipt);
        logInfo(lp);

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = lp.balanceOf(address(this));

        bool canExec = lp.checkSettle(receipt.id);
        assertEq(false, canExec);

        oracleProvider.increaseVersion(3 ether);

        canExec = lp.checkSettle(receipt.id);
        assertEq(true, canExec);

        vm.expectEmit(true, false, false, true, address(lp));
        emit AddLiquiditySettled(
            receipt.id,
            address(this),
            address(this),
            receipt.amount,
            receipt.amount,
            0
        );
        assertEq(true, lp.settle(receipt.id));

        uint256 tokenBalanceAfter = lp.balanceOf(address(this));
        assertEq(tokenBalanceBefore, 0);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
        console.log("totalSupply:", lp.totalSupply());
        assertEq(lp.totalSupply(), receipt.amount);

        receiptIds = lp.getReceiptIdsOf(address(this));
        assertEq(0, receiptIds.length);
        receipt = lp.getReceipt(receipt.id);
        assertEq(false, receipt.needSettle);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();
        uint256 lptoken = lp.balanceOf(address(this)); // 1000 ether

        lp.approve(address(lp), lptoken);

        vm.expectEmit(true, true, false, true, address(lp));
        emit RemoveLiquidity(
            3,
            address(this),
            address(this),
            oracleProvider.currentVersion().version,
            lptoken
        );

        ChromaticLPReceipt memory receipt = lp.removeLiquidity(lptoken, address(this));

        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = ctst.balanceOf(address(this));
        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit RemoveLiquiditySettled(
            receipt.id,
            address(this),
            address(this),
            receipt.amount,
            receipt.amount,
            0,
            0
        );
        assertEq(true, lp.settle(receipt.id));
        uint256 tokenBalanceAfter = ctst.balanceOf(address(this));
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
    }

    function testLossRemoveLiquidity() public {
        // logInfo(lp);
        testAddLiquidity();
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
        int256 exitPrice = 2 ether;

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

        automateLP.rebalance(address(lp));
    }

    function testTradeRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

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

        uint256 lptoken = lp.balanceOf(address(this));
        console.log("LP token: %d ether", lptoken / 10 ** 18);
        lp.approve(address(lp), lptoken);

        oracleProvider.increaseVersion(entryPrice);

        uint256 lpTokenBefore = lp.balanceOf(address(this));
        uint256 usdcTokenBefore = ctst.balanceOf(address(this));

        logInfo(lp);

        ChromaticLPReceipt memory receipt = lp.removeLiquidity(lptoken, address(this));

        logInfo(lp);

        oracleProvider.increaseVersion(entryPrice);
        assertEq(true, lp.settle(receipt.id));
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

        logInfo(lp);

        canExec = lp.checkRebalance();
        assertEq(canExec, false);
        // canExec = lp.checkRebalance();
        // assertEq(canExec, true);

        // automateLP.rebalance(address(lp));
    }
}
