// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IMate2Automation1_1, ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IMate2AutomationRegistry1_1} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry1_1.sol";

import {IChromaticBP} from "~/bp/interfaces/IChromaticBP.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";
import {IAutomateMate2BP} from "~/automation/mate2/interfaces/IAutomateMate2BP.sol";

contract AutomateBP is ReentrancyGuard, Ownable2Step, IAutomateMate2BP, IMate2Automation1_1 {
    enum UpkeepType {
        Boost
    }
    event UpkeepGasLimitUpdated(uint32 gasLimitOld, uint32 gasLimitNew);

    IMate2AutomationRegistry1_1 public immutable automate;
    mapping(IChromaticBP => uint256) internal _boostTasks;
    uint32 public constant DEFAULT_UPKEEP_GAS_LIMIT = 5e7;
    uint32 public upkeepGasLimit;

    modifier onlyOwnerOrBP(address bp) virtual {
        if (msg.sender != owner() && msg.sender != bp) revert OnlyOwnerOrBP();
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
     * @inheritdoc IAutomateMate2BP
     */
    function getBoostTaskId(IChromaticBP bp) public view returns (uint256) {
        return _boostTasks[bp];
    }

    function _setBoostTaskId(IChromaticBP bp, uint256 taskId) internal {
        _boostTasks[bp] = taskId;
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function createBoostTask() external nonReentrant {
        IChromaticBP bp = IChromaticBP(msg.sender);
        uint256 taskId = getBoostTaskId(bp);
        if (taskId != 0) revert AlreadyBoostTaskExist();
        //slither-disable-next-line reentrancy-no-eth
        taskId = _registerUpkeep(UpkeepType.Boost, address(bp), false);
        _setBoostTaskId(bp, taskId);
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function cancelBoostTask(IChromaticBP bp) external onlyOwnerOrBP(address(bp)) {
        uint256 taskId = getBoostTaskId(bp);

        if (taskId != 0) {
            _setBoostTaskId(bp, 0);
            // slither-disable-next-line reentrancy-events
            try automate.cancelUpkeep(taskId) {
                emit CancelBoostTaskSucceeded(address(bp), taskId);
            } catch {
                emit CancelBoostTaskFailed(address(bp), taskId);
            }
        } else {
            revert TaskNotExist();
        }
    }

    /**
     * @inheritdoc IAutomateMate2BP
     */
    function cancelUpkeep(uint256 upkeepId) external onlyOwner {
        automate.cancelUpkeep(upkeepId);
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function resolveBoost(
        address bp
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        if (IChromaticBP(bp).checkBoost()) {
            return (true, abi.encode(UpkeepType.Boost, bp));
        }
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IAutomateBP
     */
    function boost(address bp) public {
        (uint256 fee, address feePayee) = _getFeeInfo();
        if (getBoostTaskId(IChromaticBP(bp)) != 0) {
            _setBoostTaskId(IChromaticBP(bp), 0);
            IChromaticBP(bp).boostTask(feePayee, fee);
        }
    }

    function _registerUpkeep(
        UpkeepType upkeepType,
        address bp,
        bool singleExec
    ) internal returns (uint256 upkeepId) {
        upkeepId = automate.registerUpkeep(
            address(this), // target
            upkeepGasLimit, //uint32 gasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            singleExec, // bool singleExec,
            abi.encode(upkeepType, bp), // checkData
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
        (UpkeepType upkeepType, address bp) = abi.decode(checkData, (UpkeepType, address));
        require(upkeepType == UpkeepType.Boost);

        return resolveBoost(bp);
    }

    function performUpkeep(bytes calldata performData) external {
        (UpkeepType upkeepType, address bp) = abi.decode(performData, (UpkeepType, address));
        require(upkeepType == UpkeepType.Boost);
        boost(bp);
    }

    function updateUpkeepGasLimit(uint32 gasLimit) external onlyOwner {
        uint32 gasLimitOld = upkeepGasLimit;
        upkeepGasLimit = gasLimit;
        emit UpkeepGasLimitUpdated(gasLimitOld, gasLimit);
    }
}
