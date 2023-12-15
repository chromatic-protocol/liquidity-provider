// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title The IChromaticLPEvents interface declares events that developers can utilize to track and react to different actions within the Chromatic Protocol. These events offer transparency and can be subscribed to for monitoring the state changes of the liquidity providers.
 */
interface IChromaticLPEvents {
    /**
     * @notice Emitted when addLiquidity is performed.
     * @param receiptId Unique identifier for the liquidity addition receipt.
     * @param provider Address of the liquidity provider.
     * @param recipient Address of the recipient.
     * @param oracleVersion  Version of the oracle used.
     * @param amount Amount of liquidity added in the settlement token.
     */
    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    /**
     * @notice Emitted when addLiquidity is settled.
     * @param receiptId Unique identifier for the liquidity addition receipt.
     * @param provider Address of the liquidity provider.
     * @param recipient Address of the recipient.
     * @param settlementAdded Settlement added to the liquidity
     * @param lpTokenAmount Amount of LP tokens issued.
     * @param keeperFee Fee paid to the keeper.
     */
    event AddLiquiditySettled(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 settlementAdded,
        uint256 lpTokenAmount,
        uint256 keeperFee
    );

    /**
     * @notice Emitted when removeLiquidity is performed.
     * @param receiptId Unique identifier for the liquidity removal receipt.
     * @param provider Address of the liquidity provider.
     * @param recipient Address of the recipient.
     * @param oracleVersion Version of the oracle used.
     * @param lpTokenAmount Amount of LP tokens to be removed.
     */
    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    /**
     * @notice Emitted when removeLiquidity is settled.
     * @param receiptId Unique identifier for the settled liquidity removal receipt.
     * @param provider Address of the liquidity provider.
     * @param recipient Address of the recipient.
     * @param burningAmount Amount of LP tokens burned.
     * @param withdrawnSettlementAmount Withdrawn settlement amount.
     * @param refundedAmount Amount refunded to the provider.
     * @param keeperFee Fee paid to the keeper.
     */
    event RemoveLiquiditySettled(
        uint256 indexed receiptId,
        address indexed provider,
        address indexed recipient,
        uint256 burningAmount,
        uint256 withdrawnSettlementAmount,
        uint256 refundedAmount,
        uint256 keeperFee
    );

    /**
     * @notice Emitted when rebalance of adding liquidity is performed.
     * @param receiptId Unique identifier for the rebalance liquidity addition receipt.
     * @param oracleVersion Version of the oracle used.
     * @param amount Amount of liquidity added during rebalance.
     * @param currentUtility Current utility of the liquidity provider.
     */
    event RebalanceAddLiquidity(
        uint256 indexed receiptId,
        uint256 oracleVersion,
        uint256 amount,
        uint256 currentUtility
    );

    /**
     * @notice Emitted when rebalance of removing liquidity is performed.
     * @param receiptId Unique identifier for the rebalance liquidity removal receipt.
     * @param oracleVersion Version of the oracle used.
     * @param currentUtility Current utility of the liquidity pool.
     */
    event RebalanceRemoveLiquidity(
        uint256 indexed receiptId,
        uint256 oracleVersion,
        uint256 currentUtility
    );

    /**
     * @notice Emitted when rebalancing is settled.
     * @param receiptId Unique identifier for the settled rebalance receipt.
     * @param keeperFee Fee paid to the keeper.
     */
    event RebalanceSettled(uint256 indexed receiptId, uint256 keeperFee);

    /**
     * @notice Emitted when the AutomateLP address is set.
     * @param automate The address of the AutomateLP contract.
     */
    event SetAutomateLP(address automate);
}
