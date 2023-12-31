// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IChromaticBP} from "~/bp/interfaces/IChromaticBP.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";

/**
 * @title IAutomateMate2BP
 * @dev Interface for automating tasks related to Chromatic Boosting Pools (BPs) within a protocol.
 */
interface IAutomateMate2BP is IAutomateBP {
    /**
     * @dev Emitted when a boost task cancellation is successful.
     * @param bp The address of the boosting pool.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancleBoostTaskSucceeded(address bp, uint256 taskId);

    /**
     * @dev Emitted when a boost task cancellation is successful.
     * @param bp The address of the boosting pool.
     * @param taskId The unique identifier of the cancelled rebalance task.
     */
    event CancleBoostTaskFailed(address bp, uint256 taskId);

    /**
     * @dev Gets the task ID of the existing boost task for the specified BP.
     * @param bp The address of the Chromatic BP.
     * @return The task ID of the boost task.
     */
    function getBoostTaskId(IChromaticBP bp) external view returns (uint256);
}
