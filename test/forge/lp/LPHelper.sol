// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {AutomateLP} from "~/automation/gelato/AutomateLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";

import {BaseSetup} from "../BaseSetup.sol";

import "forge-std/console.sol";

contract LPHelper is BaseSetup {
    AutomateLP automateLP;
    ChromaticLPLogic lpLogic;

    function setUp() public virtual override {
        super.setUp();
        automateLP = new AutomateLP(address(automate));
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
        uint256 amount
    ) public returns (ChromaticLPReceipt memory receipt) {
        IERC20 token = IERC20(lp.settlementToken());
        // deal(lp.settlementToken(), msg.sender, amount);
        oracleProvider.increaseVersion(3 ether);

        token.approve(address(lp), amount);
        receipt = lp.addLiquidity(amount, msg.sender);
        console.log("ChromaticLPReceipt:", receipt.id);
    }
}
