// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPBoostingErrors {
    error StartTimeError();
    error InvalidWarmupPeriod();
    error InvalidLockupPeriod();
    error InvalidRaisingTarget();
    error TooSmallMinRaisingTarget();
    error NotWarmupPeriod();
    error FullyRaised();
    error ZeroDepositError();
    error NotRefundablePeriod();
    error RefundError();
    error NotAutomationCalled();
    error ClaimTimeError();
    error BoostingNotExecuted();
    error BoostingNotSettled();
}
