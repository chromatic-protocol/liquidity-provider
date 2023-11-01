// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";

/**
 * @title LPStateSetupLib
 * @dev A library providing functions for initializing and setting up the state of an LP (Liquidity Provider) in the Chromatic Protocol.
 */
library LPStateSetupLib {
    /**
     * @dev Initializes the LPState with the provided market, fee rates, and distribution rates.
     * @param s_state The storage state of the liquidity provider.
     * @param market The Chromatic Market interface to be associated with the LPState.
     * @param feeRates The array of fee rates for different bins.
     * @param distributionRates The array of distribution rates corresponding to fee rates.
     */
    function initialize(
        LPState storage s_state,
        IChromaticMarket market,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) internal {
        s_state.market = market;
        _setupState(s_state, feeRates, distributionRates);
    }

    /**
     * @dev Sets up the internal state of the LPState with the provided fee rates and distribution rates.
     * @param s_state The storage state of the liquidity provider.
     * @param feeRates The array of fee rates for different bins.
     * @param distributionRates The array of distribution rates corresponding to fee rates.
     */
    function _setupState(
        LPState storage s_state,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) private {
        uint256 totalRate;
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

    /**
     * @dev Sets up the CLB (Cumulative Loyalty Bonus) token IDs based on the provided fee rates.
     * @param s_state The storage state of the liquidity provider.
     * @param _feeRates The array of fee rates for different bins.
     */
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
