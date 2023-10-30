// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorage} from "~/lp/base/ChromaticLPStorage.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {TrimAddress} from "~/lp/libraries/TrimAddress.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPConfig} from "~/lp/libraries/LPConfig.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPLens} from "~/lp/interfaces/IChromaticLPLens.sol";
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
        uint16[] memory distributionRates
    ) internal {
        _validateConfig(
            config.utilizationTargetBPS,
            config.rebalanceBPS,
            _feeRates,
            distributionRates
        );
        s_meta = LPMeta({lpName: meta.lpName, tag: meta.tag});
        s_config = LPConfig({
            utilizationTargetBPS: config.utilizationTargetBPS,
            rebalanceBPS: config.rebalanceBPS,
            rebalanceCheckingInterval: config.rebalanceCheckingInterval,
            settleCheckingInterval: config.settleCheckingInterval,
            automationFeeReserved: config.automationFeeReserved
        });
        s_state.initialize(config.market, _feeRates, distributionRates);
    }

    function _validateConfig(
        uint16 utilizationTargetBPS,
        uint16 rebalanceBPS,
        int16[] memory _feeRates,
        uint16[] memory distributionRates
    ) private pure {
        if (utilizationTargetBPS > BPS) revert InvalidUtilizationTarget(utilizationTargetBPS);
        if (_feeRates.length != distributionRates.length)
            revert NotMatchDistributionLength(_feeRates.length, distributionRates.length);

        if (utilizationTargetBPS <= rebalanceBPS) revert InvalidRebalanceBPS();
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
        if (s_state.holdingValue() < s_config.automationFeeReserved) {
            return (false, bytes(""));
        }

        (uint256 currentUtility, uint256 value) = s_state.utilizationInfo();
        if (value == 0) return (false, bytes(""));

        if (s_config.allocationStatus(currentUtility) == AllocationStatus.InRange) {
            return (false, bytes(""));
        } else {
            return (true, abi.encodeCall(_rebalance, ()));
        }
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
}
