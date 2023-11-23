// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
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
 * @title BPInfo
 * @dev A struct representing the information about a Chromatic Boosting Pool.
 * @param totalRaised The total amount raised in the Boosting Pool.
 * @param totalLPToken The total amount of LP tokens associated with the Boosting Pool.
 * @param boostingTaskId The task ID associated with the boosting task.
 * @param boostingReceiptId The receipt ID associated with the boosting execution.
 * @param boostingExecStatus The execution status of the boosting task.
 */
struct BPInfo {
    uint256 totalRaised;
    uint256 totalLPToken;
    bytes32 boostingTaskId;
    uint256 boostingReceiptId;
    BPExec boostingExecStatus;
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

library BPStateLib {
    function totalRaised(BPState storage self) internal view returns (uint256) {
        return self.info.totalRaised;
    }

    function addRaised(BPState storage self, uint256 amount) internal {
        self.info.totalRaised += amount;
    }

    function market(BPState storage self) internal view returns (IChromaticMarket) {
        return IChromaticMarket(targetLP(self).market());
    }

    function minRaisingTarget(BPState storage self) internal view returns (uint256) {
        return self.config.minRaisingTarget;
    }

    function maxRaisingTarget(BPState storage self) internal view returns (uint256) {
        return self.config.maxRaisingTarget;
    }

    function startTimeOfWarmup(BPState storage self) internal view returns (uint256) {
        return self.config.startTimeOfWarmup;
    }

    function endTimeOfWarmup(BPState storage self) internal view returns (uint256 timestamp) {
        return self.config.startTimeOfWarmup + self.config.durationOfWarmup;
    }

    function endTimeOfLockup(BPState storage self) internal view returns (uint256 timestamp) {
        return
            self.config.startTimeOfWarmup +
            self.config.durationOfWarmup +
            self.config.durationOfLockup;
    }

    function targetLP(BPState storage self) internal view returns (IChromaticLP) {
        return self.config.lp;
    }

    function settlementToken(BPState storage self) internal view returns (IERC20Metadata) {
        return IERC20Metadata(self.config.lp.settlementToken());
    }

    function isRaisedOverMinTarget(BPState storage self) internal view returns (bool) {
        // check amount only but timestamp
        return totalRaised(self) >= minRaisingTarget(self);
    }

    function needToCreateBoostTask(BPState storage self) internal view returns (bool) {
        return (boostTaskId(self) == 0 && isRaisedOverMinTarget(self));
    }

    function isBoostExecutable(BPState storage self) internal view returns (bool) {
        return (block.timestamp > endTimeOfWarmup(self) &&
            isRaisedOverMinTarget(self) &&
            boostingExecStatus(self) == BPExec.NOT_EXECUTED);
    }

    function boostingExecStatus(BPState storage self) internal view returns (BPExec status) {
        return self.info.boostingExecStatus;
    }

    function setBoostingExecStatus(BPState storage self, BPExec execStatus) internal {
        self.info.boostingExecStatus = execStatus;
    }

    function boostingReceiptId(BPState storage self) internal view returns (uint256 receiptId) {
        return self.info.boostingReceiptId;
    }

    function setBoostingReceiptId(BPState storage self, uint256 receiptId) internal {
        self.info.boostingReceiptId = receiptId;
    }

    function setTotalLPToken(BPState storage self, uint256 amount) internal {
        self.info.totalLPToken = amount;
    }

    function updateBoostingSettleState(BPState storage self) internal returns (bool updated) {
        if (boostingExecStatus(self) == BPExec.EXECUTED) {
            IChromaticLP lp = targetLP(self);
            uint256 receiptId = boostingReceiptId(self);
            ChromaticLPReceipt memory receipt = lp.getReceipt(receiptId);
            if (receipt.id == 0) {
                // when it is settled
                setTotalLPToken(self, IERC20(lp.lpToken()).balanceOf(address(this)));
                setBoostingExecStatus(self, BPExec.SETTLED);
                return true;
            }
        }
        return false;
    }

    function totalLPToken(BPState storage self) internal view returns (uint256 amount) {
        return self.info.totalLPToken;
    }

    function isClaimable(BPState storage self) internal view returns (bool) {
        return
            block.timestamp > endTimeOfLockup(self) && boostingExecStatus(self) == BPExec.SETTLED;
    }

    function setBoostTask(BPState storage self, bytes32 taskId) internal {
        self.info.boostingTaskId = taskId;
    }

    function boostTaskId(BPState storage self) internal view returns (bytes32) {
        return self.info.boostingTaskId;
    }

    function currentPeriod(BPState storage self) internal view returns (BPPeriod period) {
        uint256 ts = block.timestamp;
        if (ts < startTimeOfWarmup(self)) {
            return BPPeriod.PREWARMUP;
        } else if (ts <= endTimeOfWarmup(self)) {
            return BPPeriod.WARMUP;
        } else if (ts <= endTimeOfLockup(self)) {
            return BPPeriod.LOCKUP;
        } else {
            return BPPeriod.POSTLOCKUP;
        }
    }

    function isRefundable(BPState storage self) internal view returns (bool) {
        return (block.timestamp > endTimeOfWarmup(self) && !isRaisedOverMinTarget(self));
    }

    function maxDepositable(BPState storage self) internal view returns (uint256) {
        if (totalRaised(self) < maxRaisingTarget(self)) {
            return maxRaisingTarget(self) - totalRaised(self);
        } else {
            return 0;
        }
    }
}
