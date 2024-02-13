// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev The ChromaticLPAction enum represents the types of LP actions that can be performed.
 */
enum ChromaticLPAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

/**
 * @title ChromaticLPReceipt
 * @dev A struct representing a receipt of a liquidity-related action in the Chromatic Protocol.
 * @param id Unique identifier of the receipt.
 * @param provider Address of the liquidity provider initiating the action.
 * @param recipient Address of the recipient for the liquidity or assets.
 * @param oracleVersion Version of the oracle used for the action.
 * @param amount Amount associated with the liquidity action.
 * @param pendingLiquidity Pending liquidity awaiting settlement.
 * @param action ChromaticLPAction indicating the type of liquidity-related action.
 * @param needSettle bool flag indicating whether settlement is needed
 */
struct ChromaticLPReceipt {
    uint256 id;
    address provider;
    address recipient;
    uint256 oracleVersion;
    uint256 amount;
    uint256 pendingLiquidity;
    ChromaticLPAction action;
    bool needSettle;
}
