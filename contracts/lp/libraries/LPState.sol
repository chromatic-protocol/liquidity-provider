// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title LPState
 * @dev A struct representing the state of a liquidity provider in the Chromatic Protocol.
 * @param market Instance of IChromaticMarket representing the associated market.
 * @param feeRates Array of fee rates for different actions within the liquidity pool.
 * @param distributionRates Mapping of fee rates to distribution rates for each action.
 * @param totalRate Total rate representing the sum of fee rates.
 * @param clbTokenIds Array of CLB token IDs associated with the liquidity pool.
 * @param receipts Mapping of receipt IDs to ChromaticLPReceipts.
 * @param lpReceiptMap Mapping of receipt IDs to lpReceiptIds.
 * @param providerReceiptIds Mapping of provider addresses to receipt IDs using EnumerableSet.
 * @param pendingAddLp Amount pending for addition to the liquidity pool in settlement token.
 * @param pendingAddMarket Amount pending for addition to the market in settlement token.
 * @param pendingRemoveClbAmounts Mapping of fee rates to pending amounts for CLB removal.
 * @param receiptId Current receipt ID for generating new receipts.
 */
struct LPState {
    IChromaticMarket market;
    int16[] feeRates;
    mapping(int16 => uint16) distributionRates;
    uint256 totalRate;
    uint256[] clbTokenIds;
    mapping(uint256 => ChromaticLPReceipt) receipts; // receiptId => receipt
    mapping(uint256 => uint256[]) lpReceiptMap; // receiptId => lpReceiptIds
    mapping(address => EnumerableSet.UintSet) providerReceiptIds; // provider => receiptIds
    uint256 pendingAddLp; // in settlement token
    uint256 pendingAddMarket; // in settlement token
    mapping(int16 => uint256) pendingRemoveClbAmounts; // feeRate => pending remove
    uint256 receiptId;
}

uint256 constant REBALANCE_ID = 1;
