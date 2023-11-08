// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {TrimAddress} from "~/lp/libraries/TrimAddress.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPConfig} from "~/lp/libraries/LPConfig.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPLens} from "~/lp/interfaces/IChromaticLPLens.sol";
import {IChromaticLPLiquidity} from "~/lp/interfaces/IChromaticLPLiquidity.sol";
import {IChromaticLPConfigLens} from "~/lp/interfaces/IChromaticLPConfigLens.sol";
import {IChromaticLPMeta} from "~/lp/interfaces/IChromaticLPMeta.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPStateValueLib} from "~/lp/libraries/LPStateValue.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {LPStateSetupLib} from "~/lp/libraries/LPStateSetup.sol";
import {LPConfigLib, LPConfig, AllocationStatus} from "~/lp/libraries/LPConfig.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {Errors} from "~/lp/libraries/Errors.sol";

abstract contract ChromaticLPBase is ChromaticLPStorage, IChromaticLP {
    using Math for uint256;
    using LPStateViewLib for LPState;
    using LPStateValueLib for LPState;
    using LPStateSetupLib for LPState;
    using LPConfigLib for LPConfig;

    address immutable _owner;
    modifier onlyOwner() virtual {
        if (msg.sender != _owner) revert OnlyAccessableByOwner();
        _;
    }

    constructor(AutomateParam memory automateParam) ChromaticLPStorage(automateParam) {
        _owner = msg.sender;
    }

    function _initialize(
        LPMeta memory meta,
        ConfigParam memory config,
        int16[] memory _feeRates,
        uint16[] memory _distributionRates
    ) internal {
        _validateConfig(
            config.utilizationTargetBPS,
            config.rebalanceBPS,
            _feeRates,
            _distributionRates
        );
        if (config.automationFeeReserved > config.minHoldingValueToRebalance) {
            revert InvalidMinHoldingValueToRebalance();
        }

        emit SetLpName(meta.lpName);
        emit SetLpTag(meta.tag);

        s_meta = LPMeta({lpName: meta.lpName, tag: meta.tag});

        s_config = LPConfig({
            utilizationTargetBPS: config.utilizationTargetBPS,
            rebalanceBPS: config.rebalanceBPS,
            rebalanceCheckingInterval: config.rebalanceCheckingInterval,
            settleCheckingInterval: config.settleCheckingInterval,
            automationFeeReserved: config.automationFeeReserved,
            minHoldingValueToRebalance: config.minHoldingValueToRebalance
        });
        s_state.initialize(config.market, _feeRates, _distributionRates);
    }

    function _validateConfig(
        uint16 _utilizationTargetBPS,
        uint16 _rebalanceBPS,
        int16[] memory _feeRates,
        uint16[] memory _distributionRates
    ) private pure {
        if (_utilizationTargetBPS > BPS) revert InvalidUtilizationTarget(_utilizationTargetBPS);
        if (_feeRates.length != _distributionRates.length)
            revert NotMatchDistributionLength(_feeRates.length, _distributionRates.length);

        if (_utilizationTargetBPS <= _rebalanceBPS) revert InvalidRebalanceBPS();
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view virtual override returns (string memory) {
        return string(abi.encodePacked("ChromaticLP - ", _tokenSymbol(), " - ", _indexName()));
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view virtual override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "CLP-",
                    TrimAddress.trimAddress(address(s_state.market), 4),
                    "-",
                    bytes(s_meta.tag)[0]
                )
            );
    }

    function _tokenSymbol() internal view returns (string memory) {
        return s_state.settlementToken().symbol();
    }

    function _indexName() internal view returns (string memory) {
        return s_state.market.oracleProvider().description();
    }

    function _resolveRebalance(
        function() external _rebalance
    ) internal view returns (bool, bytes memory) {
        if (s_state.holdingValue() < s_config.minHoldingValueToRebalance) {
            return (false, bytes(""));
        }
        (uint256 currentUtility, uint256 value) = s_state.utilizationInfo();
        if (value == 0) return (false, bytes(""));

        AllocationStatus status = s_config.allocationStatus(currentUtility);

        if (status == AllocationStatus.OverUtilized) {
            // estimate this remove rebalancing is meaningful for paying automationFee
            if (_estimateRebalanceRemoveValue(currentUtility) >= s_config.automationFeeReserved) {
                return (true, abi.encodeCall(_rebalance, ()));
            }
        } else if (status == AllocationStatus.UnderUtilized) {
            // check if it could be settled by automation
            if (_estimateRebalanceAddAmount(currentUtility) >= estimateMinAddLiquidityAmount()) {
                return (true, abi.encodeCall(_rebalance, ()));
            }
        }
        return (false, bytes(""));
    }

    function _resolveSettle(
        uint256 receiptId,
        function(uint256) external settleTask
    ) internal view returns (bool, bytes memory) {
        if (s_state.holdingValue() < s_config.automationFeeReserved) {
            return (false, bytes(""));
        }

        ChromaticLPReceipt memory receipt = s_state.getReceipt(receiptId);
        if (receipt.id > 0 && receipt.oracleVersion < s_state.oracleVersion()) {
            return (true, abi.encodeCall(settleTask, (receiptId)));
        }

        // for pending add/remove by user and by self
        return (false, bytes(""));
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function utilization() public view override returns (uint16 currentUtility) {
        //slither-disable-next-line unused-return
        (currentUtility, ) = s_state.utilizationInfo();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function totalValue() public view override returns (uint256 value) {
        value = s_state.totalValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function valueInfo() public view override returns (ValueInfo memory info) {
        return s_state.valueInfo();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function holdingValue() public view override returns (uint256) {
        return s_state.holdingValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function pendingValue() public view override returns (uint256) {
        return s_state.pendingValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function holdingClbValue() public view override returns (uint256 value) {
        return s_state.holdingClbValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function pendingClbValue() public view override returns (uint256 value) {
        return s_state.pendingClbValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function totalClbValue() public view override returns (uint256 value) {
        return s_state.totalClbValue();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function feeRates() external view override returns (int16[] memory) {
        return s_state.feeRates;
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function clbTokenIds() external view override returns (uint256[] memory) {
        return s_state.clbTokenIds;
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function clbTokenBalances() public view override returns (uint256[] memory _clbTokenBalances) {
        return s_state.clbTokenBalances();
    }

    /**
     * @inheritdoc IChromaticLPLens
     */
    function pendingRemoveClbBalances() public view override returns (uint256[] memory) {
        return s_state.pendingRemoveClbBalances();
    }

    /**
     * @inheritdoc IChromaticLPMeta
     */
    function setLpName(string memory newName) external onlyOwner {
        emit SetLpName(newName);
        s_meta.lpName = newName;
    }

    /**
     * @inheritdoc IChromaticLPMeta
     */
    function setLpTag(string memory tag) external onlyOwner {
        emit SetLpTag(tag);
        s_meta.tag = tag;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function utilizationTargetBPS() external view returns (uint256) {
        return s_config.utilizationTargetBPS;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function rebalanceBPS() external view returns (uint256) {
        return s_config.rebalanceBPS;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function rebalanceCheckingInterval() external view returns (uint256) {
        return s_config.rebalanceCheckingInterval;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function settleCheckingInterval() external view returns (uint256) {
        return s_config.settleCheckingInterval;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function minHoldingValueToRebalance() external view returns (uint256) {
        return s_config.minHoldingValueToRebalance;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function automationFeeReserved() external view returns (uint256) {
        return s_config.automationFeeReserved;
    }

    /**
     * @inheritdoc IChromaticLPConfigLens
     */
    function distributionRates() external view returns (uint16[] memory rates) {
        rates = new uint16[](s_state.binCount());
        for (uint256 i; i < s_state.binCount(); ) {
            rates[i] = s_state.distributionRates[s_state.feeRates[i]];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function estimateMinAddLiquidityAmount() public view returns (uint256) {
        return
            s_config.automationFeeReserved +
            s_config.automationFeeReserved.mulDiv(BPS, BPS - s_config.utilizationTargetBPS);
    }

    /**
     * @inheritdoc IChromaticLPLiquidity
     */
    function estimateMinRemoveLiquidityAmount() public view returns (uint256) {
        return s_config.automationFeeReserved.mulDiv(totalSupply(), holdingValue());
    }
}
