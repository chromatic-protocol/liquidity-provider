// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";

library LPStateSetupLib {
    function initialize(
        LPState storage s_state,
        IChromaticMarket market,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) internal {
        s_state.market = market;
        _setupState(s_state, feeRates, distributionRates);
    }

    function _setupState(
        LPState storage s_state,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) private {
        uint16 totalRate;
        for (uint256 i; i < distributionRates.length; ) {
            s_state.distributionRates[feeRates[i]] = distributionRates[i];
            totalRate += distributionRates[i];

            unchecked {
                ++i;
            }
        }
        s_state.totalRate = totalRate;
        s_state.feeRates = feeRates;

        _setupClbTokenIds(s_state, feeRates);
    }

    function _setupClbTokenIds(LPState storage s_state, int16[] memory _feeRates) private {
        s_state.clbTokenIds = new uint256[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ) {
            s_state.clbTokenIds[i] = CLBTokenLib.encodeId(_feeRates[i]);

            unchecked {
                ++i;
            }
        }
    }
}
