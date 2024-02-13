// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {ChromaticLPLogicBase} from "~/lp/base/ChromaticLPLogicBase.sol";
import {Errors} from "~/lp/libraries/Errors.sol";

/**
 * @title LPStateLogicLib
 * @dev A library providing functions for managing the logic and state transitions of an LP (Liquidity Provider) in the Chromatic Protocol.
 */
library LPStateLogicLib {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using LPStateViewLib for LPState;
    using LPStateLogicLib for LPState;
    using LPStateValueLib for LPState;

    /**
     * @dev Retrieves the next receipt ID and increments the receipt ID counter.
     * @param s_state The storage state of the liquidity provider.
     * @return id The next receipt ID.
     */
    function nextReceiptId(LPState storage s_state) internal returns (uint256 id) {
        id = ++s_state.receiptId;
    }

    /**
     * @dev Adds a receipt to the LPState, updating relevant mappings and sets.
     * @param s_state The storage state of the liquidity provider.
     * @param receipt The Chromatic LP Receipt to be added.
     * @param lpReceipts Array of LpReceipts associated with the Chromatic LP Receipt.
     */
    function addReceipt(
        LPState storage s_state,
        ChromaticLPReceipt memory receipt,
        LpReceipt[] memory lpReceipts
    ) internal {
        s_state.receipts[receipt.id] = receipt;
        EnumerableSet.UintSet storage lpReceiptIdSet = s_state.lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            //slither-disable-next-line unused-return
            lpReceiptIdSet.add(lpReceipts[i].id);

            unchecked {
                ++i;
            }
        }

        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[msg.sender];
        //slither-disable-next-line unused-return
        receiptIdSet.add(receipt.id);
    }

    /**
     * @dev Removes a receipt from the LPState, cleaning up associated mappings and sets.
     * @param s_state The storage state of the liquidity provider.
     * @param receiptId The ID of the Chromatic LP Receipt to be removed.
     */
    function removeReceipt(LPState storage s_state, uint256 receiptId) internal {
        ChromaticLPReceipt memory receipt = s_state.getReceipt(receiptId);
        delete s_state.receipts[receiptId];
        delete s_state.lpReceiptMap[receiptId];

        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[receipt.provider];
        //slither-disable-next-line unused-return
        receiptIdSet.remove(receiptId);
    }

    /**
     * @dev Claims liquidity for a given Chromatic LP Receipt, initiating the transfer of LP tokens to the recipient.
     * @param s_state The storage state of the liquidity provider.
     * @param receipt The Chromatic LP Receipt for which liquidity is to be claimed.
     * @param keeperFee The keeper fee associated with the claim.
     */
    function claimLiquidity(
        LPState storage s_state,
        ChromaticLPReceipt memory receipt,
        uint256 keeperFee
    ) internal {
        // pass ChromaticLPReceipt as calldata
        // mint and transfer lp pool token to provider in callback
        s_state.market.claimLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt, keeperFee)
        );

        s_state.removeReceipt(receipt.id);
    }

    /**
     * @dev Initiates the withdrawal of liquidity for a given Chromatic LP Receipt.
     * @param s_state The storage state of the liquidity provider.
     * @param receipt The Chromatic LP Receipt for which liquidity withdrawal is to be initiated.
     * @param keeperFee The keeper fee associated with the withdrawal.
     */
    function withdrawLiquidity(
        LPState storage s_state,
        ChromaticLPReceipt memory receipt,
        uint256 keeperFee
    ) internal {
        // do claim
        // pass ChromaticLPReceipt as calldata
        uint256[] memory receiptIds = s_state.lpReceiptMap[receipt.id].values();
        LpReceipt[] memory lpReceits = s_state.market.getLpReceipts(receiptIds);

        s_state.market.withdrawLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt, keeperFee, lpReceits)
        );

        s_state.removeReceipt(receipt.id);
    }

    /**
     * @dev Distributes a given amount among different fee bins based on their distribution rates.
     * @param s_state The storage state of the liquidity provider.
     * @param amount The total amount to be distributed.
     * @return amounts An array containing the distributed amounts for each fee bin.
     * @return totalAmount The total amount after distribution.
     */
    function distributeAmount(
        LPState storage s_state,
        uint256 amount
    ) internal view returns (uint256[] memory amounts, uint256 totalAmount) {
        amounts = new uint256[](s_state.binCount());
        for (uint256 i = 0; i < s_state.binCount(); ) {
            uint256 _amount = amount.mulDiv(
                s_state.distributionRates[s_state.feeRates[i]],
                s_state.totalRate
            );

            amounts[i] = _amount;
            totalAmount += _amount;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Adds liquidity to the liquidity pool and updates the LPState accordingly.
     * @param s_state The storage state of the liquidity provider.
     * @param amount The total amount of liquidity to be added.
     * @param liquidityTarget The target liquidity amount.
     * @param provider The address of the liquidity provider.
     * @param recipient The address to receive LP tokens.
     * @return receipt The Chromatic LP Receipt representing the addition of liquidity.
     */
    function addLiquidity(
        LPState storage s_state,
        uint256 amount,
        uint256 liquidityTarget,
        address provider,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        (uint256[] memory amounts, uint256 liquidityAmount) = s_state.distributeAmount(
            liquidityTarget
        );

        LpReceipt[] memory lpReceipts = s_state.market.addLiquidityBatch(
            address(this),
            s_state.feeRates,
            amounts,
            abi.encode(
                ChromaticLPLogicBase.AddLiquidityBatchCallbackData({
                    provider: provider,
                    liquidityAmount: liquidityAmount,
                    holdingAmount: amount - liquidityAmount
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: provider,
            recipient: recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: amount,
            pendingLiquidity: liquidityAmount,
            action: ChromaticLPAction.ADD_LIQUIDITY
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.pendingAddAmount += liquidityAmount;
    }

    /**
     * @dev Removes liquidity from the liquidity pool and updates the LPState accordingly.
     * @param s_state The storage state of the liquidity provider.
     * @param clbTokenAmounts The amounts of CLB tokens to be removed for each fee bin.
     * @param lpTokenAmount The total amount of LP tokens to be removed.
     * @param provider The address of calling removeLiquidity.
     * @param recipient The address to receive the removed liquidity.
     * @return receipt The Chromatic LP Receipt representing the removal of liquidity.
     */
    function removeLiquidity(
        LPState storage s_state,
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address provider,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = s_state.market.removeLiquidityBatch(
            address(this),
            s_state.feeRates,
            clbTokenAmounts,
            abi.encode(
                ChromaticLPLogicBase.RemoveLiquidityBatchCallbackData({
                    provider: provider,
                    recipient: recipient,
                    lpTokenAmount: lpTokenAmount,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: provider,
            recipient: recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: lpTokenAmount,
            pendingLiquidity: 0,
            action: ChromaticLPAction.REMOVE_LIQUIDITY
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.increasePendingClb(lpReceipts);
    }

    /**
     * @dev Increases the pending CLB amounts based on the given LpReceipts.
     * @param s_state The storage state of the liquidity provider.
     * @param lpReceipts Array of LpReceipts for which pending CLB amounts are to be increased.
     */
    function increasePendingClb(LPState storage s_state, LpReceipt[] memory lpReceipts) internal {
        for (uint256 i; i < lpReceipts.length; ) {
            s_state.pendingRemoveClbAmounts[lpReceipts[i].tradingFeeRate] += lpReceipts[i].amount;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Decreases the pending CLB amounts based on the given LpReceipts.
     * @param s_state The storage state of the liquidity provider.
     * @param lpReceits Array of LpReceipts for which pending CLB amounts are to be decreased.
     */
    function decreasePendingClb(LPState storage s_state, LpReceipt[] memory lpReceits) internal {
        for (uint256 i; i < lpReceits.length; ) {
            LpReceipt memory lpReceit = lpReceits[i];

            s_state.pendingRemoveClbAmounts[lpReceit.tradingFeeRate] -= lpReceit.amount;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Calculates the amounts of pending CLB tokens to be removed
     * based on the given LP token amount and total LP token supply.
     * @param s_state The storage state of the liquidity provider.
     * @param lpTokenAmount The total amount of LP tokens to be removed.
     * @param totalSupply The total supply of LP tokens.
     * @return removeAmounts An array containing the amounts of pending CLB tokens to be removed for each fee bin.
     */
    function calcRemoveClbAmounts(
        LPState storage s_state,
        uint256 lpTokenAmount,
        uint256 totalSupply
    ) internal view returns (uint256[] memory removeAmounts) {
        uint256 binCount = s_state.binCount();
        uint256[] memory clbBalances = s_state.clbTokenBalances();
        uint256[] memory pendingClb = s_state.pendingRemoveClbBalances();
        removeAmounts = new uint256[](binCount);
        for (uint256 i; i < binCount; ) {
            removeAmounts[i] = (clbBalances[i] + pendingClb[i]).mulDiv(
                lpTokenAmount,
                totalSupply,
                Math.Rounding.Up
            );
            if (removeAmounts[i] > clbBalances[i]) {
                removeAmounts[i] = clbBalances[i];
            }
            unchecked {
                ++i;
            }
        }
    }
}
