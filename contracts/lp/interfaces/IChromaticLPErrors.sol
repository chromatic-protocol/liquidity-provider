// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPErrors {
    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);

    error NotMarket();
    error OnlyBatchCall();

    error UnknownLPAction();
    error NotOwner();
    error AlreadySwapRouterConfigured();
    error NotKeeperCalled();
    error AlreadyRebalanceTaskExist();
    error OnlyAccessableByOwner();

    error NotAutomationCalled();

    error NotImplementedInLogicContract();
}
