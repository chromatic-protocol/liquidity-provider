// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// TODO: use unique name
interface IChromaticLPBoostingEvents {
    event LPBoostingDeposited(address indexed provider, uint256 amount);
    event LPBoostingRefunded(address indexed provider, uint256 amount);
    event LPBoostingClaimed(address indexed provider, uint256 boostingToken, uint256 lpTokenAmount);
    event LPBoostingExecuted();
    event LPBoostingSettleUpdated(uint256 totalLPToken);
}
