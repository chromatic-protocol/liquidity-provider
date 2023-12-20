// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LPState} from "~/lp/libraries/LPState.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {LPStateViewLib} from "~/lp/libraries/LPStateView.sol";
import {Errors} from "~/lp/libraries/Errors.sol";

/**
 * @title LPStateValueLib
 * @dev A library providing value-related functions for LPState in the Chromatic Protocol.
 */
library LPStateValueLib {
    using LPStateValueLib for LPState;
    using LPStateViewLib for LPState;

    using Math for uint256;

    /**
     * @dev Retrieves the current utility and total value of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return currentUtility The current utility percentage (basis points).
     * @return _totalValue The total value of the LPState.
     */
    function utilizationInfo(
        LPState storage s_state
    ) internal view returns (uint16 currentUtility, uint256 _totalValue) {
        ValueInfo memory value = s_state.valueInfo();
        _totalValue = value.total;
        if (_totalValue == 0) {
            currentUtility = 0;
        } else {
            currentUtility = uint16(uint256(value.total - value.holding).mulDiv(BPS, value.total));
        }
    }

    /**
     * @dev Retrieves the total value of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The total value of the LPState.
     */
    function totalValue(LPState storage s_state) internal view returns (uint256 value) {
        value = (s_state.holdingValue() + s_state.pendingValue() + s_state.totalClbValue());
    }

    /**
     * @dev Retrieves the value information of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return info The ValueInfo struct containing total, holding, pending, holdingClb, and pendingClb values.
     */
    function valueInfo(LPState storage s_state) internal view returns (ValueInfo memory info) {
        info = ValueInfo({
            total: 0,
            holding: s_state.holdingValue(),
            pending: s_state.pendingValue(),
            holdingClb: s_state.holdingClbValue(),
            pendingClb: s_state.pendingClbValue()
        });
        info.total = info.holding + info.pending + info.holdingClb + info.pendingClb;
    }

    /**
     * @dev Retrieves the holding value (balance of the settlement token) of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The holding value of the LPState.
     */
    function holdingValue(LPState storage s_state) internal view returns (uint256) {
        return s_state.settlementToken().balanceOf(address(this));
    }

    /**
     * @dev Retrieves the pending value (amount pending for addition to the liquidity pool) of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The pending value of the LPState.
     */
    function pendingValue(LPState storage s_state) internal view returns (uint256) {
        return s_state.pendingAddAmount;
    }

    /**
     * @dev Retrieves the holding CLB (Cumulative Loyalty Bonus) value of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The holding CLB value of the LPState.
     */
    function holdingClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.clbTotalSupplies();
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = s_state.clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i];
            value += (clbAmount == 0 || clbSupplies[i] == 0 || binValues[i] == 0)
                ? 0
                : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves the pending CLB (Cumulative Loyalty Bonus) value of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The pending CLB value of the LPState.
     */
    function pendingClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.clbTotalSupplies();
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += (clbAmount == 0 || clbSupplies[i] == 0 || binValues[i] == 0)
                ? 0
                : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves the total CLB (Cumulative Loyalty Bonus) value of the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return value The total CLB value of the LPState.
     */
    function totalClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.clbTotalSupplies();
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = s_state.clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i] +
                s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += (clbAmount == 0 || clbSupplies[i] == 0 || binValues[i] == 0)
                ? 0
                : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves the CLB token balances associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return _clbTokenBalances The array of CLB token balances.
     */
    function clbTokenBalances(
        LPState storage s_state
    ) internal view returns (uint256[] memory _clbTokenBalances) {
        address[] memory _owners = new address[](s_state.binCount());
        for (uint256 i; i < s_state.binCount(); ) {
            _owners[i] = address(this);
            unchecked {
                ++i;
            }
        }
        _clbTokenBalances = s_state.clbToken().balanceOfBatch(_owners, s_state.clbTokenIds);
    }

    /**
     * @dev Retrieves the CLB token balances associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return _clbTokenValues The array of CLB token values.
     */
    function clbTokenValues(
        LPState storage s_state
    ) internal view returns (uint256[] memory _clbTokenValues) {
        _clbTokenValues = new uint256[](s_state.binCount());
        uint256[] memory clbSupplies = s_state.clbTotalSupplies();
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = s_state.clbTokenBalances();
        for (uint256 i; i < s_state.binCount(); ) {
            _clbTokenValues[i] = clbSupplies[i] == 0
                ? 0
                : binValues[i].mulDiv(clbTokenAmounts[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves the total supplies of CLB tokens associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return clbTokenTotalSupplies The array of total supplies of CLB tokens.
     */
    function clbTotalSupplies(
        LPState storage s_state
    ) internal view returns (uint256[] memory clbTokenTotalSupplies) {
        clbTokenTotalSupplies = s_state.clbToken().totalSupplyBatch(s_state.clbTokenIds);
    }

    /**
     * @dev Retrieves the pending CLB balances associated with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return pendingBalances The array of pending CLB balances.
     */
    function pendingRemoveClbBalances(
        LPState storage s_state
    ) internal view returns (uint256[] memory pendingBalances) {
        pendingBalances = new uint256[](s_state.binCount());
        for (uint256 i; i < s_state.binCount(); ) {
            pendingBalances[i] = s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves information about the target of liquidity with the LPState.
     * @param s_state The storage state of the liquidity provider.
     * @return An integer representing long (1), short (-1), or both side(0).
     */
    function longShortInfo(LPState storage s_state) internal view returns (int8) {
        //slither-disable-next-line uninitialized-local
        int8 long; // = 0
        //slither-disable-next-line uninitialized-local
        int8 short; // = 0
        for (uint256 i; i < s_state.binCount(); ) {
            if (s_state.feeRates[i] > 0) long = 1;
            else if (s_state.feeRates[i] < 0) short = -1;
            unchecked {
                ++i;
            }
        }
        return long + short;
    }
}
