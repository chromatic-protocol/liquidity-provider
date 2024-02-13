// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLPLens, ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {LPConfig} from "~/lp/libraries/LPConfig.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";

abstract contract ChromaticLPStorageCore is ERC20, IChromaticLPEvents, IChromaticLPErrors {
    using LPStateViewLib for LPState;

    /**
     * @title LPMeta
     * @dev A struct representing metadata information for an LP (Liquidity Provider) in the Chromatic Protocol.
     * @param lpName The name associated with the LP.
     * @param tag A tag or identifier for the LP.
     */
    struct LPMeta {
        string lpName;
        string tag;
    }

    /**
     * @title ConfigParam
     * @dev A struct representing the configuration parameters for an LP (Liquidity Provider) in the Chromatic Protocol.
     * @param market An instance of the IChromaticMarket interface, representing the market associated with the LP.
     * @param utilizationTargetBPS Target utilization rate for the LP, represented in basis points (BPS).
     * @param rebalanceBPS Rebalance basis points, indicating the percentage change that triggers a rebalance.
     * @param rebalanceCheckingInterval Time interval (in seconds) between checks for rebalance conditions.
     * @param automationFeeReserved Amount reserved as automation fee, used for automated operations within the LP.
     * @param minHoldingValueToRebalance The minimum holding value required to trigger rebalance.
     */
    struct ConfigParam {
        IChromaticMarket market;
        uint16 utilizationTargetBPS;
        uint16 rebalanceBPS;
        uint256 rebalanceCheckingInterval;
        uint256 automationFeeReserved;
        uint256 minHoldingValueToRebalance;
    }

    //slither-disable-next-line unused-state
    LPMeta internal s_meta;
    //slither-disable-next-line uninitialized-state
    LPConfig internal s_config;
    LPState internal s_state;

    constructor() ERC20("", "") {}

    /**
     * @inheritdoc ERC20
     */
    function decimals() public view virtual override returns (uint8) {
        return s_state.settlementToken().decimals();
    }
}
