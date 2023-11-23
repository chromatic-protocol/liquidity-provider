// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticBPTask {
    function resolveBoostLPTask()
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);

    function boostLPTask() external;
}
