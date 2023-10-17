// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct LPState {
    IChromaticMarket market;
    int16[] feeRates;
    mapping(int16 => uint16) distributionRates;
    uint256[] clbTokenIds;
    mapping(uint256 => ChromaticLPReceipt) receipts; // receiptId => receipt
    mapping(uint256 => EnumerableSet.UintSet) lpReceiptMap; // receiptId => lpReceiptIds
    mapping(address => EnumerableSet.UintSet) providerReceiptIds; // provider => receiptIds
    uint256 pendingAddAmount; // in settlement token
    mapping(int16 => uint256) pendingRemoveClbAmounts; // feeRate => pending remove
    uint256 receiptId;
}
