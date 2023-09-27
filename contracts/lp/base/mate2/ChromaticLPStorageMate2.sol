// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";

import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";

abstract contract ChromaticLPStorageMate2 is ChromaticLPStorage, IMate2Automation {
    IMate2AutomationRegistry public immutable automate;

    enum UpkeepType {
        Settle,
        Rebalance
    }
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

    function _registerUpkeep(
        UpkeepType upkeepType,
        uint256 receiptIdOrZero,
        bool singleExec
    ) internal returns (uint256 upkeepId) {
        upkeepId = automate.registerUpkeep(
            address(this), // target
            1e6, //uint32 gasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            singleExec, // bool singleExec,
            abi.encode(upkeepType, receiptIdOrZero)
        );
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        // FIXME
        (UpkeepType upkeepType, uint256 receiptId) = abi.decode(checkData, (UpkeepType, uint256));
        if (upkeepType == UpkeepType.Settle) {
            return resolveSettle(receiptId);
        } else if (upkeepType == UpkeepType.Rebalance) {
            return resolveRebalance();
        }
    }

    function performUpkeep(bytes calldata performData) external {
        (UpkeepType upkeepType, uint256 receiptId) = abi.decode(performData, (UpkeepType, uint256));
        if (upkeepType == UpkeepType.Settle) {
            settle(receiptId);
        } else if (upkeepType == UpkeepType.Rebalance) {
            rebalance();
        }
    }

    function resolveSettle(
        uint256 receiptId
    ) public view virtual returns (bool upkeepNeeded, bytes memory performData);

    function resolveRebalance()
        public
        view
        virtual
        returns (bool upkeepNeeded, bytes memory performData);

    function rebalance() internal virtual;

    function settle(uint256 receiptId) public virtual returns (bool);
}
