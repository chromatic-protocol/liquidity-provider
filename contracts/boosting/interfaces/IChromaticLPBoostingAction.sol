// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPBoostingAction {
    function deposit(uint256 amount) external;

    function refund() external;

    function claimLiquidity() external;

    function boostLP() external;
}
