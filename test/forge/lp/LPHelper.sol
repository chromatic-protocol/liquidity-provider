// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
import "forge-std/console.sol";

contract LPHelper is BaseSetup, IChromaticLPEvents {
    AutomateLP automateLP;
    ChromaticLPLogic lpLogic;

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

    function addLiquidity(
        ChromaticLP lp,
        uint256 amount,
        address who
    ) public returns (ChromaticLPReceipt memory receipt) {
        return addLiquidity(lp, amount, who, true, 0);
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
        assertTrue(lp.settle(receipt.id), "settleAddFailed");
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
        assertTrue(lp.settle(receipt.id), "settleRemoveFailed");
    }

    function mockRebalance(ChromaticLP lp, uint256 receiptId) internal {
        vm.prank(address(automate));
        automateLP.rebalance(address(lp));
        vm.stopPrank();
        increaseVersion();
        lp.settle(receiptId);
    }
}
