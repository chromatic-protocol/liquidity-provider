// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticBPAction
 * @dev Interface for interacting with Chromatic Boosting Pool actions.
 */
interface IChromaticBPAction {
    /**
     * @dev Deposit function for contributing to the boosting pool.
     * @param amount The amount to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev Refund function for withdrawing funds from the boosting pool.
     */
    function refund() external;

    /**
     * @dev Claim liquidity function for accessing liquidity from the boosting pool.
     */
    function claimLiquidity() external;

    /**
     * @dev Boost LP function for boosting liquidity of the LP.
     */
    function boostLP() external;
}
