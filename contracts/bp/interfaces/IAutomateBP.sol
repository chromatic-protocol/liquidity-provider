// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IChromaticBP} from "~/bp/interfaces/IChromaticBP.sol";

/**
 * @title IAutomateBP
 * @dev Interface for automating tasks related to Chromatic Boosting Pools (BPs) within a protocol.
 */
interface IAutomateBP {
    /**
     * @dev Emitted when a function is called by an unauthorized address.
     */
    error NotAutomationCalled();

    /**
     * @dev Signifies that the function is only accessible by the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Emitted when attempting to create a boost task while one already exists.
     */
    error AlreadyBoostTaskExist();

    /**
     * @dev Emitted when attempting to cancel a boost task not existing.
     */
    error TaskNotExist();

    /**
     * @dev Initiates the creation of a boost task for the specified BP (msg.sender).
     */
    function createBoostTask() external;

    /**
     * @dev Cancels the existing boost task for the specified BP.
     */
    function cancelBoostTask(IChromaticBP bp) external;

    /**
     * @dev Checks whether a boost task is needed for the specified BP.
     * @param bp The address of the Chromatic BP.
     * @return upkeepNeeded Indicates whether upkeep is needed.
     * @return performData Additional data required for performing the task.
     */
    function resolveBoost(
        address bp
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Executes the boost task for the specified BP.
     * @param bp The address of the Chromatic BP.
     */
    function boost(address bp) external;
}
