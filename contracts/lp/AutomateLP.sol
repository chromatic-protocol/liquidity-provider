// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

contract AutomateLP is ReentrancyGuard, AutomateReady, IAutomateLP {
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
     * @title LPTasks
     * @dev A struct representing tasks associated with Chromatic LP operations.
     * @param rebalanceTaskId The task ID for rebalance operations.
     * @param settleTasks A mapping from receipt ID to the corresponding settle task ID.
     */
    struct LPTasks {
        bytes32 rebalanceTaskId;
        mapping(uint256 => bytes32) settleTasks;
    }

    mapping(IChromaticLP => LPTasks) internal _taskMap;

    constructor(
        AutomateParam memory automateParam
    )
        ReentrancyGuard()
        AutomateReady(automateParam.automate, address(this), automateParam.opsProxyFactory)
    {}

    modifier onlyAutomation() virtual {
        if (msg.sender != dedicatedMsgSender) revert NotAutomationCalled();
        _;
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function getRebalanceTaskId(IChromaticLP lp) public view returns (bytes32) {
        return _taskMap[lp].rebalanceTaskId;
    }

    function _setRebalanceTaskId(IChromaticLP lp, bytes32 rebalanceTaskId) internal {
        _taskMap[lp].rebalanceTaskId = rebalanceTaskId;
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function getSettleTaskId(IChromaticLP lp, uint256 receiptId) public view returns (bytes32) {
        return _taskMap[lp].settleTasks[receiptId];
    }

    function _setSettleTaskId(IChromaticLP lp, uint256 receiptId, bytes32 taskId) internal {
        _taskMap[lp].settleTasks[receiptId] = taskId;
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function createRebalanceTask() external nonReentrant {
        IChromaticLP lp = IChromaticLP(msg.sender);
        bytes32 rebalanceTaskId = getRebalanceTaskId(lp);
        if (rebalanceTaskId != 0) revert AlreadyRebalanceTaskExist();
        //slither-disable-next-line reentrancy-no-eth
        rebalanceTaskId = _createTask(
            abi.encodeCall(this.resolveRebalance, (msg.sender)),
            abi.encodeCall(this.rebalance, (msg.sender)),
            IChromaticLP(msg.sender).rebalanceCheckingInterval()
        );
        _setRebalanceTaskId(lp, rebalanceTaskId);
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function cancelRebalanceTask() external {
        IChromaticLP lp = IChromaticLP(msg.sender);

        bytes32 rebalanceTaskId = getRebalanceTaskId(lp);

        if (rebalanceTaskId != 0) {
            _setRebalanceTaskId(lp, 0);
            automate.cancelTask(rebalanceTaskId);
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function resolveRebalance(
        address lp
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        if (IChromaticLP(lp).checkRebalance()) {
            return (true, abi.encodeCall(this.rebalance, (lp)));
        }
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function rebalance(address lp) external onlyAutomation {
        (uint256 fee, address feePayee) = _getFeeInfo();

        IChromaticLP(lp).rebalance(feePayee, fee);
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function createSettleTask(uint256 receiptId) external nonReentrant {
        IChromaticLP lp = IChromaticLP(msg.sender);
        if (getSettleTaskId(lp, receiptId) == 0) {
            //slither-disable-next-line reentrancy-no-eth
            bytes32 taskId = _createTask(
                abi.encodeCall(this.resolveSettle, (msg.sender, receiptId)),
                abi.encodeCall(this.settle, (msg.sender, receiptId)),
                lp.settleCheckingInterval()
            );
            _setSettleTaskId(lp, receiptId, taskId);
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function cancelSettleTask(uint256 receiptId) external {
        IChromaticLP lp = IChromaticLP(msg.sender);

        bytes32 taskId = getSettleTaskId(lp, receiptId);
        if (taskId != 0) {
            _setSettleTaskId(lp, receiptId, 0);
            automate.cancelTask(taskId);
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function settle(address lp, uint256 receiptId) external onlyAutomation {
        (uint256 fee, address feePayee) = _getFeeInfo();

        IChromaticLP(lp).settleTask(receiptId, feePayee, fee);
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function resolveSettle(
        address lp,
        uint256 receiptId
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        if (IChromaticLP(lp).checkSettle(receiptId)) {
            return (true, abi.encodeCall(this.settle, (lp, receiptId)));
        }
        return (false, bytes(""));
    }

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

    function _getFeeInfo() internal view returns (uint256 fee, address feePayee) {
        (fee, ) = _getFeeDetails();
        feePayee = automate.gelato();
    }
}
