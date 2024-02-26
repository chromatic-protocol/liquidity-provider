// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {AutomateLP} from "~/automation/mate2/AutomateLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {BaseSetup} from "../BaseSetup.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import "forge-std/console.sol";

contract LPHelper is BaseSetup, IChromaticLPEvents {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    AutomateLP automateLP;
    ChromaticLPLogic lpLogic;

    EnumerableSet.AddressSet holders;
    EnumerableSet.UintSet receiptIds;

    function setUp() public virtual override {
        super.setUp();
        automateLP = new AutomateLP(automate);
        lpLogic = new ChromaticLPLogic(automateLP);
    }

    function deployLP(
        ChromaticLPStorageCore.ConfigParam memory params
    ) public returns (ChromaticLP) {
        int8[8] memory _feeRates = [-4, -3, -2, -1, 1, 2, 3, 4];
        uint16[8] memory _distributions = [2000, 1500, 1000, 500, 500, 1000, 1500, 2000];

        int16[] memory feeRates = new int16[](_feeRates.length);
        uint16[] memory distributionRates = new uint16[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ++i) {
            feeRates[i] = _feeRates[i];
            distributionRates[i] = _distributions[i];
        }

        ChromaticLP lp = new ChromaticLP(
            lpLogic,
            ChromaticLPStorageCore.LPMeta({lpName: "lp pool", tag: "N"}),
            params,
            feeRates,
            distributionRates,
            automateLP
        );
        lp.createRebalanceTask();
        // console.log("LP address: ", address(lp));
        // console.log("LP logic address: ", address(lpLogic));
        return lp;
    }

    function addMint(
        ChromaticLP lp,
        uint256 amount,
        address who
    ) internal returns (uint256 minted) {
        return addMint(lp, amount, who, int256(oracleProvider.currentVersion().version));
    }

    function addMint(
        ChromaticLP lp,
        uint256 amount,
        address who,
        int256 price
    ) internal returns (uint256 minted) {
        uint256 balanceBefore = lp.balanceOf(who);
        ChromaticLPReceipt memory receipt = addLiquidity(lp, amount, who);
        increaseVersion(price);
        settle(lp, receipt.id);
        minted = lp.balanceOf(who) - balanceBefore;
    }

    function removeBurn(
        ChromaticLP lp,
        uint256 amount,
        address who
    ) internal returns (uint256 minted) {
        return removeBurn(lp, amount, who, int256(oracleProvider.currentVersion().version));
    }

    function removeBurn(
        ChromaticLP lp,
        uint256 amount,
        address who,
        int256 price
    ) internal returns (uint256 burned) {
        uint256 balanceBefore = lp.balanceOf(who);
        ChromaticLPReceipt memory receipt = removeLiquidity(lp, amount, who);
        increaseVersion(price);
        settle(lp, receipt.id);
        burned = balanceBefore - lp.balanceOf(who);
    }

    function addLiquidity(
        ChromaticLP lp,
        uint256 amount,
        address who
    ) public returns (ChromaticLPReceipt memory receipt) {
        return addLiquidity(lp, amount, who, true, 0);
    }

    function actionLiquidity(
        ChromaticLP lp,
        address who,
        ChromaticLPAction action,
        uint256 amount
    ) internal returns (ChromaticLPReceipt memory receipt) {
        if (action == ChromaticLPAction.ADD_LIQUIDITY) {
            return addLiquidity(lp, amount, who);
        } else {
            return removeLiquidity(lp, amount, who);
        }
    }

    function addLiquidity(
        ChromaticLP lp,
        uint256 amount,
        address who,
        bool dealAmount,
        uint256 expectedReceiptId
    ) public returns (ChromaticLPReceipt memory receipt) {
        IERC20 token = IERC20(lp.settlementToken());
        if (dealAmount) {
            deal(lp.settlementToken(), who, amount);
        }
        vm.startPrank(who);
        token.approve(address(lp), amount);
        if (expectedReceiptId == 0) {
            vm.expectEmit(false, true, false, true, address(lp));
        } else {
            vm.expectEmit(true, true, false, true, address(lp));
        }
        emit AddLiquidity(
            expectedReceiptId,
            who,
            who,
            oracleProvider.currentVersion().version,
            amount
        );
        receipt = lp.addLiquidity(amount, who);

        vm.stopPrank();
    }

    function removeLiquidity(
        ChromaticLP lp,
        uint256 amount,
        address who
    ) public returns (ChromaticLPReceipt memory receipt) {
        return removeLiquidity(lp, amount, who, 0);
    }

    function removeLiquidity(
        ChromaticLP lp,
        uint256 amount,
        address who,
        uint256 expectedReceiptId
    ) public returns (ChromaticLPReceipt memory receipt) {
        vm.startPrank(who);
        lp.approve(address(lp), amount);
        if (expectedReceiptId == 0) {
            vm.expectEmit(false, true, false, true, address(lp));
        } else {
            vm.expectEmit(true, true, false, true, address(lp));
        }
        emit RemoveLiquidity(
            expectedReceiptId,
            who,
            who,
            oracleProvider.currentVersion().version,
            amount
        );
        receipt = lp.removeLiquidity(amount, who);

        vm.stopPrank();
    }

    function increaseVersion() public {
        // any value
        oracleProvider.increaseVersion(int256(oracleProvider.currentVersion().version));
    }

    function increaseVersion(int256 price) public {
        oracleProvider.increaseVersion(price);
    }

    function expectSettleAdd(ChromaticLP lp, ChromaticLPReceipt memory receipt) public {
        expectSettleAdd(lp, receipt, 3 ether);
    }

    function expectSettleRemove(ChromaticLP lp, ChromaticLPReceipt memory receipt) public {
        expectSettleRemove(lp, receipt, 3 ether);
    }

    function expectSettleAdd(
        ChromaticLP lp,
        ChromaticLPReceipt memory receipt,
        int256 price
    ) public {
        oracleProvider.increaseVersion(price);
        vm.expectEmit(true, false, false, false, address(lp));
        emit AddLiquiditySettled(
            receipt.id,
            receipt.provider /* dont care */,
            receipt.recipient /* dont care */,
            receipt.amount /* dont care */,
            receipt.amount /* dont care */,
            0
        );
        settle(lp, receipt.id);
    }

    function expectSettleRemove(
        ChromaticLP lp,
        ChromaticLPReceipt memory receipt,
        int256 price
    ) public {
        oracleProvider.increaseVersion(price);
        vm.expectEmit(true, false, false, false, address(lp));
        emit RemoveLiquiditySettled(
            receipt.id,
            receipt.provider /* dont care */,
            receipt.recipient /* dont care */,
            receipt.amount /* dont care */,
            receipt.amount /* dont care */,
            0,
            0
        );
        settle(lp, receipt.id);
    }

    function mockRebalance(ChromaticLP lp, uint256 receiptId) internal {
        vm.prank(address(automate));
        automateLP.rebalance(address(lp));
        vm.stopPrank();
        increaseVersion();
        settle(lp, receiptId);
    }

    function settle(ChromaticLP lp, uint256 receiptId) internal {
        ChromaticLPReceipt memory receipt = lp.getReceipt(receiptId);
        lp.settle(receiptId);
        if (lp.balanceOf(receipt.recipient) > 0) {
            holders.add(receipt.recipient);
        } else if (lp.balanceOf(receipt.recipient) == 0) {
            holders.remove(receipt.recipient);
        }
    }
}
