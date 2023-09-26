// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";

abstract contract ChromaticLPStorageMate2 is ChromaticLPStorage {
    IMate2AutomationRegistry public immutable automate;

    struct Tasks {
        uint256 rebalanceTaskId;
        mapping(uint256 => uint256) settleTasks;
    }

    Tasks internal s_task;

    constructor(IMate2AutomationRegistry _automate) ChromaticLPStorage() {
        automate = _automate;
    }

    function _getFeeInfo() internal view override returns (uint256 fee, address feePayee) {
        fee = automate.getPerformUpkeepFee();
        feePayee = address(automate);
    }

}
