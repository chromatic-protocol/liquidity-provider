// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticBPErrors {
    /**
     * @dev Error indicating an issue with the start time.
     */
    error StartTimeError();

    /**
     * @dev Error indicating an invalid warm-up period.
     */
    error InvalidWarmup();

    /**
     * @dev Error indicating an invalid lock-up period.
     */
    error InvalidLockup();

    /**
     * @dev Error indicating an invalid raising target.
     */
    error InvalidRaisingTarget();

    /**
     * @dev Error indicating a too small minimum raising target.
     */
    error TooSmallMinRaisingTarget();

    /**
     * @dev Error indicating that the warm-up period is not active.
     */
    error NotWarmupPeriod();

    /**
     * @dev Error indicating that the raising has been fully completed.
     */
    error FullyRaised();

    /**
     * @dev Error indicating a zero deposit amount.
     */
    error ZeroDepositError();

    /**
     * @dev Error indicating that it's not the refundable period.
     */
    error NotRefundablePeriod();

    /**
     * @dev Error indicating a general refund error.
     */
    error RefundError();

    /**
     * @dev Error indicating a zero refund amount error.
     */
    error RefundZeroAmountError();

    /**
     * @dev Error indicating that the function can only be called by automation.
     */
    error NotAutomationCalled();

    /**
     * @dev Error indicating an issue with the claim time.
     */
    error ClaimTimeError();

    /**
     * @dev Error indicating a zero balance for claiming.
     */
    error ClaimBalanceZeroError();

    /**
     * @dev Error indicating that boosting cannot be executed.
     */
    error NotBoostable();

    /**
     * @dev Error indicating that boosting has not been executed.
     */
    error BoostingNotExecuted();

    /**
     * @dev Error indicating that boosting has not been settled.
     */
    error BoostingNotSettled();
}
