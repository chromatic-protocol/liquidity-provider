// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticBPAutomate
 * @dev Interface for resolving and executing tasks related to Chromatic Boosting Pool.
 */
interface IChromaticBPAutomate {
    function checkBoost() external view returns (bool);

    /**
     * @dev Executes the Boost LP task by AutomateBP.
     */
    function boost(address feePayee, uint256 keeperFee) external;
}
