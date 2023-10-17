// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPLogicBase} from "~/lp/base/ChromaticLPLogicBase.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";

contract ChromaticLPLogic is ChromaticLPLogicBase {
    using Math for uint256;
    using LPStateViewLib for LPState;

    constructor(
        AutomateParam memory automateParam
    )
        ChromaticLPLogicBase(
            AutomateParam({
                automate: automateParam.automate,
                opsProxyFactory: automateParam.opsProxyFactory
            })
        )
    {}

    /**
     * @dev implementation of IChromaticLP
     */
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory receipt) {
        emit AddLiquidity({
            receiptId: receipt.id,
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            amount: amount
        });
        receipt = _addLiquidity(amount, recipient);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external returns (ChromaticLPReceipt memory receipt) {
        uint256[] memory clbTokenAmounts = _calcRemoveClbAmounts(lpTokenAmount);

        emit RemoveLiquidity({
            receiptId: receipt.id,
            provider: msg.sender,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });
        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function settle(uint256 receiptId) external returns (bool) {
        return _settle(receiptId);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function rebalance() external override {
        uint256 receiptId = _rebalance();
        if (receiptId != 0) {
            uint256 balance = s_state.settlementToken().balanceOf(address(this));
            _payKeeperFee(balance);
        }
    }
}
