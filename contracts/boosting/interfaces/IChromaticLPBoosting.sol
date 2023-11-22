// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IChromaticLPBoostingAction} from "~/boosting/interfaces/IChromaticLPBoostingAction.sol";
import {IChromaticLPBoostingEvents} from "~/boosting/interfaces/IChromaticLPBoostingEvents.sol";
import {IChromaticLPBoostingLens} from "~/boosting/interfaces/IChromaticLPBoostingLens.sol";
import {IChromaticLPBoostingTask} from "~/boosting/interfaces/IChromaticLPBoostingTask.sol";
import {IChromaticLPBoostingErrors} from "~/boosting/interfaces/IChromaticLPBoostingErrors.sol";

interface IChromaticLPBoosting is
    IERC20,
    IChromaticLPBoostingAction,
    IChromaticLPBoostingEvents,
    IChromaticLPBoostingLens,
    IChromaticLPBoostingTask,
    IChromaticLPBoostingErrors
{}
