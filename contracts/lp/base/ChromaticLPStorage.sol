// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";

abstract contract ChromaticLPStorage is ChromaticLPStorageCore, AutomateReady {
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

    /**
     * @title Tasks
     * @dev A struct representing tasks associated with Chromatic LP operations.
     * @param rebalanceTaskId The task ID for rebalance operations.
     * @param settleTasks A mapping from receipt ID to the corresponding settle task ID.
     */
    struct Tasks {
        bytes32 rebalanceTaskId;
        mapping(uint256 => bytes32) settleTasks;
    }

    modifier onlyAutomation() virtual {
        if (msg.sender != dedicatedMsgSender) revert NotAutomationCalled();
        _;
    }

    Tasks internal s_task;

    constructor(
        AutomateParam memory automateParam
    )
        ChromaticLPStorageCore()
        AutomateReady(automateParam.automate, address(this), automateParam.opsProxyFactory)
    {}

    function _createTask(
        bytes memory resolver,
        bytes memory execSelector,
        uint256 interval
    ) internal returns (bytes32) {
        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});
        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(address(this), resolver); // abi.encodeCall(this.resolveRebalance, ()));
        moduleData.args[1] = abi.encode(uint128(block.timestamp + interval), uint128(interval));
        moduleData.args[2] = bytes("");

        return automate.createTask(address(this), execSelector, moduleData, ETH);
    }

    function _getFeeInfo() internal view override returns (uint256 fee, address feePayee) {
        (fee, ) = _getFeeDetails();
        feePayee = automate.gelato();
    }
}
