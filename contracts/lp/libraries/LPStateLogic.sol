// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
import {MIN_ADD_LIQUIDITY_BIN} from "~/lp/libraries/Constants.sol";

/**
 * @title AddLiquidityParam
 * @dev Struct representing parameters for adding liquidity to a liquidity provider in the Chromatic Protocol.
 */
struct AddLiquidityParam {
    uint256 amount; // Amount in settlement token to add liquidity in the LP
    uint256 amountMarket; // Amount of adding to market
    address provider; // Address of the liquidity provider
    address recipient; // Address of the recipient
}

/**
 * @title RemoveLiquidityParam
 * @dev Struct representing parameters for removing liquidity from a liquidity provider in the Chromatic Protocol.
 */
struct RemoveLiquidityParam {
    uint256 amount; // LP token requesting to burn
    address provider; // Address of the liquidity provider
    address recipient; // Address of the recipient
}

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
        uint256[] storage lpReceiptIds = s_state.lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            //slither-disable-next-line unused-return
            lpReceiptIds.push(lpReceipts[i].id);

            unchecked {
                ++i;
            }
        }

        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[msg.sender];
        //slither-disable-next-line unused-return
        receiptIdSet.add(receipt.id);
    }

    /**
     * @dev Update a receipt settled from the LPState, cleaning up associated mappings and sets.
     * @param s_state The storage state of the liquidity provider.
     * @param receiptId The ID of the Chromatic LP Receipt to be removed.
     */
    function removeReceipt(LPState storage s_state, uint256 receiptId) internal {
        ChromaticLPReceipt storage receipt = s_state.receipts[receiptId];
        receipt.needSettle = false;

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
        // valueOfSupply() : aleady keeperFee excluded
        s_state.decreasePendingAdd(keeperFee, 0);

        s_state.market.claimLiquidityBatch(
            s_state.lpReceiptMap[receipt.id],
            abi.encode(receipt, s_state.valueOfSupply(), keeperFee)
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
        uint256[] memory receiptIds = s_state.lpReceiptMap[receipt.id];
        LpReceipt[] memory lpReceits = s_state.market.getLpReceipts(receiptIds);

        s_state.market.withdrawLiquidityBatch(
            s_state.lpReceiptMap[receipt.id],
            abi.encode(receipt, lpReceits, s_state.valueOfSupply(), keeperFee) // FIXME
        );

        s_state.removeReceipt(receipt.id);
    }

    /**
     * @dev Distributes a given amount among different fee bins based on their distribution rates.
     * @param s_state The storage state of the liquidity provider.
     * @param amount The total amount to be distributed.
     * @return feeRates An array containing the feeRate of bins.
     * @return amounts An array containing the distributed amounts for each fee bin.
     * @return totalAmount The total amount after distribution.
     */
    function distributeAmount(
        LPState storage s_state,
        uint256 amount
    )
        internal
        view
        returns (int16[] memory feeRates, uint256[] memory amounts, uint256 totalAmount)
    {
        uint256 binCount = s_state.binCount();

        feeRates = new int16[](binCount);
        amounts = new uint256[](binCount);
        uint256 index;
        for (uint256 i = 0; i < binCount; ) {
            amounts[index] = amount.mulDiv(
                s_state.distributionRates[s_state.feeRates[i]],
                s_state.totalRate
            );
            if (amounts[index] > MIN_ADD_LIQUIDITY_BIN) {
                totalAmount += amounts[index];
                feeRates[index] = s_state.feeRates[i];
                unchecked {
                    ++index;
                }
            } else {
                assembly {
                    mstore(amounts, sub(mload(amounts), 1))
                    mstore(feeRates, sub(mload(feeRates), 1))
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Adds liquidity to the liquidity pool and updates the LPState accordingly.
     * @param s_state The storage state of the liquidity provider.
     * @param feeRates An array of fee rates for different actions within the liquidity pool.
     * @param amounts An array of amounts representing the liquidity to be added.
     * @param addParam Parameters for adding liquidity.
     * @return receipt The Chromatic LP Receipt representing the addition of liquidity.
     */
    function addLiquidity(
        LPState storage s_state,
        int16[] memory feeRates,
        uint256[] memory amounts,
        AddLiquidityParam memory addParam
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = s_state.market.addLiquidityBatch(
            address(this),
            feeRates,
            amounts,
            abi.encode(
                ChromaticLPLogicBase.AddLiquidityBatchCallbackData({
                    provider: addParam.provider,
                    liquidityAmount: addParam.amountMarket,
                    holdingAmount: addParam.amount - addParam.amountMarket
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: addParam.provider,
            recipient: addParam.recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: addParam.amount,
            pendingLiquidity: addParam.amountMarket,
            action: ChromaticLPAction.ADD_LIQUIDITY,
            needSettle: true
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.increasePendingAdd(addParam.amount, addParam.amountMarket);
    }

    /**
     * @dev Removes liquidity from the liquidity pool and updates the LPState accordingly.
     * @param s_state The storage state of the liquidity provider.
     * @param clbTokenAmounts The amounts of CLB tokens to be removed for each fee bin.
     * @param removeParam Parameters for removing liquidity.
     * @return receipt The Chromatic LP Receipt representing the removal of liquidity.
     */
    function removeLiquidity(
        LPState storage s_state,
        int16[] memory feeRates,
        uint256[] memory clbTokenAmounts,
        RemoveLiquidityParam memory removeParam
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = s_state.market.removeLiquidityBatch(
            address(this),
            feeRates,
            clbTokenAmounts,
            abi.encode(
                ChromaticLPLogicBase.RemoveLiquidityBatchCallbackData({
                    provider: removeParam.provider,
                    recipient: removeParam.recipient,
                    lpTokenAmount: removeParam.amount,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: removeParam.provider,
            recipient: removeParam.recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: removeParam.amount,
            pendingLiquidity: 0,
            action: ChromaticLPAction.REMOVE_LIQUIDITY,
            needSettle: true
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.increasePendingClb(lpReceipts);
    }

    /**
     * @dev Increases the pending add amounts
     * @param s_state The storage state of the liquidity provider.
     * @param amountToLp pending amount to the lp when addLiquidity called.
     * @param amountToMarket pending addLiquidity amount to market not claimed.
     */
    function increasePendingAdd(
        LPState storage s_state,
        uint256 amountToLp,
        uint256 amountToMarket
    ) internal {
        s_state.pendingAddLp += amountToLp;
        s_state.pendingAddMarket += amountToMarket;
    }

    /**
     * @dev Decreases the pending add amounts.
     * @param amountToLp pending amount to the lp when addLiquidity called.
     * @param amountToMarket pending addLiquidity amount to the market claimed.
     */
    function decreasePendingAdd(
        LPState storage s_state,
        uint256 amountToLp,
        uint256 amountToMarket
    ) internal {
        s_state.pendingAddLp -= amountToLp;
        s_state.pendingAddMarket -= amountToMarket;
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
     * @return feeRates An array containing the feeRate of bins.
     * @return removeAmounts An array containing the amounts of pending CLB tokens to be removed for each fee bin.
     */
    function calcRemoveClbAmounts(
        LPState storage s_state,
        uint256 lpTokenAmount,
        uint256 totalSupply
    ) internal view returns (int16[] memory feeRates, uint256[] memory removeAmounts) {
        uint256 binCount = s_state.binCount();
        feeRates = new int16[](binCount);
        removeAmounts = new uint256[](binCount);

        uint256[] memory clbBalances = s_state.clbTokenBalances();
        uint256[] memory pendingClb = s_state.pendingRemoveClbBalances();

        uint256 index;
        for (uint256 i; i < binCount; ) {
            removeAmounts[index] = (clbBalances[i] + pendingClb[i]).mulDiv(
                lpTokenAmount,
                totalSupply,
                Math.Rounding.Up
            );
            if (removeAmounts[index] > clbBalances[i]) {
                removeAmounts[index] = clbBalances[i];
            }
            if (removeAmounts[index] != 0) {
                feeRates[index] = s_state.feeRates[i];
                unchecked {
                    ++index;
                }
            } else {
                // decrease length
                assembly {
                    mstore(removeAmounts, sub(mload(removeAmounts), 1))
                    mstore(feeRates, sub(mload(feeRates), 1))
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function calcRebalanceRemoveAmounts(
        LPState storage s_state,
        uint256 currentUtility,
        uint256 utilizationTargetBPS
    ) internal view returns (int16[] memory feeRates, uint256[] memory removeAmounts) {
        uint256 binCount = s_state.binCount();
        removeAmounts = new uint256[](binCount);
        feeRates = new int16[](binCount);

        uint256[] memory _clbTokenBalances = s_state.clbTokenBalances();
        uint256 index;
        for (uint256 i; i < binCount; ) {
            removeAmounts[index] = _clbTokenBalances[i].mulDiv(
                currentUtility - utilizationTargetBPS,
                currentUtility
            );
            if (removeAmounts[index] == 0) {
                assembly {
                    mstore(removeAmounts, sub(mload(removeAmounts), 1))
                    mstore(feeRates, sub(mload(feeRates), 1))
                }
            } else {
                feeRates[index] = s_state.feeRates[i];
                unchecked {
                    ++index;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
