// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticBPEvents
 * @dev Interface for the events emitted by Chromatic Boosting Pool.
 */
interface IChromaticBPEvents {
    /**
     * @dev Emitted when a liquidity provider deposits funds into the boosting pool.
     * @param provider The address of the liquidity provider.
     * @param amount The deposited amount.
     */
    event BPDeposited(address indexed provider, uint256 amount);

    /**
     * @dev Emitted when a liquidity provider requests a refund from the boosting pool.
     * @param provider The address of the liquidity provider.
     * @param amount The refunded amount.
     */
    event BPRefunded(address indexed provider, uint256 amount);

    /**
     * @dev Emitted when a liquidity provider claims liquidity from the boosting pool.
     * @param provider The address of the liquidity provider.
     * @param bpTokenAmount The amount of BP tokens claimed.
     * @param lpTokenAmount The corresponding LP token amount.
     */
    event BPClaimed(address indexed provider, uint256 bpTokenAmount, uint256 lpTokenAmount);

    /**
     * @dev Emitted when the boosting LP is executed.
     */
    event BPExecuted();

    /**
     * @dev Emitted when the total LP token amount used for boosting is updated.
     * @param totalLPToken The updated total LP token amount.
     */
    event BPSettleUpdated(uint256 totalLPToken);
}
