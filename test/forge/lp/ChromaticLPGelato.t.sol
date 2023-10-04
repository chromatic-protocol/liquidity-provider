// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../BaseSetup.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {MarketLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacet.sol";
import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";
import {IChromaticLPLens, ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {ChromaticLPStorageGelato} from "~/lp/base/gelato/ChromaticLPStorageGelato.sol";
import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {IChromaticAccount} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticAccount.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPGelato} from "~/lp/contracts/gelato/ChromaticLPGelato.sol";
import {ChromaticLPLogicGelato} from "~/lp/contracts/gelato/ChromaticLPLogicGelato.sol";

import {LogUtil, Taker} from "./Helper.sol";

import "forge-std/console.sol";

contract ChromaticLPGelatoTest is BaseSetup, LogUtil {
    using Math for uint256;

    ChromaticLPGelato lp;
    ChromaticLPLogicGelato lpLogic;

    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(
        uint256 indexed receiptId,
        uint256 settlementAdded,
        uint256 lpTokenAmount
    );

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(
        uint256 indexed receiptId,
        uint256 burningAmount,
        uint256 witdrawnSettlementAmount,
        uint256 refundedAmount
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
        for (uint256 i; i < _feeRates.length; i++) {
            feeRates[i] = _feeRates[i];
            distributionRates[i] = _distributions[i];
        }

        lpLogic = new ChromaticLPLogicGelato(
            ChromaticLPStorageGelato.AutomateParam({
                automate: address(automate),
                opsProxyFactory: address(opf)
            })
        );

        lp = new ChromaticLPGelato(
            lpLogic,
            ChromaticLPStorage.LPMeta({lpName: "lp pool", tag: "N"}),
            ChromaticLPStorage.Config({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 500,
                rebalanceCheckingInterval: 1 hours,
                settleCheckingInterval: 1 minutes
            }),
            feeRates,
            distributionRates,
            ChromaticLPStorageGelato.AutomateParam({
                automate: address(automate),
                opsProxyFactory: address(opf)
            })
        );
        console.log("LP address: ", address(lp));
        console.log("LP logic address: ", address(lpLogic));
    }

    function testAddLiquidity() public {
        assertEq(lp.totalSupply(), 0);
        logInfo(lp);

        // by super.setUp()
        assertEq(usdc.balanceOf(address(this)), 1000000 ether);
        oracleProvider.increaseVersion(3 ether);
        // approve first
        usdc.approve(address(lp), 1000000 ether);

        vm.expectEmit(true, true, false, true, address(lp));
        uint256 amount = 1000 ether;
        emit AddLiquidity(1, address(this), oracleProvider.currentVersion().version, amount);

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
        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit AddLiquiditySettled(receipt.id, receipt.amount, receipt.amount);
        assertEq(true, lp.settle(receipt.id));

        uint256 tokenBalanceAfter = lp.balanceOf(address(this));
        assertEq(tokenBalanceBefore, 0);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
        console.log("totalSupply:", lp.totalSupply());
        assertEq(lp.totalSupply(), receipt.amount);

        receiptIds = lp.getReceiptIdsOf(address(this));
        assertEq(0, receiptIds.length);
        receipt = lp.getReceipt(receipt.id);
        assertEq(0, receipt.id);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();
        uint256 lptoken = lp.balanceOf(address(this)); // 1000 ether

        lp.approve(address(lp), lptoken);

        vm.expectEmit(true, true, false, true, address(lp));
        emit RemoveLiquidity(2, address(this), oracleProvider.currentVersion().version, lptoken);

        ChromaticLPReceipt memory receipt = lp.removeLiquidity(lptoken, address(this));

        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = usdc.balanceOf(address(this));
        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit RemoveLiquiditySettled(receipt.id, receipt.amount, receipt.amount, 0);
        assertEq(true, lp.settle(receipt.id));
        uint256 tokenBalanceAfter = usdc.balanceOf(address(this));
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
    }

    function testLossRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

        Taker taker = new Taker(router);
        taker.createAccount();
        usdc.transfer(taker.getAccount(), 100 ether);
        uint256 balanceBefore = usdc.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        logInfo(openinfo);

        (bool canExec, ) = lp.resolveRebalance();
        assertEq(canExec, false);

        int256 entryPrice = 1 ether;
        int256 exitPrice = 2 ether;

        oracleProvider.increaseVersion(entryPrice);
        market.settleAll();

        taker.closePosition(address(market), openinfo.id);

        oracleProvider.increaseVersion(exitPrice);
        (canExec, ) = lp.resolveRebalance();
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

        uint256 balanceAfter = usdc.balanceOf(taker.getAccount());
        console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        (canExec, ) = lp.resolveRebalance();
        assertEq(canExec, true);

        lp.rebalance();
    }

    function testTradeRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

        Taker taker = new Taker(router);
        taker.createAccount();
        usdc.transfer(taker.getAccount(), 100 ether);
        // uint256 balanceBefore = usdc.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        logInfo(openinfo);

        (bool canExec, ) = lp.resolveRebalance();
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
        uint256 usdcTokenBefore = usdc.balanceOf(address(this));

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
            usdc.balanceOf(address(this)) / 10 ** 18
        );
        logInfo(lp);
        // taker.closePosition(address(market), openinfo.id);

        // oracleProvider.increaseVersion(exitPrice);
        // (canExec, ) = lp.resolveRebalance();
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

        // uint256 balanceAfter = usdc.balanceOf(taker.getAccount());
        // console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        // (canExec, ) = lp.resolveRebalance();
        // assertEq(canExec, true);

        // lp.rebalance();
    }
}