// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPBaseMate2} from "~/lp/base/mate2/ChromaticLPBaseMate2.sol";
import {ChromaticLPLogicMate2} from "~/lp/contracts/mate2/ChromaticLPLogicMate2.sol";
import {ChromaticLPStorageMate2} from "~/lp/base/mate2/ChromaticLPStorageMate2.sol";

import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";

uint16 constant BPS = 10000;

contract ChromaticLPMate2 is
    IChromaticLP,
    IChromaticLiquidityCallback,
    IERC1155Receiver,
    ChromaticLPBaseMate2,
    Proxy
{
    // using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    address public immutable CHROMATIC_LP_LOGIC;

    error NotImplementedInProxyContract();

    constructor(
        ChromaticLPLogicMate2 lpLogic,
        LPMeta memory lpMeta,
        Config memory config,
        int16[] memory _feeRates,
        uint16[] memory distributionRates,
        IMate2AutomationRegistry _automate
    ) ChromaticLPBaseMate2(_automate) {
        CHROMATIC_LP_LOGIC = address(lpLogic);

        _initialize(lpMeta, config, _feeRates, distributionRates);
    }

    function createRebalanceTask() external onlyOwner {
        if (s_task.rebalanceTaskId != 0) revert AlreadyRebalanceTaskExist();
        s_task.rebalanceTaskId = _registerUpkeep(
            UpkeepType.Rebalance,
            0,
            false // is not singleExec
        );
    }

    function cancelRebalanceTask() external onlyOwner {
        _fallback();
    }

    /**
     * @dev This is the address to which proxy functions are delegated to
     */
    function _implementation() internal view virtual override returns (address) {
        return CHROMATIC_LP_LOGIC;
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function addLiquidity(
        uint256 /* amount */,
        address /* recipient */
    ) external override returns (ChromaticLPReceipt memory /* receipt */) {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function removeLiquidity(
        uint256 /* lpTokenAmount */,
        address /* recipient */
    ) external override returns (ChromaticLPReceipt memory /* receipt */) {
        _fallback();
    }

    function rebalance() internal pure override {
        revert NotImplementedInProxyContract();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settle(
        uint256 /* receiptId */
    ) public override(IChromaticLP, ChromaticLPStorageMate2) returns (bool) {
        _fallback();
    }

    // function resolveSettle(
    //     uint256 receiptId
    // ) public view override returns (bool upkeepNeeded, bytes memory performData) {}

    // function resolveRebalance()
    //     public
    //     view
    //     virtual
    //     override
    //     returns (bool upkeepNeeded, bytes memory performData)
    // {}

    function resolveSettle(uint256 receiptId) public view override returns (bool, bytes memory) {
        return _resolveSettle(receiptId);
    }

    function resolveRebalance() public view override returns (bool, bytes memory) {
        return _resolveRebalance();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function lpName() external view override returns (string memory) {
        return s_meta.lpName;
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function market() external view override returns (address) {
        return address(s_config.market);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settlementToken() external view override returns (address) {
        return address(s_config.market.settlementToken());
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function lpToken() external view override returns (address) {
        return address(this);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function getReceiptIdsOf(
        address owner
    ) external view override returns (uint256[] memory receiptIds) {
        return s_state.providerReceiptIds[owner].values();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function getReceipt(
        uint256 receiptId
    ) external view override returns (ChromaticLPReceipt memory) {
        return s_state.receipts[receiptId];
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
}
