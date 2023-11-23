// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// TODO: use unique name
interface IChromaticBPEvents {
    event BPDeposited(address indexed provider, uint256 amount);
    event BPRefunded(address indexed provider, uint256 amount);
    event BPClaimed(address indexed provider, uint256 boostingToken, uint256 lpTokenAmount);
    event BPExecuted();
    event BPSettleUpdated(uint256 totalLPToken);
}
