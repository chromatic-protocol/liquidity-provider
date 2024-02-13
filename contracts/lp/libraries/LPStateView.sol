// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {LPState} from "~/lp/libraries/LPState.sol";

/**
 * @title LPStateViewLib
 * @dev A library providing view functions for querying information from an LPState instance.
 */
library LPStateViewLib {
    using LPStateViewLib for LPState;

    /**
     * @dev Retrieves the settlement token associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return IERC20Metadata The settlement token interface.
     */
    function settlementToken(LPState storage s_state) internal view returns (IERC20Metadata) {
        return s_state.market.settlementToken();
    }

    /**
     * @dev Retrieves the CLB token associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return ICLBToken The CLB token interface.
     */
    function clbToken(LPState storage s_state) internal view returns (ICLBToken) {
        return s_state.market.clbToken();
    }

    /**
     * @dev Retrieves a specific ChromaticLPReceipt by ID.
     * @param s_state The storage state of the liquidity provider.
     * @param receiptId The ID of the ChromaticLPReceipt to retrieve.
     * @return ChromaticLPReceipt The retrieved ChromaticLPReceipt.
     */
    function getReceipt(
        LPState storage s_state,
        uint256 receiptId
    ) internal view returns (ChromaticLPReceipt memory) {
        return s_state.receipts[receiptId];
    }

    /**
     * @dev Retrieves the number of fee bins in the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return uint256 The number of fee bins.
     */
    function binCount(LPState storage s_state) internal view returns (uint256) {
        return s_state.feeRates.length;
    }

    /**
     * @dev Retrieves the oracle version associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return uint256 The current oracle version.
     */
    function oracleVersion(LPState storage s_state) internal view returns (uint256) {
        return s_state.market.oracleProvider().currentVersion().version;
    }
}
