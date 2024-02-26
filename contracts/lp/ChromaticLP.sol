// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPAdmin} from "~/lp/interfaces/IChromaticLPAdmin.sol";
import {IChromaticLPLiquidity} from "~/lp/interfaces/IChromaticLPLiquidity.sol";
import {IChromaticLPMeta} from "~/lp/interfaces/IChromaticLPMeta.sol";
import {ChromaticLPBase} from "~/lp/base/ChromaticLPBase.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {LPState, REBALANCE_ID} from "~/lp/libraries/LPState.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {IChromaticLPAutomate} from "~/lp/interfaces/IChromaticLPAutomate.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";

contract ChromaticLP is ChromaticLPBase, Proxy, IChromaticLiquidityCallback, IERC1155Receiver {
    using EnumerableSet for EnumerableSet.UintSet;
    using LPStateViewLib for LPState;

    constructor(
        address logicAddress,
        LPMeta memory lpMeta,
        ConfigParam memory config,
        int16[] memory _feeRates,
        uint16[] memory _distributionRates,
        IAutomateLP automate
    ) ChromaticLPBase() {
        _initialize(lpMeta, config, _feeRates, _distributionRates, automate, logicAddress);
    }

    /**
     * @inheritdoc IChromaticLPAdmin
     */
    function createRebalanceTask() public onlyDao {
        s_task[REBALANCE_ID] = s_automate;
        s_automate.createRebalanceTask();
    }

    /**
     * @inheritdoc IChromaticLPAdmin
     */
    function cancelRebalanceTask() external onlyDao {
        IAutomateLP automate = s_task[REBALANCE_ID];
        delete s_task[REBALANCE_ID];
        automate.cancelRebalanceTask();
    }

    /**
     * @inheritdoc IChromaticLPAdmin
     */
    function cancelSettleTask(uint256 /* receiptId */) external onlyDao {
        _fallback();
    }

    /**
     * @dev This is the address to which proxy functions are delegated to
     */
    function _implementation() internal view virtual override returns (address) {
        return s_logicAddress;
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function addLiquidity(
        uint256 amount,
        address /* recipient */
    ) external override addLiquidityEnabled returns (ChromaticLPReceipt memory /* receipt */) {
        if (amount < estimateMinAddLiquidityAmount()) {
            revert TooSmallAmountToAddLiquidity();
        }
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function removeLiquidity(
        uint256 /* lpTokenAmount */,
        address /* recipient */
    ) external override removeLiquidityEnabled returns (ChromaticLPReceipt memory /* receipt */) {
        // NOTE:
        // if lpTokenAmount is too small then settlement couldn't be completed by automation
        // user should call manually `settle(receiptId)`
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function settle(uint256 /* receiptId */) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLPAdmin
     */
    function setAutomationFeeReserved(
        uint256 _automationFeeReserved
    ) external override(IChromaticLPAdmin) onlyDao {
        emit SetAutomationFeeReserved(_automationFeeReserved);
        s_config.automationFeeReserved = _automationFeeReserved;
    }

    /**
     * @inheritdoc IChromaticLPAdmin
     */
    function setMinHoldingValueToRebalance(
        uint256 _minHoldingValueToRebalance
    ) external override(IChromaticLPAdmin) onlyDao {
        if (_minHoldingValueToRebalance < s_config.automationFeeReserved) {
            revert InvalidMinHoldingValueToRebalance();
        }
        emit SetMinHoldingValueToRebalance(_minHoldingValueToRebalance);
        s_config.minHoldingValueToRebalance = _minHoldingValueToRebalance;
    }

    /**
     * @inheritdoc IChromaticLPMeta
     */
    function lpName() external view override returns (string memory) {
        return s_meta.lpName;
    }

    /**
     * @inheritdoc IChromaticLPMeta
     */
    function lpTag() external view override returns (string memory) {
        return s_meta.tag;
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function market() external view override returns (address) {
        return address(s_state.market);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settlementToken() external view override returns (address) {
        return address(s_state.market.settlementToken());
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function lpToken() external view override returns (address) {
        return address(this);
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function getReceiptIdsOf(
        address owner_
    ) external view override returns (uint256[] memory receiptIds) {
        return s_state.providerReceiptIds[owner_].values();
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function getReceipt(
        uint256 receiptId
    ) external view override returns (ChromaticLPReceipt memory) {
        return s_state.getReceipt(receiptId);
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function getMarketReceiptsOf(uint256 receiptId) external view returns (uint256[] memory) {
        return s_state.lpReceiptMap[receiptId];
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function addLiquidityCallback(address, address, bytes calldata) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function claimLiquidityCallback(
        uint256 /* receiptId */,
        int16 /* feeRate */,
        uint256 /* depositedAmount */,
        uint256 /* mintedCLBTokenAmount */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function removeLiquidityCallback(
        address /* clbToken */,
        uint256 /* clbTokenId */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function withdrawLiquidityCallback(
        uint256 /* receiptId */,
        int16 /* feeRate */,
        uint256 /* withdrawnAmount */,
        uint256 /* burnedCLBTokenAmount */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function addLiquidityBatchCallback(
        address /* settlementToken */,
        address /* vault */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* depositedAmounts */,
        uint256[] calldata /* mintedCLBTokenAmounts */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function removeLiquidityBatchCallback(
        address /* clbToken */,
        uint256[] calldata /* clbTokenIds */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* withdrawnAmounts */,
        uint256[] calldata /* burnedCLBTokenAmounts */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155Received(
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }

    /**
     * @dev called by automation only
     */
    function rebalance(
        address /* feePayee */,
        uint256 /* keeperFee */
    ) external onlyAutomation(REBALANCE_ID) {
        _fallback();
    }

    /**
     * @dev called by automation only
     */
    function settleTask(
        uint256 receiptId,
        address /* feePayee */,
        uint256 /* keeperFee */
    ) external onlyAutomation(receiptId) {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLPAutomate
     */
    function setAutomateLP(IAutomateLP automate) external override onlyDao {
        emit SetAutomateLP(address(automate));
        _setAutomateLP(automate);
    }

    /**
     * @inheritdoc IChromaticLPAutomate
     */
    function automateLP() external view override returns (IAutomateLP) {
        return s_automate;
    }
}
