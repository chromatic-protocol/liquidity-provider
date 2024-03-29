// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IMate2Automation1_1, ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IMate2AutomationRegistry1_1} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry1_1.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {IAutomateMate2LP} from "~/automation/mate2/interfaces/IAutomateMate2LP.sol";

contract AutomateLP is ReentrancyGuard, Ownable2Step, IAutomateMate2LP, IMate2Automation1_1 {
    enum UpkeepType {
        Rebalance,
        Settle
    }

    event UpkeepGasLimitUpdated(uint32 gasLimitOld, uint32 gasLimitNew);

    /**
     * @title LPTasks
     * @dev A struct representing tasks associated with Chromatic LP operations.
     * @param rebalanceTaskId The task ID for rebalance operations.
     * @param settleTasks A mapping from receipt ID to the corresponding settle task ID.
     */
    struct LPTasks {
        uint256 nextRebalanceCheck;
        uint256 rebalanceTaskId;
        mapping(uint256 => uint256) settleTasks;
    }

    IMate2AutomationRegistry1_1 public immutable automate;
    mapping(IChromaticLP => LPTasks) internal _taskMap;

    uint32 public constant DEFAULT_UPKEEP_GAS_LIMIT = 5e7;
    uint32 public upkeepGasLimit;

    modifier onlyAutomation() virtual {
        if (msg.sender != address(automate)) revert NotAutomationCalled();
        _;
    }

    constructor(IMate2AutomationRegistry1_1 _automate) ReentrancyGuard() Ownable2Step() {
        automate = _automate;
        upkeepGasLimit = DEFAULT_UPKEEP_GAS_LIMIT;
    }

    /**
     * @dev Checks if the caller is the owner of the contract.
     */
    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    /**
     * @inheritdoc IAutomateMate2LP
     */
    function getRebalanceTaskId(IChromaticLP lp) public view returns (uint256) {
        return _taskMap[lp].rebalanceTaskId;
    }

    function _setRebalanceTaskId(IChromaticLP lp, uint256 rebalanceTaskId) internal {
        _taskMap[lp].rebalanceTaskId = rebalanceTaskId;
    }

    /**
     * @inheritdoc IAutomateMate2LP
     */
    function getSettleTaskId(IChromaticLP lp, uint256 receiptId) public view returns (uint256) {
        return _taskMap[lp].settleTasks[receiptId];
    }

    function _setSettleTaskId(IChromaticLP lp, uint256 receiptId, uint256 taskId) internal {
        _taskMap[lp].settleTasks[receiptId] = taskId;
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function createRebalanceTask() external nonReentrant {
        IChromaticLP lp = IChromaticLP(msg.sender);
        uint256 rebalanceTaskId = getRebalanceTaskId(lp);
        if (rebalanceTaskId != 0) revert AlreadyRebalanceTaskExist();
        //slither-disable-next-line reentrancy-no-eth
        rebalanceTaskId = _registerUpkeep(
            UpkeepType.Rebalance,
            address(lp),
            0,
            false // is not singleExec
        );
        _updateNextRebalanceCheckingTime(lp);
        _setRebalanceTaskId(lp, rebalanceTaskId);
    }

    function _updateNextRebalanceCheckingTime(IChromaticLP lp) internal {
        uint256 interval = lp.rebalanceCheckingInterval();
        _taskMap[lp].nextRebalanceCheck = block.timestamp + interval;
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function cancelRebalanceTask() external {
        IChromaticLP lp = IChromaticLP(msg.sender);

        uint256 rebalanceTaskId = getRebalanceTaskId(lp);

        if (rebalanceTaskId != 0) {
            _setRebalanceTaskId(lp, 0);
            _taskMap[lp].nextRebalanceCheck = 0;

            // slither-disable-next-line reentrancy-events
            try automate.cancelUpkeep(rebalanceTaskId) {
                emit CancelRebalanceTaskSucceeded(address(lp), rebalanceTaskId);
            } catch {
                emit CancelRebalanceTaskFailed(address(lp), rebalanceTaskId);
            }
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    //slither-disable-next-line timestamp
    function resolveRebalance(
        address lp
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        if (
            _taskMap[IChromaticLP(lp)].nextRebalanceCheck != 0 &&
            _taskMap[IChromaticLP(lp)].nextRebalanceCheck <= block.timestamp &&
            IChromaticLP(lp).checkRebalance()
        ) {
            return (true, abi.encode(UpkeepType.Rebalance, lp, 0));
        }
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function rebalance(address lp) public onlyAutomation {
        (uint256 fee, address feePayee) = _getFeeInfo();

        _updateNextRebalanceCheckingTime(IChromaticLP(lp));
        IChromaticLP(lp).rebalance(feePayee, fee);
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function createSettleTask(uint256 receiptId) external nonReentrant {
        IChromaticLP lp = IChromaticLP(msg.sender); // called by LP

        if (getSettleTaskId(lp, receiptId) == 0) {
            //slither-disable-next-line reentrancy-no-eth
            uint256 taskId = _registerUpkeep(UpkeepType.Settle, address(lp), receiptId, true);
            _setSettleTaskId(lp, receiptId, taskId);
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function cancelSettleTask(uint256 receiptId) external {
        IChromaticLP lp = IChromaticLP(msg.sender);

        uint256 taskId = getSettleTaskId(lp, receiptId);
        if (taskId != 0) {
            _setSettleTaskId(lp, receiptId, 0);
            // slither-disable-next-line reentrancy-events
            try automate.cancelUpkeep(taskId) {
                emit CancelSettleTaskSucceeded(address(lp), receiptId, taskId);
            } catch {
                emit CancelSettleTaskFailed(address(lp), receiptId, taskId);
            }
        }
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function settle(address lp, uint256 receiptId) public onlyAutomation {
        (uint256 fee, address feePayee) = _getFeeInfo();

        IChromaticLP(lp).settleTask(receiptId, feePayee, fee);
    }

    /**
     * @inheritdoc IAutomateLP
     */
    function resolveSettle(
        address lp,
        uint256 receiptId
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        if (IChromaticLP(lp).checkSettle(receiptId)) {
            return (true, abi.encode(UpkeepType.Settle, lp, receiptId));
        }
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IAutomateMate2LP
     */
    function cancelUpkeep(uint256 upkeepId) external onlyOwner {
        automate.cancelUpkeep(upkeepId);
    }

    function _registerUpkeep(
        UpkeepType upkeepType,
        address lp,
        uint256 receiptIdOrZero,
        bool singleExec
    ) internal returns (uint256 upkeepId) {
        upkeepId = automate.registerUpkeep(
            address(this), // target
            upkeepGasLimit, //uint32 gasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            singleExec, // bool singleExec,
            abi.encode(upkeepType, lp, receiptIdOrZero), // checkData
            ExtraModule.None, // extraModule
            bytes("") // extraParam
        );
    }

    function _getFeeInfo() internal view returns (uint256 fee, address feePayee) {
        fee = automate.getPerformUpkeepFee();
        feePayee = address(automate);
    }

    function checkUpkeep(
        bytes calldata checkData,
        bytes calldata /* extraData */
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (UpkeepType upkeepType, address lp, uint256 receiptId) = abi.decode(
            checkData,
            (UpkeepType, address, uint256)
        );
        if (upkeepType == UpkeepType.Settle) {
            return resolveSettle(lp, receiptId);
        } else if (upkeepType == UpkeepType.Rebalance) {
            return resolveRebalance(lp);
        }
    }

    function performUpkeep(bytes calldata performData) external {
        (UpkeepType upkeepType, address lp, uint256 receiptId) = abi.decode(
            performData,
            (UpkeepType, address, uint256)
        );
        if (upkeepType == UpkeepType.Settle) {
            settle(lp, receiptId);
        } else if (upkeepType == UpkeepType.Rebalance) {
            rebalance(lp);
        }
    }

    function updateUpkeepGasLimit(uint32 gasLimit) external onlyOwner {
        uint32 gasLimitOld = upkeepGasLimit;
        upkeepGasLimit = gasLimit;
        emit UpkeepGasLimitUpdated(gasLimitOld, gasLimit);
    }
}
