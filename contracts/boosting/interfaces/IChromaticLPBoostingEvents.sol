// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// TODO: use unique name
interface IChromaticLPBoostingEvents {
    event Deposited(address indexed provider, uint256 amount);
    event Refunded(address indexed provider, uint256 amount);
    event ClaimedLPToken(address indexed provider, uint256 amount);
    event RaisingTargetFilled(uint256 amount);
    // event BoostingCanceled();
    event BoostingExecuted();
}
