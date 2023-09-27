// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPLogicBaseMate2} from "~/lp/base/mate2/ChromaticLPLogicBaseMate2.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";

contract ChromaticLPLogicMate2 is ChromaticLPLogicBaseMate2 {
    using Math for uint256;

    constructor(IMate2AutomationRegistry _automate) ChromaticLPLogicBaseMate2(_automate) {}

    /**
     * @dev implementation of IChromaticLP
     */
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory receipt) {
        receipt = _addLiquidity(amount, recipient);
        emit AddLiquidity({
            receiptId: receipt.id,
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
    ) external returns (ChromaticLPReceipt memory receipt) {
        uint256[] memory clbTokenAmounts = _calcRemoveClbAmounts(lpTokenAmount);

        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);
        emit RemoveLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function settle(uint256 receiptId) public override returns (bool) {
        return _settle(receiptId);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function rebalance() internal override onlyAutomation {
        uint256 receiptId = _rebalance();
        if (receiptId != 0) {
            emit RebalanceLiquidity({receiptId: receiptId});
            _payKeeperFee();
        }
    }
}