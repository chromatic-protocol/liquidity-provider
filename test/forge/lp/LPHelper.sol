// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {AutomateLP} from "~/automation/gelato/AutomateLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";

import "forge-std/console.sol";

contract LPHelper is Test {
    AutomateLP automateLP;
    ChromaticLPLogic lpLogic;

    function init(address automate) public virtual {
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
}
