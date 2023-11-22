// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {LPBoostingConfig} from "~/boosting/libraries/LPBoostingConfig.sol";

enum LPBoostingPeriod {
    PREWARMUP,
    WARMUP,
    LOCKUP,
    POSTLOCKUP
}

enum LPBoostingExec {
    NOT_EXECUTED,
    EXECUTED,
    SETTLED
}

struct LPBoostingInfo {
    uint256 totalRaised;
    // uint256 totalRefunded;
    uint256 totalLPToken;
    bytes32 boostingTaskId;
    uint256 boostingReceiptId;
    LPBoostingExec boostingExecStatus;
}

struct LPBoostingState {
    LPBoostingConfig config;
    LPBoostingInfo info;
}

library LPBoostingStateLib {
    function totalRaised(LPBoostingState storage self) internal view returns (uint256) {
        return self.info.totalRaised;
    }

    function addRaised(LPBoostingState storage self, uint256 amount) internal {
        self.info.totalRaised += amount;
    }

    // function removeRaised(LPBoostingState storage self, uint256 amount) internal {
    //     self.info.totalRaised -= amount;
    // }

    function market(LPBoostingState storage self) internal view returns (IChromaticMarket) {
        return IChromaticMarket(targetLP(self).market());
    }

    function minRaisingTarget(LPBoostingState storage self) internal view returns (uint256) {
        return self.config.minRaisingTarget;
    }

    function maxRaisingTarget(LPBoostingState storage self) internal view returns (uint256) {
        return self.config.maxRaisingTarget;
    }

    function startTimeOfWarmup(LPBoostingState storage self) internal view returns (uint256) {
        return self.config.startTimeOfWarmup;
    }

    function endTimeOfWarmup(
        LPBoostingState storage self
    ) internal view returns (uint256 timestamp) {
        return self.config.startTimeOfWarmup + self.config.periodOfWarmup;
    }

    function endTimeOfLockup(
        LPBoostingState storage self
    ) internal view returns (uint256 timestamp) {
        return
            self.config.startTimeOfWarmup + self.config.periodOfWarmup + self.config.periodOfLockup;
    }

    function targetLP(LPBoostingState storage self) internal view returns (IChromaticLP) {
        return self.config.lp;
    }

    function settlementToken(LPBoostingState storage self) internal view returns (IERC20Metadata) {
        return IERC20Metadata(self.config.lp.settlementToken());
    }

    function isRaisedOverMinTarget(LPBoostingState storage self) internal view returns (bool) {
        // check amount only but timestamp
        return totalRaised(self) >= minRaisingTarget(self);
    }

    function needToCreateBoostTask(LPBoostingState storage self) internal view returns (bool) {
        return (boostTaskId(self) == 0 && isRaisedOverMinTarget(self));
    }

    function isBoostExecutable(LPBoostingState storage self) internal view returns (bool) {
        return (block.timestamp > endTimeOfWarmup(self) &&
            isRaisedOverMinTarget(self) &&
            boostingExecStatus(self) == LPBoostingExec.NOT_EXECUTED);
    }

    function boostingExecStatus(
        LPBoostingState storage self
    ) internal view returns (LPBoostingExec status) {
        return self.info.boostingExecStatus;
    }

    function setBoostingExecStatus(
        LPBoostingState storage self,
        LPBoostingExec execStatus
    ) internal {
        self.info.boostingExecStatus = execStatus;
    }

    function boostingReceiptId(
        LPBoostingState storage self
    ) internal view returns (uint256 receiptId) {
        return self.info.boostingReceiptId;
    }

    function setBoostingReceiptId(LPBoostingState storage self, uint256 receiptId) internal {
        self.info.boostingReceiptId = receiptId;
    }

    function setTotalLPToken(LPBoostingState storage self, uint256 amount) internal {
        self.info.totalLPToken = amount;
    }

    function updateBoostingSettleState(LPBoostingState storage self) internal {
        if (boostingExecStatus(self) == LPBoostingExec.EXECUTED) {
            IChromaticLP lp = targetLP(self);
            uint256 receiptId = boostingReceiptId(self);
            ChromaticLPReceipt memory receipt = lp.getReceipt(receiptId);
            if (receipt.id == 0) {
                // when it is settled
                setTotalLPToken(self, IERC20(lp.lpToken()).balanceOf(address(this)));
                setBoostingExecStatus(self, LPBoostingExec.SETTLED);
            }
        }
    }

    function totalLPToken(LPBoostingState storage self) internal view returns (uint256 amount) {
        return self.info.totalLPToken;
    }

    function isClaimable(LPBoostingState storage self) internal view returns (bool) {
        return
            block.timestamp > endTimeOfLockup(self) &&
            boostingExecStatus(self) == LPBoostingExec.SETTLED;
    }

    function setBoostTask(LPBoostingState storage self, bytes32 taskId) internal {
        self.info.boostingTaskId = taskId;
    }

    function boostTaskId(LPBoostingState storage self) internal view returns (bytes32) {
        return self.info.boostingTaskId;
    }

    function currentPeriod(
        LPBoostingState storage self
    ) internal view returns (LPBoostingPeriod period) {
        uint256 ts = block.timestamp;
        if (ts < startTimeOfWarmup(self)) {
            return LPBoostingPeriod.PREWARMUP;
        } else if (ts <= endTimeOfWarmup(self)) {
            return LPBoostingPeriod.WARMUP;
        } else if (ts <= endTimeOfLockup(self)) {
            return LPBoostingPeriod.LOCKUP;
        } else {
            return LPBoostingPeriod.POSTLOCKUP;
        }
    }

    function isRefundable(LPBoostingState storage self) internal view returns (bool) {
        return (block.timestamp > endTimeOfWarmup(self) && !isRaisedOverMinTarget(self));
    }

    function maxDepositable(LPBoostingState storage self) internal view returns (uint256) {
        if (totalRaised(self) < maxRaisingTarget(self)) {
            return maxRaisingTarget(self) - totalRaised(self);
        } else {
            return 0;
        }
    }
    // function getStatus(
    //     LPBoostingState storage self
    // ) internal view returns (LPBoostingStatus status) {
    //     uint256 ts = block.timestamp;
    //     if (ts < startTimeOfWarmup(self)) {
    //         return LPBoostingStatus.PREWARMUP;
    //     } else if (ts < endTimeOfWarmup(self)) {
    //         return LPBoostingStatus.WARMUP;
    //     } else if (ts < endTimeOfLockup(self)) {
    //         return isRaisedToTarget(self) ? LPBoostingStatus.LOCKED : LPBoostingStatus.CANCELED;
    //     } else {
    //         return LPBoostingStatus.UNLOCKED;
    //     }
    // }
}
