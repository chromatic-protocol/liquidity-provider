// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {LPState} from "~/lp/libraries/LPState.sol";

import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {LPStateLogicLib} from "~/lp/libraries/LPStateLogic.sol";
import {LPConfigLib, LPConfig, AllocationStatus} from "~/lp/libraries/LPConfig.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {IChromaticLPCallback} from "~/lp/interfaces/IChromaticLPCallback.sol";
import {REBALANCE_ID} from "~/lp/libraries/LPState.sol";

import {BPS} from "~/lp/libraries/Constants.sol";
import {Errors} from "~/lp/libraries/Errors.sol";

abstract contract ChromaticLPLogicBase is ChromaticLPStorage, ReentrancyGuard {
    using Math for uint256;

    using LPStateValueLib for LPState;
    using LPStateViewLib for LPState;
    using LPStateLogicLib for LPState;
    using LPConfigLib for LPConfig;

    /**
     * @title AddLiquidityBatchCallbackData
     * @dev A struct representing callback data for the addLiquidityBatch function in the Chromatic LP contract.
     * @param provider The address of the liquidity provider initiating the addLiquidityBatch.
     * @param liquidityAmount The amount of liquidity added to the LP.
     * @param holdingAmount The remaining holding amount after adding liquidity.
     */
    struct AddLiquidityBatchCallbackData {
        address provider;
        uint256 liquidityAmount;
        uint256 holdingAmount;
    }

    /**
     * @title RemoveLiquidityBatchCallbackData
     * @dev A struct representing callback data for the removeLiquidityBatch function in the Chromatic LP contract.
     * @param provider The address of the liquidity provider initiating the removeLiquidityBatch.
     * @param recipient The address where the LP tokens and settlement tokens are sent after removal.
     * @param lpTokenAmount The amount of LP tokens removed from the LP.
     * @param clbTokenAmounts An array of CLB token amounts corresponding to different fee rates.
     */
    struct RemoveLiquidityBatchCallbackData {
        address provider;
        address recipient;
        uint256 lpTokenAmount;
        uint256[] clbTokenAmounts;
    }

    modifier verifyCallback() virtual {
        if (address(s_state.market) != msg.sender) revert NotMarket();
        _;
    }

    constructor(IAutomateLP automate) ChromaticLPStorage(automate) ReentrancyGuard() {}

    function _createSettleTask(uint256 receiptId) internal {
        s_task[receiptId] = s_automate;
        s_automate.createSettleTask(receiptId);
    }

    function settleTask(
        uint256 receiptId,
        address feePayee,
        uint256 keeperFee
    ) external /* onlyAutomation */ {
        if (address(s_task[receiptId]) != address(0)) {
            uint256 feeMax = _getMaxPayableFeeInSettlement(receiptId);
            uint256 fee = _payKeeperFee(feeMax, feePayee, keeperFee);
            _settle(receiptId, fee);
        } // TODO else revert
    }

    function _getMaxPayableFeeInSettlement(
        uint256 receiptId
    ) internal view returns (uint256 maxFee) {
        ChromaticLPReceipt memory receipt = s_state.getReceipt(receiptId);
        if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
            maxFee = receipt.amount - receipt.amount.mulDiv(s_config.utilizationTargetBPS, BPS);
        } else {
            uint256 balance = s_state.settlementToken().balanceOf(address(this));
            if (receipt.amount == 0) {
                // case of rebalanceRemove
                maxFee = balance;
            } else {
                maxFee = balance.mulDiv(receipt.amount, totalSupply());
            }
        }
    }

    function _payKeeperFee(
        uint256 maxFeeInSettlementToken,
        address feePayee,
        uint256 keeperFee
    ) internal virtual returns (uint256 feeInSettlementAmount) {
        IKeeperFeePayer payer = IKeeperFeePayer(s_state.market.factory().keeperFeePayer());

        IERC20 token = s_state.settlementToken();
        SafeERC20.safeTransfer(token, address(payer), maxFeeInSettlementToken);

        feeInSettlementAmount = payer.payKeeperFee(address(token), keeperFee, feePayee);
    }

    function _settle(uint256 receiptId, uint256 keeperFee) internal returns (bool) {
        ChromaticLPReceipt memory receipt = s_state.getReceipt(receiptId);

        if (
            receipt.id > REBALANCE_ID &&
            receipt.needSettle &&
            receipt.oracleVersion < s_state.oracleVersion()
        ) {
            _cancelSettleTask(receiptId);

            if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
                s_state.claimLiquidity(receipt, keeperFee);
            } else if (receipt.action == ChromaticLPAction.REMOVE_LIQUIDITY) {
                s_state.withdrawLiquidity(receipt, keeperFee);
            } else {
                revert UnknownLPAction();
            }
            return true;
        } else {
            return false;
        }
    }

    function _cancelSettleTask(uint256 receiptId) internal /* onlyOwner */ {
        IAutomateLP automate = s_task[receiptId];
        if (address(automate) != address(0)) {
            delete s_task[receiptId];
            automate.cancelSettleTask(receiptId);
        }
    }

    function _calcRemoveClbAmounts(
        uint256 lpTokenAmount
    ) internal view returns (uint256[] memory clbTokenAmounts) {
        return s_state.calcRemoveClbAmounts(lpTokenAmount, totalSupply());
    }

    function resolveRebalance() external view virtual returns (bool, bytes memory) {
        revert NotImplementedInLogicContract();
    }

    function rebalance() external virtual {}

    function _addLiquidity(
        uint256 amount,
        address provider,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        if (amount <= s_config.automationFeeReserved) {
            revert TooSmallAmountToAddLiquidity();
        }
        receipt = s_state.addLiquidity(
            amount,
            (amount - s_config.automationFeeReserved).mulDiv(s_config.utilizationTargetBPS, BPS),
            provider,
            recipient
        );

        // slither-disable-next-line reentrancy-benign
        _createSettleTask(receipt.id);
    }

    function _removeLiquidity(
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address provider,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        receipt = s_state.removeLiquidity(clbTokenAmounts, lpTokenAmount, provider, recipient);

        // slither-disable-next-line reentrancy-benign
        _createSettleTask(receipt.id);
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function addLiquidityBatchCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external verifyCallback {
        AddLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (AddLiquidityBatchCallbackData)
        );
        if (callbackData.provider != address(this)) {
            //slither-disable-next-line arbitrary-send-erc20
            SafeERC20.safeTransferFrom(
                IERC20(settlementToken),
                callbackData.provider,
                vault,
                callbackData.liquidityAmount
            );
            //slither-disable-next-line arbitrary-send-erc20
            SafeERC20.safeTransferFrom(
                IERC20(settlementToken),
                callbackData.provider,
                address(this),
                callbackData.holdingAmount
            );
        } else {
            SafeERC20.safeTransfer(IERC20(settlementToken), vault, callbackData.liquidityAmount);
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* depositedAmounts */,
        uint256[] calldata /* mintedCLBTokenAmounts */,
        bytes calldata data
    ) external verifyCallback {
        (ChromaticLPReceipt memory receipt, uint256 keeperFee) = abi.decode(
            data,
            (ChromaticLPReceipt, uint256)
        );
        s_state.pendingAddAmount -= receipt.pendingLiquidity;
        uint256 netAmount = receipt.amount - keeperFee;
        if (receipt.recipient != address(this)) {
            uint256 total = s_state.totalValue();

            //slither-disable-next-line incorrect-equality
            uint256 lpTokenMint = totalSupply() == 0
                ? netAmount
                : netAmount.mulDiv(totalSupply(), total - netAmount);
            _mint(receipt.recipient, lpTokenMint);
            emit AddLiquiditySettled({
                receiptId: receipt.id,
                provider: receipt.provider,
                recipient: receipt.recipient,
                settlementAdded: netAmount,
                lpTokenAmount: lpTokenMint,
                keeperFee: keeperFee
            });
            if (receipt.provider.code.length > 0) {
                try
                    IChromaticLPCallback(receipt.provider).claimedCallback(
                        receipt.id,
                        netAmount,
                        lpTokenMint,
                        keeperFee
                    )
                {} catch {}
            }
        } else {
            emit RebalanceSettled({receiptId: receipt.id, keeperFee: keeperFee});
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata _clbTokenIds,
        bytes calldata data
    ) external verifyCallback {
        RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityBatchCallbackData)
        );
        IERC1155(clbToken).safeBatchTransferFrom(
            address(this),
            msg.sender, // market
            _clbTokenIds,
            callbackData.clbTokenAmounts,
            bytes("")
        );

        if (callbackData.provider != address(this) && callbackData.lpTokenAmount > 0) {
            //slither-disable-next-line arbitrary-send-erc20
            SafeERC20.safeTransferFrom(
                IERC20(this),
                callbackData.provider,
                address(this),
                callbackData.lpTokenAmount
            );
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* _feeRates */,
        uint256[] calldata /* withdrawnAmounts */,
        uint256[] calldata /* burnedCLBTokenAmounts */,
        bytes calldata data
    ) external verifyCallback {
        (ChromaticLPReceipt memory receipt, uint256 keeperFee, LpReceipt[] memory lpReceits) = abi
            .decode(data, (ChromaticLPReceipt, uint256, LpReceipt[]));
        s_state.decreasePendingClb(lpReceits);
        // burn and transfer settlementToken

        if (receipt.recipient != address(this)) {
            uint256 totalValue = s_state.totalValue();
            uint256 totalValueBefore = totalValue + keeperFee;

            uint256 withdrawingMaxAmount = totalValueBefore.mulDiv(receipt.amount, totalSupply());

            uint256 burningAmount;
            uint256 withdrawingAmount;

            require(withdrawingMaxAmount > keeperFee, Errors.WITHDRAWAL_LESS_THAN_AUTOMATION_FEE);

            if (withdrawingMaxAmount - keeperFee > s_state.holdingValue()) {
                withdrawingAmount = s_state.holdingValue();
                // burningAmount: (withdrawingAmount + keeperFee) = receipt.amount: withdrawingMaxAmount
                burningAmount = receipt.amount.mulDiv(
                    withdrawingAmount + keeperFee,
                    withdrawingMaxAmount
                );
            } else {
                withdrawingAmount = withdrawingMaxAmount - keeperFee;
                burningAmount = receipt.amount;
            }

            uint256 remainingAmount = receipt.amount - burningAmount;

            emit RemoveLiquiditySettled({
                receiptId: receipt.id,
                provider: receipt.provider,
                recipient: receipt.recipient,
                burningAmount: burningAmount,
                withdrawnSettlementAmount: withdrawingAmount,
                refundedAmount: remainingAmount,
                keeperFee: keeperFee
            });

            SafeERC20.safeTransfer(s_state.settlementToken(), receipt.recipient, withdrawingAmount);

            // burn LPToken requested
            if (burningAmount > 0) {
                _burn(address(this), burningAmount);
            }
            if (remainingAmount > 0) {
                SafeERC20.safeTransfer(IERC20(this), receipt.recipient, remainingAmount);
            }
            if (receipt.provider.code.length > 0) {
                try
                    IChromaticLPCallback(receipt.provider).withdrawnCallback(
                        receipt.id,
                        burningAmount,
                        withdrawingAmount,
                        remainingAmount,
                        keeperFee
                    )
                {} catch {}
            }
        } else {
            emit RebalanceSettled({receiptId: receipt.id, keeperFee: keeperFee});
        }
    }

    function _rebalance() internal returns (uint256) {
        (uint256 currentUtility, uint256 valueTotal) = s_state.utilizationInfo();
        if (valueTotal == 0) return 0;

        AllocationStatus status = s_config.allocationStatus(currentUtility);

        if (status == AllocationStatus.OverUtilized) {
            return _rebalanceRemoveLiquidity(currentUtility);
        } else if (status == AllocationStatus.UnderUtilized) {
            return _rebalanceAddLiquidity(currentUtility);
        } else {
            return 0;
        }
    }

    function _rebalanceRemoveLiquidity(uint256 currentUtility) private returns (uint256 receiptId) {
        uint256[] memory _clbTokenBalances = s_state.clbTokenBalances();
        uint256 binCount = s_state.binCount();
        uint256[] memory clbTokenAmounts = new uint256[](binCount);
        for (uint256 i; i < binCount; ) {
            clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                currentUtility - s_config.utilizationTargetBPS,
                currentUtility
            );
            unchecked {
                ++i;
            }
        }
        ChromaticLPReceipt memory receipt = _removeLiquidity(
            clbTokenAmounts,
            0,
            address(this),
            address(this)
        );
        //slither-disable-next-line reentrancy-events
        emit RebalanceRemoveLiquidity(receipt.id, receipt.oracleVersion, currentUtility);
        return receipt.id;
    }

    function _rebalanceAddLiquidity(uint256 currentUtility) private returns (uint256 receiptId) {
        uint256 amount = _estimateRebalanceAddAmount(currentUtility);

        ChromaticLPReceipt memory receipt = _addLiquidity(amount, address(this), address(this));
        //slither-disable-next-line reentrancy-events
        emit RebalanceAddLiquidity(receipt.id, receipt.oracleVersion, amount, currentUtility);
        return receipt.id;
    }
}
