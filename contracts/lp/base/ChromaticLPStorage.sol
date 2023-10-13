// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLPLens, ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {LPState} from "~/lp/libraries/LPState.sol";

abstract contract ChromaticLPStorage is ERC20, IChromaticLPEvents, IChromaticLPErrors {
    uint16 constant BPS = 10000;

    struct LPMeta {
        string lpName;
        string tag;
    }

    struct Config {
        IChromaticMarket market;
        uint16 utilizationTargetBPS;
        uint16 rebalanceBPS;
        uint256 rebalanceCheckingInterval;
        uint256 settleCheckingInterval;
    }
    struct LPConfig {
        uint16 utilizationTargetBPS;
        uint16 rebalanceBPS;
        uint256 rebalanceCheckingInterval;
        uint256 settleCheckingInterval;
    }

    LPMeta internal s_meta;
    LPConfig internal s_config;
    LPState internal s_state;

    constructor() ERC20("", "") {}

    function _getFeeInfo() internal view virtual returns (uint256 fee, address feePayee);
}
