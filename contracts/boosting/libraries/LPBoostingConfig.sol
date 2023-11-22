// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

struct LPBoostingConfig {
    IChromaticLP lp;
    uint256 minRaisingTarget;   
    uint256 maxRaisingTarget;
    uint256 startTimeOfWarmup;
    uint256 periodOfWarmup;
    uint256 periodOfLockup;
}
