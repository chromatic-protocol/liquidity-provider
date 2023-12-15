// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title The IChromaticLPAdmin interface is designed to facilitate the administration of liquidity provider within the Chromatic Protocol.
 * @author
 * @notice
 */
interface IChromaticLPAdmin {
    /**
     * @dev Initiates the creation of a rebalance task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     */
    function createRebalanceTask() external;

    /**
     * @dev Cancels the currently active rebalance task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     */
    function cancelRebalanceTask() external;

    /**
     * @dev Cancels the settle task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     * @param  receiptId The receipt ID associated with the settle execution.
     */
    function cancelSettleTask(uint256 receiptId) external;

    /**
     * @dev Additional data to be used in the rebalance process.
     * @param _automationFeeReserved The new value for the reserved automation fee.
     */
    function setAutomationFeeReserved(uint256 _automationFeeReserved) external;

    /**
     * @dev Additional data to be used in the rebalance process.
     * @param _minHoldingValueToRebalance The new value for the required minimum amount to trigger rebalance.
     */
    function setMinHoldingValueToRebalance(uint256 _minHoldingValueToRebalance) external;
}
