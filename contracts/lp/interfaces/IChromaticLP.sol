// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLPLiquidity} from "./IChromaticLPLiquidity.sol";
import {IChromaticLPAdmin} from "./IChromaticLPAdmin.sol";
import {IChromaticLPLens} from "./IChromaticLPLens.sol";
import {IChromaticLPMeta} from "./IChromaticLPMeta.sol";
import {IChromaticLPEvents} from "./IChromaticLPEvents.sol";

import {IChromaticLPErrors} from "./IChromaticLPErrors.sol";

interface IChromaticLP is
    IChromaticLPLiquidity,
    IChromaticLPLens,
    IChromaticLPMeta,
    IChromaticLPAdmin,
    IChromaticLPEvents,
    IChromaticLPErrors
{
    function market() external view returns (address);

    function settlementToken() external view returns (address);

    function lpToken() external view returns (address);
}
