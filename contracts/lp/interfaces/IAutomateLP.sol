// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

/**
 * @title IAutomateLP
 * @dev Interface for automating tasks related to liquidity providers (LPs) within a protocol.
 */
interface IAutomateLP {
    /**
     * @dev Emitted when a function is called by an unauthorized address.
     */
    error NotAutomationCalled();

    /**
     * @dev Emitted when attempting to create a rebalance task while one already exists.
     */
    error AlreadyRebalanceTaskExist();

    /**
     * @dev Signifies that the function is only accessible by the owner
     */
    error OnlyAccessableByOwner();

    /**
     * @dev Initiates the creation of a rebalance task for the specified LP (msg.sender).
     */
    function createRebalanceTask() external;

    /**
     * @dev Cancels the existing rebalance task for the specified LP (msg.sender).
     */
    function cancelRebalanceTask() external;

    /**
     * @dev Checks whether a rebalance task is needed for the specified LP.
     * @param lp The address of the liquidity provider.
     * @return upkeepNeeded Indicates whether upkeep is needed.
     * @return performData Additional data required for performing the task.
     */
    function resolveRebalance(
        address lp
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Executes the rebalance task for the specified LP.
     * @param lp The address of the liquidity provider.
     */
    function rebalance(address lp) external;

    /**
     * @dev Initiates the creation of a settle task for a specific receipt ID.
     * @param receiptId The unique identifier of the receipt associated with the task.
     */
    function createSettleTask(uint256 receiptId) external;

    /**
     * @dev Cancels the existing settle task for a specific receipt ID.
     * @param receiptId The unique identifier of the receipt associated with the task.
     */
    function cancelSettleTask(uint256 receiptId) external;

    /**
     * @dev Checks whether a settle task is needed for the specified LP and receipt ID.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the receipt associated with the task.
     * @return upkeepNeeded Indicates whether upkeep is needed.
     * @return performData Additional data required for performing the task.
     */
    function resolveSettle(
        address lp,
        uint256 receiptId
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Executes the settle task for the specified LP and receipt ID.
     * @param lp The address of the liquidity provider.
     * @param receiptId The unique identifier of the receipt associated with the task.
     */
    function settle(address lp, uint256 receiptId) external;

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
     * @dev Cancels the existing task for a specific task ID.
     * @param taskId The unique identifier of the task.
     */
    function cancelTask(bytes32 taskId) external;
}
