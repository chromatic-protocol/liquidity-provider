// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IChromaticLPLogic {
    function version() external view returns (bytes32);

    function setVersion(bytes32 version) external;

    function onUpgrade(bytes calldata data) external;

    error OnlyDelegateCall();
}
