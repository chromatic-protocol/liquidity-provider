// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IChromaticLPCallback
 * @dev Interface for handling callbacks related to Chromatic LP actions.
 */
interface IChromaticLPCallback {
    /**
     * @dev Callback function triggered after claiming liquidity.
     * @param receiptId The unique identifier of the receipt associated with the action.
     * @param addedLiquidity The amount of liquidity added in settlement token.
     * @param lpTokenMint The amount of LP tokens minted.
     * @param keeperFee The amount of keeper fee paid.
     */
    function claimedCallback(
        uint256 receiptId,
        uint256 addedLiquidity,
        uint256 lpTokenMint,
        uint256 keeperFee
    ) external;

    /**
     * @dev Callback function triggered after withdrawing liquidity.
     * @param receiptId The unique identifier of the receipt associated with the action.
     * @param burnedAmount The amount of LP tokens burned.
     * @param withdrawnAmount The amount of settlement tokens withdrawn.
     * @param refundedAmount The amount of LP tokens refunded.
     * @param keeperFee The amount of keeper fee paid.
     */
    function withdrawnCallback(
        uint256 receiptId,
        uint256 burnedAmount,
        uint256 withdrawnAmount,
        uint256 refundedAmount,
        uint256 keeperFee
    ) external;
}
