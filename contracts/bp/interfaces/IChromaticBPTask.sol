// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticBPTask
 * @dev Interface for resolving and executing tasks related to Chromatic Boosting Pool.
 */
interface IChromaticBPTask {
    /**
     * @dev Resolves the Boost LP task to determine if upkeep is needed and the data to perform the task.
     * @return upkeepNeeded A boolean indicating whether upkeep is needed.
     * @return performData The data needed to perform the task.
     */
    function resolveBoostLPTask()
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @dev Executes the Boost LP task.
     */
    function boostLPTask() external;
}
