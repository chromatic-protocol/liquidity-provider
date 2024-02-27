// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {ChromaticLPLogicBase} from "~/lp/base/ChromaticLPLogicBase.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {LPConfigLib, LPConfig, AllocationStatus} from "~/lp/libraries/LPConfig.sol";

contract ChromaticLPLogic is ChromaticLPLogicBase {
    using Math for uint256;
    using LPStateViewLib for LPState;
    using LPStateValueLib for LPState;
    using LPConfigLib for LPConfig;

    constructor(bytes32 _version) ChromaticLPLogicBase(_version) {}

    /**
     * @dev implementation of IChromaticLP
     */
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external nonReentrant returns (ChromaticLPReceipt memory receipt) {
        receipt = _addLiquidity(amount, msg.sender, recipient);
        //slither-disable-next-line reentrancy-events
        emit AddLiquidity({
            receiptId: receipt.id,
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            amount: amount
        });
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external nonReentrant returns (ChromaticLPReceipt memory receipt) {
        if (lpTokenAmount == 0) revert ZeroRemoveLiquidityError();
        uint256[] memory clbTokenAmounts = _calcRemoveClbAmounts(lpTokenAmount);

        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, msg.sender, recipient);
        //slither-disable-next-line reentrancy-events
        emit RemoveLiquidity({
            receiptId: receipt.id,
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function settle(uint256 receiptId) external nonReentrant {
        _settle(receiptId, 0);
    }

    function cancelSettleTask(uint256 receiptId) external /* onlyOwner */ {
        _cancelSettleTask(receiptId);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function rebalance(
        address feePayee,
        uint256 keeperFee // native token amount
    ) external nonReentrant {
        (uint256 currentUtility, uint256 valueTotal) = s_state.utilizationInfo();
        if (valueTotal == 0) return;

        AllocationStatus status = s_config.allocationStatus(currentUtility);

        if (status != AllocationStatus.InRange) {
            uint256 balance = s_state.settlementToken().balanceOf(address(this));
            _payKeeperFee(balance, feePayee, keeperFee);
            _rebalance();
        }
    }
}
