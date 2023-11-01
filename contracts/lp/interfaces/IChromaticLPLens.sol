// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLPConfigLens} from "./IChromaticLPConfigLens.sol";

struct ValueInfo {
    uint256 total;
    uint256 holding;
    uint256 pending;
    uint256 holdingClb;
    uint256 pendingClb;
}

/**
 * @title The IChromaticLPLens interface is designed to offer a lens into the financial and operational aspects of the Chromatic Protocol. Developers can use the functions defined in this interface to retrieve information such as utilization, total value, value breakdowns, fee rates, and token balances.
 */
interface IChromaticLPLens is IChromaticLPConfigLens {
    /**
     * @dev The current utilization of the liquidity provider, represented in basis points (BPS)
     */
    function utilization() external view returns (uint16);

    /**
     * @dev The total value of the liquidity provider
     */
    function totalValue() external view returns (uint256);

    /**
     * @dev Retrieves the total value of the liquidity provider, including both holding and pending values.
     * @return info A ValueInfo struct containing total, holding, pending, holdingClb, and pendingClb values.
     */
    function valueInfo() external view returns (ValueInfo memory info);

    /**
     * @dev Retrieves the current holding value of the liquidity pool.
     * @return The current holding value in the liquidity provider.
     */
    function holdingValue() external view returns (uint256);

    /**
     * @dev Retrieves the pending value of the liquidity provider.
     * @return pendingValue The pending value in the liquidity pool.
     */
    function pendingValue() external view returns (uint256);

    /**
     * @dev Retrieves the current holding CLB value in the liquidity provider.
     * @return The current holding CLB value in the liquidity provider.
     */
    function holdingClbValue() external view returns (uint256);

    /**
     * @dev Retrieves the pending CLB value in the liquidity provider.
     * @return The pending CLB value in the liquidity provider.
     */
    function pendingClbValue() external view returns (uint256);

    /**
     * @dev Retrieves the total CLB value in the liquidity provider, combining holding and pending CLB values.
     * @return value The total CLB value in the liquidity provider.
     */
    function totalClbValue() external view returns (uint256 value);

    /**
     * @dev Retrieves the fee rates associated with various actions in the liquidity provider.
     * @return An array of fee rates for different actions within the liquidity pool.
     */
    function feeRates() external view returns (int16[] memory);

    /**
     * @dev Retrieves the token IDs of CLB tokens handled in the liquidity provider
     * @return tokenIds An array of CLB token IDs handled in the liquidity provider.
     */
    function clbTokenIds() external view returns (uint256[] memory tokenIds);

    /**
     * @dev Retrieves the balances of CLB tokens held in the liquidity provider.
     * @return balances An array of CLB token balances held in the liquidity provider.
     */
    function clbTokenBalances() external view returns (uint256[] memory balances);

    /**
     * @dev An array of pending CLB token balances for removal.
     * Retrieves the pending CLB token balances that are pending removal from the liquidity provider.
     */
    function pendingRemoveClbBalances() external view returns (uint256[] memory pendingBalances);
}
