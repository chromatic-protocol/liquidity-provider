// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IChromaticBP} from "~/bp/interfaces/IChromaticBP.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";

/**
 * @title IAutomateGelatoBP
 * @dev Interface for automating tasks related to Chromatic Boosting Pools (BPs) within a protocol.
 */
interface IAutomateGelatoBP is IAutomateBP {
    /**
     * @dev Emitted when a boost task cancellation is successful.
     * @param bp The address of the boosting pool.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancelBoostTaskSucceeded(address bp, bytes32 taskId);

    /**
     * @dev Emitted when a boost task cancellation is successful.
     * @param bp The address of the boosting pool.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancelBoostTaskFailed(address bp, bytes32 taskId);

    /**
     * @dev Gets the task ID of the existing boost task for the specified BP.
     * @param bp The address of the Chromatic BP.
     * @return The task ID of the boost task.
     */
    function getBoostTaskId(IChromaticBP bp) external view returns (bytes32);
}
