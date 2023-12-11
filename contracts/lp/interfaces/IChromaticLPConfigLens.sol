// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticLPConfigLens
 * @dev Interface for viewing the configuration parameters of a Chromatic Protocol liquidity provider.
 */
interface IChromaticLPConfigLens {
    /**
     * @dev Emitted when the automation fee reserved value is updated.
     * @param newValue The new value of the automation fee reserved.
     */
    event SetAutomationFeeReserved(uint256 newValue);

    /**
     * @dev Emitted when the minimum holding value to trigger rebalance is updated.
     * @param newValue The new value of the minimum holding value to rebalance.
     */
    event SetMinHoldingValueToRebalance(uint256 newValue);

    /**
     * @dev Retrieves the target utilization rate in basis points (BPS) for the liquidity provider.
     * @return The target utilization rate in BPS.
     */
    function utilizationTargetBPS() external view returns (uint256);

    /**
     * @dev Retrieves the rebalance basis points (BPS) for the liquidity provider.
     * @return The rebalance BPS.
     */
    function rebalanceBPS() external view returns (uint256);

    /**
     * @dev Retrieves the time interval in seconds between checks for rebalance conditions.
     * @return The rebalance checking interval in seconds.
     */
    function rebalanceCheckingInterval() external view returns (uint256);

    /**
     * @dev Retrieves the amount reserved as automation fee for automated operations within the liquidity provider.
     * @return The automation fee reserved amount.
     */
    function automationFeeReserved() external view returns (uint256);

    /**
     * @dev Retrieves the minimum holding value required to trigger rebalance.
     * @return The minimum holding value to rebalance.
     */
    function minHoldingValueToRebalance() external view returns (uint256);

    /**
     * @dev Retrieves an array of distribution rates associated with different fee rates.
     * @return An array of distribution rates.
     */
    function distributionRates() external view returns (uint16[] memory);
}
