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
     * @dev Retrieves information about the settlement task identified by receiptId.
     * @param receiptId Unique identifier for the settlement receipt
     * @return upkeepNeeded Boolean indicating whether upkeep is needed for the settlement.
     * @return performData Additional data to be used in the settlement process.
     */
    function resolveSettle(
        uint256 receiptId
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Retrieves information about the active rebalance task.
     * @return upkeepNeeded Boolean indicating whether upkeep is needed for the rebalance.
     * @return performData Additional data to be used in the rebalance process.
     */
    function resolveRebalance() external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Additional data to be used in the rebalance process.
     * @param automationFeeReserved The new value for the reserved automation fee.
     */
    function setAutomationFeeReserved(uint256 automationFeeReserved) external;
}
