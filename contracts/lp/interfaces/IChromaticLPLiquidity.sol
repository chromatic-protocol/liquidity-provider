// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

interface IChromaticLPLiquidity {
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    function settle(uint256 receiptId) external returns (bool);

    function getReceiptIdsOf(address owner) external view returns (uint256[] memory);

    function getReceipt(uint256 id) external view returns (ChromaticLPReceipt memory);
}
