// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IChromaticBPAdmin
 * @dev Interface for administrative functions related to the Chromatic Boosting Pool within the Chromatic Protocol.
 */
interface IChromaticBPAdmin {
    /**
     * @dev Cancels the funding of the boosting pool.
     */
    function cancelBP() external;
}
