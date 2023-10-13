// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLPEvents {
    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(
        uint256 indexed receiptId,
        uint256 settlementAdded,
        uint256 lpTokenAmount
    );

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(
        uint256 indexed receiptId,
        uint256 burningAmount,
        uint256 witdrawnSettlementAmount,
        uint256 refundedAmount
    );

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);
}