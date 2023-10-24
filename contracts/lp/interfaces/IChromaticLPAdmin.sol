// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPAdmin {
    function createRebalanceTask() external;

    function cancelRebalanceTask() external;

    function resolveSettle(
        uint256 receiptId
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    function resolveRebalance() external view returns (bool upkeepNeeded, bytes memory performData);

    function setAutomationFeeReserved(uint256 automationFeeReserved) external;
}
