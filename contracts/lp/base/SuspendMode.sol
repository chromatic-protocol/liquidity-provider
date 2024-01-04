// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";

/**
 * @title SuspendModeType
 * @dev An enumeration representing the suspension mode of the contract.
 * @param NOT_SUSPENDED The contract is not suspended.
 * @param ADD_SUSPENDED Adding liquidity is suspended.
 * @param ALL_SUSPENDED Both adding and removing liquidity are suspended.
 */
enum SuspendModeType {
    NOT_SUSPENDED,
    ADD_SUSPENDED,
    ALL_SUSPENDED
}

/**
 * @title SuspendMode
 * @dev A contract providing suspension functionality for adding and removing liquidity in Chromatic LP.
 */
abstract contract SuspendMode is IChromaticLPEvents, IChromaticLPErrors {
    // The current suspension mode
    SuspendModeType _mode;

    /**
     * @dev Modifier to check if adding liquidity is enabled.
     */
    modifier addLiquidityEnabled() virtual {
        if (!_checkAddLiquidityEnabled()) revert AddLiquiditySuspended();
        _;
    }

    /**
     * @dev Modifier to check if removing liquidity is enabled.
     */
    modifier removeLiquidityEnabled() virtual {
        if (!_checkRemoveLiquidityEnabled()) revert RemoveLiquiditySuspended();
        _;
    }

    /**
     * @dev Internal function to set the suspension mode.
     * @param mode The new suspension mode.
     */
    function _setSuspendMode(uint8 mode) internal {
        emit SetSuspendMode(uint8(mode));
        _mode = SuspendModeType(mode);
    }

    /**
     * @dev Internal function to check if adding liquidity is enabled based on the current suspension mode.
     * @return Whether adding liquidity is enabled.
     */
    function _checkAddLiquidityEnabled() internal view returns (bool) {
        return _mode < SuspendModeType.ADD_SUSPENDED;
    }

    /**
     * @dev Internal function to check if removing liquidity is enabled based on the current suspension mode.
     * @return Whether removing liquidity is enabled.
     */
    function _checkRemoveLiquidityEnabled() internal view returns (bool) {
        return _mode < SuspendModeType.ALL_SUSPENDED;
    }

    /**
     * @dev Internal function to retrieve the current suspension mode.
     * @return The current suspension mode.
     */
    function _suspendMode() internal view returns (uint8) {
        return uint8(_mode);
    }
}
