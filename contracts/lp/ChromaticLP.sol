// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticCommonLP, ChromaticLPLogic, IAutomateLP} from "~/lp/ChromaticCommonLP.sol";

contract ChromaticLP is ChromaticCommonLP {
    constructor(
        ChromaticLPLogic lpLogic,
        LPMeta memory lpMeta,
        ConfigParam memory config,
        int16[] memory _feeRates,
        uint16[] memory _distributionRates,
        IAutomateLP automate
    ) ChromaticCommonLP(lpLogic, lpMeta, config, _feeRates, _distributionRates, automate) {}

    function owner() public view override returns (address) {
        return s_state.market.factory().dao();
    }

    function _checkOwner() internal view override returns (bool) {
        return msg.sender == owner();
    }
}
