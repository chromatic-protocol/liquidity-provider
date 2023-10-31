// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title LPConfig
 * @dev A struct representing the configuration parameters of an LP (Liquidity Provider) in the Chromatic Protocol.
 * @param utilizationTargetBPS Target utilization rate for the LP, represented in basis points (BPS).
 * @param rebalanceBPS Rebalance basis points, indicating the percentage change that triggers a rebalance.
 * @param rebalanceCheckingInterval Time interval (in seconds) between checks for rebalance conditions.
 * @param settleCheckingInterval Time interval (in seconds) between checks for settlement conditions.
 * @param automationFeeReserved Amount reserved as automation fee, used for automated operations within the liquidity pool.
 */
struct LPConfig {
    uint16 utilizationTargetBPS;
    uint16 rebalanceBPS;
    uint256 rebalanceCheckingInterval;
    uint256 settleCheckingInterval;
    uint256 automationFeeReserved;
}

/**
 * @dev The AllocationStatus enum represents different allocation status scenarios within Chromatic Protocol LP
 */
enum AllocationStatus {
    InRange,
    UnderUtilized,
    OverUtilized
}


/**
 * @title LPConfigLib
 * @dev A library providing utility functions for calculating the allocation status of LPs (Liquidity Providers)
 * based on the provided LPConfig parameters and the current utility.
 */
library LPConfigLib {
    /**
     * @dev Calculates the allocation status of an LP.
     * @param lpconfig An instance of the LPConfig struct representing the configuration of the LP.
     * @param currentUtility The current utility of the LP, used for determining the allocation status.
     * @return allocationStatus The allocation status of the LP based on the provided parameters.
     */
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
