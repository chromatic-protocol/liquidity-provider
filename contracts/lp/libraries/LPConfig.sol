// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

struct LPConfig {
    uint16 utilizationTargetBPS;
    uint16 rebalanceBPS;
    uint256 rebalanceCheckingInterval;
    uint256 settleCheckingInterval;
}

enum AllocationStatus {
    InRange,
    UnderUtilized,
    OverUtilized
}

library LPConfigLib {
    function allocationStatus(
        LPConfig memory lpconfig,
        uint256 currentUtility
    ) internal pure returns (AllocationStatus) {
        if (uint256(lpconfig.utilizationTargetBPS + lpconfig.rebalanceBPS) < currentUtility) {
            return AllocationStatus.OverUtilized;
        } else if (
            uint256(lpconfig.utilizationTargetBPS - lpconfig.rebalanceBPS) > currentUtility
        ) {
            return AllocationStatus.UnderUtilized;
        } else {
            return AllocationStatus.InRange;
        }
    }
}
