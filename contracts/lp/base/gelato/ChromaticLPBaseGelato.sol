// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorageGelato} from "~/lp/base/gelato/ChromaticLPStorageGelato.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {TrimAddress} from "~/lp/libraries/TrimAddress.sol";

abstract contract ChromaticLPBaseGelato is ChromaticLPStorageGelato {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    address _owner;
    modifier onlyOwner() virtual {
        if (msg.sender != _owner) revert OnlyAccessableByOwner();
        _;
    }

    constructor(AutomateParam memory automateParam) ChromaticLPStorageGelato(automateParam) {
        _owner = msg.sender;
    }

    function _initialize(
        LPMeta memory meta,
        Config memory config,
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
        s_config = Config({
            market: config.market,
            utilizationTargetBPS: config.utilizationTargetBPS,
            rebalanceBPS: config.rebalanceBPS,
            rebalanceCheckingInterval: config.rebalanceCheckingInterval,
            settleCheckingInterval: config.settleCheckingInterval
        });
        _setupState(_feeRates, distributionRates);
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

    function _setupState(int16[] memory _feeRates, uint16[] memory distributionRates) private {
        uint16 totalRate;
        for (uint256 i; i < distributionRates.length; ) {
            s_state.distributionRates[_feeRates[i]] = distributionRates[i];
            totalRate += distributionRates[i];

            unchecked {
                i++;
            }
        }
        if (totalRate != BPS) revert InvalidDistributionSum();
        s_state.feeRates = _feeRates;

        _setupClbTokenIds(_feeRates);
    }

    function _setupClbTokenIds(int16[] memory _feeRates) private {
        s_state.clbTokenIds = new uint256[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ) {
            s_state.clbTokenIds[i] = CLBTokenLib.encodeId(_feeRates[i]);

            unchecked {
                i++;
            }
        }
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
                    TrimAddress.trimAddress(address(s_config.market), 4),
                    "-",
                    bytes(s_meta.tag)[0]
                )
            );
    }

    function _tokenSymbol() internal view returns (string memory) {
        return s_config.market.settlementToken().symbol();
    }

    function _indexName() internal view returns (string memory) {
        return s_config.market.oracleProvider().description();
    }

    function _resolveRebalance(
        function() external _rebalance
    ) internal view returns (bool, bytes memory) {
        ValueInfo memory value = valueInfo();

        if (value.total == 0) return (false, bytes(""));

        uint256 currentUtility = (value.holdingClb + value.pending - value.pendingClb).mulDiv(
            BPS,
            value.total
        );

        if (uint256(s_config.utilizationTargetBPS + s_config.rebalanceBPS) < currentUtility) {
            return (true, abi.encodeCall(_rebalance, ()));
        } else if (
            uint256(s_config.utilizationTargetBPS - s_config.rebalanceBPS) > currentUtility
        ) {
            return (true, abi.encodeCall(_rebalance, ()));
        }
        return (false, bytes(""));
    }

    function _resolveSettle(
        uint256 receiptId,
        function(uint256) external settleTask
    ) internal view returns (bool, bytes memory) {
        IOracleProvider.OracleVersion memory currentOracle = s_config
            .market
            .oracleProvider()
            .currentVersion();

        ChromaticLPReceipt memory receipt = s_state.receipts[receiptId];
        if (receipt.id > 0 && receipt.oracleVersion < currentOracle.version) {
            return (true, abi.encodeCall(settleTask, (receiptId)));
        }

        // for pending add/remove by user and by self
        return (false, bytes(""));
    }
}
