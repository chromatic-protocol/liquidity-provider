// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorageGelato} from "~/lp/base/gelato/ChromaticLPStorageGelato.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {LPState} from "~/lp/libraries/LPState.sol";

import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {LPStateLogicLib} from "~/lp/libraries/LPStateLogic.sol";
import {BPS} from "~/lp/libraries/Constants.sol";

abstract contract ChromaticLPLogicBaseGelato is ChromaticLPStorageGelato {
    using Math for uint256;

    using LPStateValueLib for LPState;
    using LPStateViewLib for LPState;
    using LPStateLogicLib for LPState;

    struct AddLiquidityBatchCallbackData {
        address provider;
        uint256 liquidityAmount;
        uint256 holdingAmount;
    }

    struct RemoveLiquidityBatchCallbackData {
        address provider;
        uint256 lpTokenAmount;
        uint256[] clbTokenAmounts;
    }

    modifier verifyCallback() virtual {
        if (address(s_state.market) != msg.sender) revert NotMarket();
        _;
    }

    constructor(AutomateParam memory automateParam) ChromaticLPStorageGelato(automateParam) {}

    function cancelRebalanceTask() external {
        if (s_task.rebalanceTaskId != 0) {
            automate.cancelTask(s_task.rebalanceTaskId);
            s_task.rebalanceTaskId = 0;
        }
    }

    function createSettleTask(uint256 receiptId) internal {
        if (s_task.settleTasks[receiptId] == 0) {
            s_task.settleTasks[receiptId] = _createTask(
                abi.encodeCall(this.resolveSettle, (receiptId)),
                abi.encodeCall(this.settleTask, (receiptId)),
                s_config.settleCheckingInterval
            );
        }
    }

    function cancelSettleTask(uint256 receiptId) internal {
        if (s_task.settleTasks[receiptId] != 0) {
            automate.cancelTask(s_task.settleTasks[receiptId]);
            delete s_task.settleTasks[receiptId];
        }
    }

    function settleTask(uint256 receiptId) external /* onlyAutomation */ {
        if (s_task.settleTasks[receiptId] != 0) {
            uint256 feeMax = _getMaxPayableFeeInSettlement(receiptId);
            if (_settle(receiptId)) {
                _payKeeperFee(feeMax);
            }
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
            maxFee = balance.mulDiv(receipt.amount, totalSupply());
        }
    }

    function _payKeeperFee(uint256 maxFeeInSettlementToken) internal virtual {
        (uint256 fee, address feePayee) = _getFeeInfo();
        IKeeperFeePayer payer = IKeeperFeePayer(s_state.market.factory().keeperFeePayer());

        IERC20 token = s_state.settlementToken();
        SafeERC20.safeTransfer(token, address(payer), maxFeeInSettlementToken);

        payer.payKeeperFee(address(token), fee, feePayee);
    }

    function _settle(uint256 receiptId) internal returns (bool) {
        ChromaticLPReceipt memory receipt = s_state.getReceipt(receiptId);

        // TODO check receipt
        if (receipt.oracleVersion < s_state.oracleVersion()) {
            if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
                s_state.claimLiquidity(receipt);
            } else if (receipt.action == ChromaticLPAction.REMOVE_LIQUIDITY) {
                s_state.withdrawLiquidity(receipt);
            } else {
                revert UnknownLPAction();
            }
            // finally remove settle task
            cancelSettleTask(receiptId);
            return true;
        } else {
            return false;
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

    function resolveSettle(
        uint256 /* receiptId */
    ) external view virtual returns (bool, bytes memory) {
        revert NotImplementedInLogicContract();
    }

    function rebalance() external virtual {}

    function _addLiquidity(
        uint256 amount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        receipt = s_state.addLiquidity(
            amount,
            amount.mulDiv(s_config.utilizationTargetBPS, BPS),
            recipient
        );

        createSettleTask(receipt.id);
    }

    function _removeLiquidity(
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        receipt = s_state.removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);

        createSettleTask(receipt.id);
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
        //slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(
            IERC20(settlementToken),
            callbackData.provider,
            vault,
            callbackData.liquidityAmount
        );

        if (callbackData.provider != address(this)) {
            SafeERC20.safeTransferFrom(
                IERC20(settlementToken),
                callbackData.provider,
                address(this),
                callbackData.holdingAmount
            );
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
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));
        s_state.pendingAddAmount -= receipt.pendingLiquidity;

        if (receipt.recipient != address(this)) {
            uint256 total = s_state.totalValue();

            uint256 lpTokenMint = totalSupply() == 0
                ? receipt.amount
                : receipt.amount.mulDiv(totalSupply(), total - receipt.amount);
            _mint(receipt.recipient, lpTokenMint);
            emit AddLiquiditySettled({
                receiptId: receipt.id,
                provider: receipt.provider,
                recipient: receipt.recipient,
                settlementAdded: receipt.amount,
                lpTokenAmount: lpTokenMint
            });
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata _clbTokenIds,
        bytes calldata data
    ) external {
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

        if (callbackData.provider != address(this)) {
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
        uint256[] calldata receiptIds,
        int16[] calldata _feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));

        s_state.decreasePendingClb(_feeRates, burnedCLBTokenAmounts);
        // burn and transfer settlementToken

        if (receipt.recipient != address(this)) {
            uint256 value = s_state.totalValue();

            uint256 withdrawnAmount;
            for (uint256 i; i < receiptIds.length; ) {
                withdrawnAmount += withdrawnAmounts[i];
                unchecked {
                    ++i;
                }
            }
            // (tokenBalance - withdrawn) * (burningLP /totalSupplyLP) + withdrawn
            uint256 balance = s_state.settlementToken().balanceOf(address(this));
            uint256 withdrawAmount = (balance - withdrawnAmount).mulDiv(
                receipt.amount,
                totalSupply()
            ) + withdrawnAmount;

            SafeERC20.safeTransfer(s_state.settlementToken(), receipt.recipient, withdrawAmount);
            // burningLP: withdrawAmount = totalSupply: totalValue
            // burningLP = withdrawAmount * totalSupply / totalValue
            // burn LPToken requested
            uint256 burningAmount = withdrawAmount.mulDiv(totalSupply(), value);
            _burn(address(this), burningAmount);

            // transfer left lpTokens
            uint256 remainingAmount = receipt.amount - burningAmount;
            if (remainingAmount > 0) {
                SafeERC20.safeTransfer(IERC20(this), receipt.recipient, remainingAmount);
            }

            emit RemoveLiquiditySettled({
                receiptId: receipt.id,
                provider: receipt.provider,
                recipient: receipt.recipient,
                burningAmount: burningAmount,
                witdrawnSettlementAmount: withdrawAmount,
                refundedAmount: remainingAmount
            });
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    function _rebalance() internal returns (uint256) {
        // (uint256 total, uint256 clbValue, ) = _poolValue();
        ValueInfo memory value = s_state.valueInfo();

        if (value.total == 0) return 0;

        uint256 currentUtility = (value.holdingClb + value.pending - value.pendingClb).mulDiv(
            BPS,
            value.total
        );
        if (uint256(s_config.utilizationTargetBPS + s_config.rebalanceBPS) < currentUtility) {
            uint256[] memory _clbTokenBalances = s_state.clbTokenBalances();
            uint256 binCount = s_state.binCount();
            uint256[] memory clbTokenAmounts = new uint256[](binCount);
            for (uint256 i; i < binCount; ) {
                clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                    s_config.rebalanceBPS,
                    currentUtility
                );
                unchecked {
                    ++i;
                }
            }
            ChromaticLPReceipt memory receipt = _removeLiquidity(clbTokenAmounts, 0, address(this));
            emit RebalanceRemoveLiquidity(receipt.id, receipt.oracleVersion, currentUtility);
            return receipt.id;
        } else if (
            uint256(s_config.utilizationTargetBPS - s_config.rebalanceBPS) > currentUtility
        ) {
            uint256 amount = (value.total).mulDiv(s_config.rebalanceBPS, BPS);
            ChromaticLPReceipt memory receipt = _addLiquidity(
                (value.total).mulDiv(s_config.rebalanceBPS, BPS),
                address(this)
            );
            emit RebalanceAddLiquidity(receipt.id, receipt.oracleVersion, amount, currentUtility);
            return receipt.id;
        }
        return 0;
    }
}
