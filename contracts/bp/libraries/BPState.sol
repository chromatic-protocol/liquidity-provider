// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";
import {BPConfig} from "~/bp/libraries/BPConfig.sol";

/**
 * @title BPPeriod
 * @dev An enumeration representing the different periods in the lifecycle of a Chromatic Boosting Pool.
 * @param PREWARMUP The period before the warm-up period begins.
 * @param WARMUP The warm-up period.
 * @param LOCKUP The lock-up period.
 * @param POSTLOCKUP The period after the lock-up period.
 */
enum BPPeriod {
    PREWARMUP,
    WARMUP,
    LOCKUP,
    POSTLOCKUP
}

/**
 * @title BPExec
 * @dev An enumeration representing the execution status of a boosting task in a Chromatic Boosting Pool.
 * @param NOT_EXECUTED The boosting task has not been executed.
 * @param EXECUTED The boosting task has been executed.
 * @param SETTLED The boosting task has been settled.
 */
enum BPExec {
    NOT_EXECUTED,
    EXECUTED,
    SETTLED
}

/**
 * @title BPStatus
 * @dev An enumeration representing the status of a Chromatic Boosting Pool.
 *
 * @param UPCOMING The boosting pool is in the upcoming status.
 * @param DEPOSITABLE Deposits can be made to the boosting pool.
 * @param WAIT_BOOST Waiting for boosting task execution.
 * @param WAIT_SETTLE Waiting for settling boosting tasks.
 * @param LOCKUP The lock-up period is active.
 * @param CLAIMABLE The boosting pool is in the claimable status.
 * @param REFUNDABLE Refunds can be initiated.
 */
enum BPStatus {
    UPCOMING,
    DEPOSITABLE,
    WAIT_BOOST,
    WAIT_SETTLE,
    LOCKUP,
    CLAIMABLE,
    REFUNDABLE
}

/**
 * @title BPInfo
 * @dev A struct representing the information about a Chromatic Boosting Pool.
 * @param totalRaised The total amount raised in the Boosting Pool.
 * @param totalLPToken The total amount of LP tokens associated with the Boosting Pool.
 * @param automateBP The AutomateBP with the boosting task.
 * @param boostingReceiptId The receipt ID associated with the boosting execution.
 * @param boostingExecStatus The execution status of the boosting task.
 * @param startTimeOfLockup The start time of the lockup period. (valid value if only boost executed )
 * @param isCanceled Whether this BP is canceled and forced to refundable by DAO
 */
struct BPInfo {
    uint256 totalRaised;
    uint256 totalLPToken;
    IAutomateBP automateBP;
    uint256 boostingReceiptId;
    BPExec boostingExecStatus;
    uint256 startTimeOfLockup;
    bool isCanceled;
}

/**
 * @title BPState
 * @dev A struct representing the state of a Chromatic Boosting Pool.
 * @param config The configuration parameters of the Boosting Pool.
 * @param info The information about the Boosting Pool.
 */
struct BPState {
    BPConfig config;
    BPInfo info;
}

/**
 * @title Chromatic Boosting Pool (BP) State Library
 * @dev Library containing functions for managing the state of Chromatic Boosting Pool.
 */
library BPStateLib {
    /**
     * @dev Initialize the state of the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param config The configuration parameters for the ChromaticBP.
     */
    function init(BPState storage self, BPConfig memory config) internal {
        self.config = config;
        self.info.startTimeOfLockup = config.startTimeOfWarmup + config.maxDurationOfWarmup;
    }

    /**
     * @dev Retrieves the total raised amount in the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The total raised amount.
     */
    function totalRaised(BPState storage self) internal view returns (uint256) {
        return self.info.totalRaised;
    }

    /**
     * @dev Increases the total raised amount in the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param amount The amount to add to the total raised.
     */
    function addRaised(BPState storage self, uint256 amount) internal {
        self.info.totalRaised += amount;
    }

    /**
     * @dev Retrieves the Chromatic Market associated with the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The Chromatic Market instance.
     */
    function market(BPState storage self) internal view returns (IChromaticMarket) {
        return IChromaticMarket(targetLP(self).market());
    }

    /**
     * @dev Retrieves the minimum raising target for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The minimum raising target.
     */
    function minRaisingTarget(BPState storage self) internal view returns (uint256) {
        return self.config.minRaisingTarget;
    }

    /**
     * @dev Retrieves the maximum raising target for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The maximum raising target.
     */
    function maxRaisingTarget(BPState storage self) internal view returns (uint256) {
        return self.config.maxRaisingTarget;
    }

    /**
     * @dev Retrieves the start time of the warm-up period for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The start time of the warm-up period.
     */
    function startTimeOfWarmup(BPState storage self) internal view returns (uint256) {
        return self.config.startTimeOfWarmup;
    }

    /**
     * @dev Retrieves the start time of the warm-up period for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The start time of the lock-up period.
     */
    function startTimeOfLockup(BPState storage self) internal view returns (uint256) {
        return self.info.startTimeOfLockup;
    }

    function setStartTimeOfLockup(BPState storage self, uint256 _startTimeOfLockup) internal {
        self.info.startTimeOfLockup = _startTimeOfLockup;
    }

    /**
     * @dev Retrieves the end time of the warm-up period for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return timestamp The end time of the warm-up period.
     */
    function endTimeOfWarmup(BPState storage self) internal view returns (uint256 timestamp) {
        return startTimeOfLockup(self);
    }

    /**
     * @dev Retrieves the end time of the lock-up period for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return timestamp The end time of the lock-up period.
     */
    function endTimeOfLockup(BPState storage self) internal view returns (uint256 timestamp) {
        return startTimeOfLockup(self) + self.config.durationOfLockup;
    }

    /**
     * @dev Retrieves the target Chromatic LP for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The target Chromatic LP instance.
     */
    function targetLP(BPState storage self) internal view returns (IChromaticLP) {
        return self.config.lp;
    }

    /**
     * @dev Retrieves the settlement token for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The settlement token instance.
     */
    function settlementToken(BPState storage self) internal view returns (IERC20Metadata) {
        return IERC20Metadata(self.config.lp.settlementToken());
    }

    /**
     * @dev Checks if the total raised amount in the Chromatic Boosting Pool is over the minimum raising target.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return True if over the minimum raising target, false otherwise.
     */
    function isRaisedOverMinTarget(BPState storage self) internal view returns (bool) {
        // check amount only but timestamp
        return totalRaised(self) >= minRaisingTarget(self);
    }

    /**
     * @dev Checks if creating a boosting task is needed for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return True if needed, false otherwise.
     */
    function needToCreateBoostTask(BPState storage self) internal view returns (bool) {
        return (address(automateBP(self)) == address(0) && isRaisedOverMinTarget(self));
    }

    /**
     * @dev Checks if boosting is executable for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return True if executable, false otherwise.
     */
    function isBoostExecutable(BPState storage self) internal view returns (bool) {
        if (isBPCanceled(self)) return false;
        if (boostingExecStatus(self) != BPExec.NOT_EXECUTED) return false;
        if (totalRaised(self) >= maxRaisingTarget(self)) return true;
        //slither-disable-next-line timestamp
        return (block.timestamp > endTimeOfWarmup(self) && isRaisedOverMinTarget(self));
    }

    /**
     * @dev Retrieves the boosting execution status for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return execStatus The boosting execution status (NOT_EXECUTED, EXECUTED, SETTLED).
     */
    function boostingExecStatus(BPState storage self) internal view returns (BPExec execStatus) {
        return self.info.boostingExecStatus;
    }

    /**
     * @dev Sets the boosting execution status for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param execStatus The new boosting execution status.
     */
    function setBoostingExecStatus(BPState storage self, BPExec execStatus) internal {
        self.info.boostingExecStatus = execStatus;
    }

    /**
     * @dev Retrieves the boosting receipt ID for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return receiptId The boosting receipt ID.
     */
    //slither-disable-next-line dead-code
    function boostingReceiptId(BPState storage self) internal view returns (uint256 receiptId) {
        return self.info.boostingReceiptId;
    }

    /**
     * @dev Sets the boosting receipt ID for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param receiptId The new boosting receipt ID.
     */
    function setBoostingReceiptId(BPState storage self, uint256 receiptId) internal {
        self.info.boostingReceiptId = receiptId;
    }

    /**
     * @dev Sets the total LP token amount for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param amount The new total LP token amount.
     */
    function setTotalLPToken(BPState storage self, uint256 amount) internal {
        self.info.totalLPToken = amount;
    }

    /**
     * @dev Updates the boosting settlement state for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param lpToken The amount of lp token.
     */
    function updateBoostingSettleState(BPState storage self, uint256 lpToken) internal {
        // when it is settled
        require(boostingExecStatus(self) == BPExec.EXECUTED);
        setTotalLPToken(self, lpToken);
        setBoostingExecStatus(self, BPExec.SETTLED);
    }

    /**
     * @dev Retrieves the total LP token amount for the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return amount The total LP token amount.
     */
    function totalLPToken(BPState storage self) internal view returns (uint256 amount) {
        return self.info.totalLPToken;
    }

    /**
     * @dev Checks if the Chromatic Boosting Pool is claimable.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return True if claimable, false otherwise.
     */
    function isClaimable(BPState storage self) internal view returns (bool) {
        //slither-disable-next-line timestamp
        return
            boostingExecStatus(self) == BPExec.SETTLED && block.timestamp > endTimeOfLockup(self);
    }

    /**
     * @dev Sets AutomateBP.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @param _automateBP The address of AutomateBP to handle boosting task.
     */
    function setAutomateBP(BPState storage self, IAutomateBP _automateBP) internal {
        self.info.automateBP = _automateBP;
    }

    /**
     * @dev Retrieves the AutomateBP.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The address of AutomateBP to handle boosting task.
     */
    function automateBP(BPState storage self) internal view returns (IAutomateBP) {
        return self.info.automateBP;
    }

    /**
     * @dev Retrieves the current period of the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return period The current period (PREWARMUP, WARMUP, LOCKUP, POSTLOCKUP).
     */
    function currentPeriod(BPState storage self) internal view returns (BPPeriod period) {
        uint256 ts = block.timestamp;
        //slither-disable-next-line timestamp
        if (ts < startTimeOfWarmup(self)) {
            return BPPeriod.PREWARMUP;
        } else if (ts < endTimeOfWarmup(self)) {
            return BPPeriod.WARMUP;
        } else if (ts < endTimeOfLockup(self)) {
            return BPPeriod.LOCKUP;
        } else {
            return BPPeriod.POSTLOCKUP;
        }
    }

    /**
     * @dev Checks if the Chromatic Boosting Pool is refundable.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return True if refundable, false otherwise.
     */
    function isRefundable(BPState storage self) internal view returns (bool) {
        //slither-disable-next-line timestamp
        if (isBPCanceled(self)) return true;
        return (block.timestamp >= endTimeOfWarmup(self) && !isRaisedOverMinTarget(self));
    }

    /**
     * @dev Calculates the maximum depositable amount in the Chromatic Boosting Pool.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return The maximum depositable amount.
     */
    function maxDepositable(BPState storage self) internal view returns (uint256) {
        if (totalRaised(self) < maxRaisingTarget(self)) {
            return maxRaisingTarget(self) - totalRaised(self);
        } else {
            return 0;
        }
    }

    /**
     * @dev Checks if it is possible to make a deposit.
     * @param self The storage state of the Chromatic Boosting Pool.
     * @return true if a deposit can be made, false otherwise.
     */
    function isDepositable(BPState storage self) internal view returns (bool) {
        return !isBPCanceled(self) && currentPeriod(self) == BPPeriod.WARMUP; // && maxDepositable(self) > 0;
    }

    function totalReward(BPState storage self) internal view returns (uint256) {
        return self.config.totalReward;
    }

    function status(BPState storage self) internal view returns (BPStatus) {
        if (isBPCanceled(self)) return BPStatus.REFUNDABLE;

        BPPeriod period = currentPeriod(self);
        if (period == BPPeriod.PREWARMUP) {
            return BPStatus.UPCOMING;
        } else if (period == BPPeriod.WARMUP) {
            return BPStatus.DEPOSITABLE;
        } else if (isRefundable(self)) {
            return BPStatus.REFUNDABLE;
        } else if (period == BPPeriod.LOCKUP) {
            BPExec execStatus = boostingExecStatus(self);
            if (execStatus == BPExec.NOT_EXECUTED) {
                return BPStatus.WAIT_BOOST;
            } else if (execStatus == BPExec.EXECUTED) {
                return BPStatus.WAIT_SETTLE;
            } else {
                // BPExec.SETTLED
                return BPStatus.LOCKUP;
            }
        } else {
            // (period == BPPeriod.POSTLOCKUP)
            return BPStatus.CLAIMABLE;
        }
    }

    function cancelBP(BPState storage self) internal {
        self.info.isCanceled = true;
    }

    function isBPCanceled(BPState storage self) internal view returns (bool) {
        return self.info.isCanceled;
    }
}
