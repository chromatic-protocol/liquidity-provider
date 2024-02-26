// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title The IChromaticLPErrors interface houses a set of custom errors that developers may encounter when interacting with liquidity providers for the Chromatic Protocol. These errors are designed to provide meaningful feedback about specific issues that may arise during the execution of smart contracts.
 */
interface IChromaticLPErrors {
    /**
     * @dev The invalid target basis points.
     */
    error InvalidUtilizationTarget(uint16 targetBPS);

    /**
     * @dev Signifies that an invalid rebalance basis points value has been encountered.
     */
    error InvalidRebalanceBPS();

    /**
     * @dev Signifies that an invalid minHoldingValueToRebalance value has been encountered.
     */
    error InvalidMinHoldingValueToRebalance();

    /**
     * @dev Thrown when the lengths of the fee array and distribution array do not match.
     * @param feeLength The length of the fee array.
     * @param distributionLength The length of the distribution array.
     */
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);

    /**
     * @dev Indicates that the operation is not applicable to the market.
     */
    error NotMarket();

    /**
     * @dev Denotes that the function can only be called within a batch call.
     */
    error OnlyBatchCall();

    /**
     * @dev Thrown when an unknown liquidity provider action is encountered
     */
    error UnknownLPAction();

    /**
     * @dev Signifies that the caller is not the owner of the contract
     */
    error NotOwner();

    /**
     * @dev Thrown when the keeper is not called.
     */
    error NotKeeperCalled();

    /**
     * @dev Signifies that the function is only accessible by the owner
     */
    error OnlyAccessableByOwner();

    /**
     * @dev Thrown when an automation call is not made
     */
    error NotAutomationCalled();

    /**
     * @dev Indicates that the functionality is not implemented in the logic contract.
     */
    error NotImplementedInLogicContract();

    /**
     * @dev Throws an error indicating that the amount to add liquidity is too small.
     */
    error TooSmallAmountToAddLiquidity();

    /**
     * @dev Error indicating that adding liquidity is suspended.
     */
    error AddLiquiditySuspended();

    /**
     * @dev Error indicating that removing liquidity is suspended.
     */
    error RemoveLiquiditySuspended();

    /**
     * @dev Error indicating that adding liquidity is not allowed during private mode.
     */
    error AddLiquidityNotAllowed();

    /**
     * @dev Error indicating an attempt to use a zero address.
     */
    error ZeroAddressError();

    /**
     * @dev Error indicating invalid receitp ID.
     */
    error InvalidReceiptId();

    /**
     * @dev Error indicating an invalid oracle version.
     */
    error OracleVersionError();

    /**
     * @dev Error indicating that the action has already been settled.
     */
    error AlreadySettled();

    /**
     * @dev Error indicating that removing zero amount of liquidity is invalid.
     */
    error ZeroRemoveLiquidityError();

}
