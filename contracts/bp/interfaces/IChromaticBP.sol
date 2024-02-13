// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IChromaticBPAction} from "~/bp/interfaces/IChromaticBPAction.sol";
import {IChromaticBPEvents} from "~/bp/interfaces/IChromaticBPEvents.sol";
import {IChromaticBPLens} from "~/bp/interfaces/IChromaticBPLens.sol";
import {IChromaticBPAutomate} from "~/bp/interfaces/IChromaticBPAutomate.sol";
import {IChromaticBPErrors} from "~/bp/interfaces/IChromaticBPErrors.sol";
import {IChromaticBPAdmin} from "~/bp/interfaces/IChromaticBPAdmin.sol";

interface IChromaticBP is
    IERC20Metadata,
    IChromaticBPAction,
    IChromaticBPEvents,
    IChromaticBPLens,
    IChromaticBPAutomate,
    IChromaticBPErrors,
    IChromaticBPAdmin
{}
