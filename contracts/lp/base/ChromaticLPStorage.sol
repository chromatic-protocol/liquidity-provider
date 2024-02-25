// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SuspendMode} from "~/lp/base/SuspendMode.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {IChromaticLPRegistry} from "~/lp/interfaces/IChromaticLPRegistry.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";

import {BPS} from "~/lp/libraries/Constants.sol";

abstract contract ChromaticLPStorage is ChromaticLPStorageCore, ReentrancyGuard, SuspendMode {
    using Math for uint256;
    using LPStateValueLib for LPState;

    modifier onlyAutomation(uint256 rebalanceOrReceiptId) {
        if (msg.sender != address(s_task[rebalanceOrReceiptId])) revert NotAutomationCalled();
        _;
    }

    mapping(uint256 => IAutomateLP) internal s_task;
    IAutomateLP internal s_automate;

    constructor(IAutomateLP automate) ChromaticLPStorageCore() {
        _setAutomateLP(automate);
    }

    function _setAutomateLP(IAutomateLP automate) internal virtual {
        s_automate = automate;
    }

    function _estimateRebalanceAddAmount(uint256 currentUtility) internal view returns (uint256) {
        return
            (s_state.holdingValue()).mulDiv(
                (BPS - currentUtility) - (BPS - s_config.utilizationTargetBPS),
                BPS - currentUtility
            );
    }

    function _estimateRebalanceRemoveValue(uint256 currentUtility) internal view returns (uint256) {
        return
            s_state.holdingClbValue().mulDiv(
                currentUtility - s_config.utilizationTargetBPS,
                currentUtility
            );
    }
}
