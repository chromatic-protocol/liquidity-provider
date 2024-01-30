// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {Module, ModuleData, TriggerType} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IChromaticBP} from "~/bp/interfaces/IChromaticBP.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";
import {IAutomateGelatoBP} from "~/automation/gelato/interfaces/IAutomateGelatoBP.sol";

contract AutomateBP is ReentrancyGuard, AutomateReady, IAutomateGelatoBP {
    mapping(IChromaticBP => bytes32) internal _boostTasks;
    IChromaticMarketFactory public immutable marketFactory;

    constructor(
        address gelatoAutomate,
        IChromaticMarketFactory _marketFactory
    ) ReentrancyGuard() AutomateReady(gelatoAutomate, address(this)) {
        marketFactory = _marketFactory;
    }

    modifier onlyAutomation() virtual {
        if (msg.sender != dedicatedMsgSender) revert NotAutomationCalled();
        _;
    }

    modifier onlyDao() {
        if (msg.sender != marketFactory.dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @inheritdoc IAutomateGelatoBP
     */
    function getBoostTaskId(IChromaticBP bp) public view returns (bytes32) {
        return _boostTasks[bp];
    }

    function _setBoostTaskId(IChromaticBP bp, bytes32 taskId) internal {
        _boostTasks[bp] = taskId;
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function createBoostTask() external nonReentrant {
        IChromaticBP bp = IChromaticBP(msg.sender);
        bytes32 taskId = getBoostTaskId(bp);
        if (taskId != 0) revert AlreadyBoostTaskExist();
        //slither-disable-next-line reentrancy-no-eth
        taskId = _createSingleExecTask(
            abi.encodeCall(this.resolveBoost, (msg.sender)),
            abi.encodeCall(this.boost, (msg.sender))
        );
        _setBoostTaskId(bp, taskId);
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function cancelBoostTask(IChromaticBP bp) external onlyDao {
        bytes32 taskId = getBoostTaskId(bp);

        if (taskId != 0) {
            _setBoostTaskId(bp, 0);
            // slither-disable-next-line reentrancy-events
            try automate.cancelTask(taskId) {
                emit CancelBoostTaskSucceeded(address(bp), taskId);
            } catch {
                emit CancelBoostTaskFailed(address(bp), taskId);
            }
        } else {
            revert TaskNotExist();
        }
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function resolveBoost(
        address bp
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        if (IChromaticBP(bp).checkBoost()) {
            return (true, abi.encodeCall(this.boost, (bp)));
        }
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function boost(address bp) external onlyAutomation {
        (uint256 fee, address feePayee) = _getFeeInfo();
        _setBoostTaskId(IChromaticBP(bp), 0);
        IChromaticBP(bp).boostTask(feePayee, fee);
    }

    function _createSingleExecTask(
        bytes memory resolver,
        bytes memory execSelector
    ) internal returns (bytes32) {
        ModuleData memory moduleData = ModuleData({modules: new Module[](4), args: new bytes[](4)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.SINGLE_EXEC;
        moduleData.modules[3] = Module.TRIGGER;
        moduleData.args[0] = abi.encode(address(this), resolver);
        moduleData.args[1] = bytes("");
        moduleData.args[2] = bytes("");
        moduleData.args[3] = abi.encode(TriggerType.BLOCK, bytes(""));

        return automate.createTask(address(this), execSelector, moduleData, ETH);
    }

    function _getFeeInfo() internal view returns (uint256 fee, address feePayee) {
        (fee, ) = _getFeeDetails();
        feePayee = automate.gelato();
    }
}
