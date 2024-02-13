// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseSetup} from "../BaseSetup.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IChromaticLPLens, ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {IChromaticAccount} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticAccount.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {AutomateLP} from "~/automation/gelato/AutomateLP.sol";

import {LogUtil, Taker} from "./Helper.sol";

import "forge-std/console.sol";

contract ChromaticLPTest is BaseSetup, LogUtil {
    using Math for uint256;

    AutomateLP automateLP;
    ChromaticLP lp;
    ChromaticLPLogic lpLogic;

    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 settlementAdded,
        uint256 lpTokenAmount,
        uint256 keeperFee
    );

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 burningAmount,
        uint256 witdrawnSettlementAmount,
        uint256 refundedAmount,
        uint256 keeperFee
    );

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);

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
        int8[8] memory _feeRates = [-4, -3, -2, -1, 1, 2, 3, 4];
        uint16[8] memory _distributions = [2000, 1500, 1000, 500, 500, 1000, 1500, 2000];

        int16[] memory feeRates = new int16[](_feeRates.length);
        uint16[] memory distributionRates = new uint16[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ++i) {
            feeRates[i] = _feeRates[i];
            distributionRates[i] = _distributions[i];
        }
        automateLP = new AutomateLP(address(automate));
        lpLogic = new ChromaticLPLogic(automateLP);

        lp = new ChromaticLP(
            lpLogic,
            ChromaticLPStorageCore.LPMeta({lpName: "lp pool", tag: "N"}),
            ChromaticLPStorageCore.ConfigParam({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 500,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: 1 ether,
                minHoldingValueToRebalance: 2 ether
            }),
            feeRates,
            distributionRates,
            automateLP
        );
        lp.createRebalanceTask();
        console.log("LP address: ", address(lp));
        console.log("LP logic address: ", address(lpLogic));
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
        console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        canExec = lp.checkRebalance();
        assertEq(canExec, true);

        automateLP.rebalance(address(lp));
    }

    function testTradeRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

        Taker taker = new Taker(router);
        taker.createAccount();
        ctst.transfer(taker.getAccount(), 100 ether);
        // uint256 balanceBefore = ctst.balanceOf(taker.getAccount());

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
        uint256 lpTokenAfter = lp.balanceOf(address(this));

        console.log(
            "LP token \n - before: %d\n - after remove: %d",
            lpTokenBefore / 10 ** 18,
            lpTokenAfter / 10 ** 18
        );
        console.log(
            "Settlement token \n - before: %d\n - after remove: %d",
            usdcTokenBefore / 10 ** 18,
            ctst.balanceOf(address(this)) / 10 ** 18
        );
        logInfo(lp);

        // WIP
        // taker.closePosition(address(market), openinfo.id);

        // oracleProvider.increaseVersion(exitPrice);
        // canExec = lp.checkRebalance();
        // assertEq(canExec, false);

        // market.settleAll();

        // vm.expectEmit(true, true, false, true, taker.getAccount());
        // emit ClaimPosition(
        //     address(market),
        //     openinfo.id,
        //     uint256(entryPrice),
        //     uint256(exitPrice),
        //     (openinfo.qty * (exitPrice - entryPrice)) / 10 ** 18,
        //     0,
        //     CLAIM_USER
        // );
        // taker.claimPosition(address(market), openinfo.id);

        // uint256 balanceAfter = ctst.balanceOf(taker.getAccount());
        // console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        // canExec = lp.checkRebalance();
        // assertEq(canExec, true);
        // canExec = lp.checkRebalance();
        // assertEq(canExec, true);

        // automateLP.rebalance(address(lp));
    }
}
