// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticBPAutomate
 * @dev Interface for resolving and executing tasks related to Chromatic Boosting Pool.
 */
interface IChromaticBPAutomate {
    /**
     * @dev Checks whether a boost task is needed.
     * @return A boolean indicating whether a boost task is needed.
     */
    function checkBoost() external view returns (bool);

    /**
     * @dev Executes the Boost LP task by AutomateBP.
     */
    function boostTask(address feePayee, uint256 keeperFee) external;
}
