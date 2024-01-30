// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";

/**
 * @title IAutomateLP
 * @dev Interface for automating tasks related to liquidity providers (LPs) within a protocol.
 */
interface IAutomateGelatoLP is IAutomateLP {
    /**
     * @dev Emitted when a rebalance task cancellation is successful.
     * @param lp The address of the liquidity provider.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancelRebalanceTaskSucceeded(address lp, bytes32 taskId);

    /**
     * @dev Emitted when a rebalance task cancellation fails.
     * @param lp The address of the liquidity provider.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancelRebalanceTaskFailed(address lp, bytes32 taskId);

    /**
     * @dev Emitted when a settle task cancellation is successful.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the cancelled settle task.
     * @param taskId The unique identifier of the cancelled settle task.
     */
    event CancelSettleTaskSucceeded(address lp, uint256 receiptId, bytes32 taskId);

    /**
     * @dev Emitted when a settle task cancellation fails.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the cancelled settle task.
     * @param taskId The unique identifier of the cancelled settle task.
     */
    event CancelSettleTaskFailed(address lp, uint256 receiptId, bytes32 taskId);

    /**
     * @dev Gets the task ID of the existing rebalance task for the specified LP.
     * @param lp The address of the liquidity provider.
     * @return The task ID of the rebalance task.
     */
    function getRebalanceTaskId(IChromaticLP lp) external view returns (bytes32);

    /**
     * @dev Gets the task ID of the existing settle task for the specified LP and receipt ID.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the receipt associated with the task.
     * @return The task ID of the settle task.
     */
    function getSettleTaskId(IChromaticLP lp, uint256 receiptId) external view returns (bytes32);

    /**
     * @dev Cancels the existing task for a specific upkeep ID.
     * @param upkeepId The unique identifier of the task.
     */
    function cancelUpkeep(bytes32 upkeepId) external;
}
