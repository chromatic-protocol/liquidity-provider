// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {BPS} from "~/lp/libraries/Constants.sol";

import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
// import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {ChromaticLPLogicBase} from "~/lp/base/ChromaticLPLogicBase.sol";

library LPStateLogicLib {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using LPStateViewLib for LPState;
    using LPStateLogicLib for LPState;

    function nextReceiptId(LPState storage s_state) internal returns (uint256 id) {
        id = ++s_state.receiptId;
    }

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

        s_state.providerMap[receipt.id] = msg.sender;
        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[msg.sender];
        //slither-disable-next-line unused-return
        receiptIdSet.add(receipt.id);
    }

    function removeReceipt(LPState storage s_state, uint256 receiptId) internal {
        delete s_state.receipts[receiptId];
        delete s_state.lpReceiptMap[receiptId];

        address provider = s_state.providerMap[receiptId];
        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[provider];
        //slither-disable-next-line unused-return
        receiptIdSet.remove(receiptId);
        delete s_state.providerMap[receiptId];
    }

    function claimLiquidity(LPState storage s_state, ChromaticLPReceipt memory receipt) internal {
        // pass ChromaticLPReceipt as calldata
        // mint and transfer lp pool token to provider in callback
        s_state.market.claimLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt)
        );

        s_state.removeReceipt(receipt.id);
    }

    function withdrawLiquidity(
        LPState storage s_state,
        ChromaticLPReceipt memory receipt
    ) internal {
        // do claim
        // pass ChromaticLPReceipt as calldata
        s_state.market.withdrawLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt)
        );

        s_state.removeReceipt(receipt.id);
    }

    function distributeAmount(
        LPState storage s_state,
        uint256 amount
    ) internal view returns (uint256[] memory amounts, uint256 totalAmount) {
        amounts = new uint256[](s_state.binCount());
        for (uint256 i = 0; i < s_state.binCount(); ) {
            uint256 _amount = amount.mulDiv(s_state.distributionRates[s_state.feeRates[i]], BPS);

            amounts[i] = _amount;
            totalAmount += _amount;

            unchecked {
                ++i;
            }
        }
    }

    function addLiquidity(
        LPState storage s_state,
        uint256 amount,
        uint256 liquidityTarget,
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
                    provider: msg.sender,
                    liquidityAmount: liquidityAmount,
                    holdingAmount: amount - liquidityAmount
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: amount,
            pendingLiquidity: liquidityAmount,
            action: ChromaticLPAction.ADD_LIQUIDITY
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.pendingAddAmount += liquidityAmount;
    }

    function removeLiquidity(
        LPState storage s_state,
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = s_state.market.removeLiquidityBatch(
            address(this),
            s_state.feeRates,
            clbTokenAmounts,
            abi.encode(
                ChromaticLPLogicBase.RemoveLiquidityBatchCallbackData({
                    provider: msg.sender,
                    lpTokenAmount: lpTokenAmount,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: s_state.nextReceiptId(),
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: lpTokenAmount,
            pendingLiquidity: 0,
            action: ChromaticLPAction.REMOVE_LIQUIDITY
        });

        s_state.addReceipt(receipt, lpReceipts);
        s_state.increasePendingClb(lpReceipts);
    }

    function increasePendingClb(LPState storage s_state, LpReceipt[] memory lpReceipts) internal {
        for (uint256 i; i < lpReceipts.length; ) {
            s_state.pendingRemoveClbAmounts[lpReceipts[i].tradingFeeRate] += lpReceipts[i].amount;
            unchecked {
                ++i;
            }
        }
    }

    function decreasePendingClb(
        LPState storage s_state,
        int16[] calldata _feeRates,
        uint256[] calldata burnedCLBTokenAmounts
    ) internal {
        for (uint256 i; i < _feeRates.length; ) {
            s_state.pendingRemoveClbAmounts[_feeRates[i]] -= burnedCLBTokenAmounts[i];
            unchecked {
                ++i;
            }
        }
    }

    function calcRemoveClbAmounts(
        LPState storage s_state,
        uint256 lpTokenAmount,
        uint256 totalSupply
    ) internal view returns (uint256[] memory clbTokenAmounts) {
        uint256 binCount = s_state.binCount();
        address[] memory _owners = new address[](binCount);
        for (uint256 i; i < binCount; ) {
            _owners[i] = address(this);
            unchecked {
                ++i;
            }
        }
        uint256[] memory _clbTokenBalances = s_state.clbToken().balanceOfBatch(
            _owners,
            s_state.clbTokenIds
        );

        clbTokenAmounts = new uint256[](binCount);
        for (uint256 i; i < binCount; ) {
            clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                lpTokenAmount,
                totalSupply,
                Math.Rounding.Up
            );

            unchecked {
                ++i;
            }
        }
    }
}
