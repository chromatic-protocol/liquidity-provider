// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {ChromaticLPReceipt} from "@/lp/libraries/ChromaticLPReceipt.sol";

interface IChromaticLP is IERC20, IERC1155Receiver {
    function market() external view returns (address);

    function settlementToken() external view returns (address);

    function lpToken() external view returns (address);

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

    function resolveSettle(uint256 receiptId) external view returns (bool, bytes memory);

    function resolveRebalance() external view returns (bool, bytes memory);
}
