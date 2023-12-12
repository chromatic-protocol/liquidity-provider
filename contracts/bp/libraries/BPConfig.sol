// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

/**
 * @title BPConfig
 * @dev A struct representing the configuration parameters of a Chromatic Boosting Pool.
 * @param lp The ChromaticLP address associated with the Boosting Pool.
 * @param minRaisingTarget The minimum raising target amount.
 * @param maxRaisingTarget The maximum raising target amount.
 * @param startTimeOfWarmup The start time of the warmup period.
 * @param maxDurationOfWarmup The max duration of the warmup period.
 * @param durationOfLockup The duration of the lockup period.
 */
struct BPConfig {
    IChromaticLP lp;
    uint256 minRaisingTarget;
    uint256 maxRaisingTarget;
    uint256 startTimeOfWarmup;
    uint256 maxDurationOfWarmup;
    uint256 durationOfLockup;
}
