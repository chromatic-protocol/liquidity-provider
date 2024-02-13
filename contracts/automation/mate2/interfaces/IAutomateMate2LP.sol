// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";

interface IAutomateMate2LP is IAutomateLP {
    /**
     * @dev Emitted when a rebalance task cancellation is successful.
     * @param lp The address of the liquidity provider.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancleRebalanceTaskSucceeded(address lp, uint256 taskId);

    /**
     * @dev Emitted when a rebalance task cancellation fails.
     * @param lp The address of the liquidity provider.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancleRebalanceTaskFailed(address lp, uint256 taskId);

    /**
     * @dev Emitted when a settle task cancellation is successful.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the cancelled settle task.
     * @param taskId The unique identifier of the cancelled settle task.
     */
    event CancleSettleTaskSucceeded(address lp, uint256 receiptId, uint256 taskId);

    /**
     * @dev Emitted when a settle task cancellation fails.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the cancelled settle task.
     * @param taskId The unique identifier of the cancelled settle task.
     */
    event CancleSettleTaskFailed(address lp, uint256 receiptId, uint256 taskId);

    /**
     * @dev Gets the task ID of the existing rebalance task for the specified LP.
     * @param lp The address of the liquidity provider.
     * @return The task ID of the rebalance task.
     */
    function getRebalanceTaskId(IChromaticLP lp) external view returns (uint256);

    /**
     * @dev Gets the task ID of the existing settle task for the specified LP and receipt ID.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the receipt associated with the task.
     * @return The task ID of the settle task.
     */
    function getSettleTaskId(IChromaticLP lp, uint256 receiptId) external view returns (uint256);

    /**
     * @dev Cancels the existing task for a specific task ID.
     * @param taskId The unique identifier of the task.
     */
    function cancelTask(uint256 taskId) external;
}
