// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

/**
 * @title The IChromaticLPLiquidity interface provides methods for adding and removing liquidity, settling transactions, and retrieving information about liquidity receipts. Developers can interact with this interface to facilitate liquidity operations in Chromatic Protocol.
 */
interface IChromaticLPLiquidity {
    /**
     * @dev Adds liquidity to the Chromatic Protocol, minting LP tokens for the specified amount and assigning them to the recipient.
     * @param amount The amount of liquidity to add.
     * @param recipient The address of the recipient for the LP tokens.
     * @return ChromaticLPReceipt A data structure representing the receipt of the liquidity addition.
     */
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    /**
     * @dev Removes liquidity from the Chromatic Protocol, burning the specified amount of LP tokens and transferring the corresponding assets to the recipient.
     * @param lpTokenAmount The amount of LP tokens to remove.
     * @param recipient The address of the recipient for the withdrawn assets.
     */
    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    /**
     * @dev Initiates the settlement process for a specific liquidity receipt identified by receiptId.
     * @param receiptId The unique identifier of the liquidity receipt to settle.
     * @return true if the settlement is successful, false otherwise.
     */
    function settle(uint256 receiptId) external returns (bool);

    /**
     * @dev Retrieves the unique identifiers of all liquidity receipts owned by a given address.
     * @param owner The address of the liquidity provider.
     * @return receiptIds An array of unique identifiers for the liquidity receipts owned by the specified address.
     */
    function getReceiptIdsOf(address owner) external view returns (uint256[] memory);

    /**
     * @dev Retrieves detailed information about a specific liquidity receipt identified by id.
     * @param id The unique identifier of the liquidity receipt to retrieve.
     * @return A data structure representing the liquidity receipt.
     */
    function getReceipt(uint256 id) external view returns (ChromaticLPReceipt memory);
}
