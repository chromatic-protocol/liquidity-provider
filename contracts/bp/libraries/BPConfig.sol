// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

struct BPConfig {
    IChromaticLP lp;
    uint256 minRaisingTarget;
    uint256 maxRaisingTarget;
    uint256 startTimeOfWarmup;
    uint256 durationOfWarmup;
    uint256 durationOfLockup;
}

/**
 * @title AutomateParam
 * @dev A struct representing the automation parameters for the Chromatic LP contract.
 * @param automate The address of the automation contract.
 * @param opsProxyFactory The address of the operations proxy factory contract.
 */
struct AutomateParam {
    address automate;
    address opsProxyFactory;
}
