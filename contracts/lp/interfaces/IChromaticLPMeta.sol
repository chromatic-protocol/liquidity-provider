// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPMeta {
    function lpName() external view returns (string memory);

    function lpTag() external view returns (string memory);
}
