// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";

/**
 * @title Privatable
 * @dev Abstract contract for managing the private mode and allowed providers in the Chromatic Protocol.
 */
abstract contract Privatable is IChromaticLPEvents, IChromaticLPErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    bool private _isPrivateMode;

    EnumerableSet.AddressSet private _addLiquidityAllowed;

    /**
     * @dev Modifier that allows only allowed providers to perform certain actions during private mode.
     * @param provider The address of the provider attempting to perform the action.
     */
    modifier onlyAllowedProvider(address provider) {
        if (_isPrivateMode && _containsAllowed(provider)) revert AddLiquidityNotAllowed();
        _;
    }

    /**
     * @dev Internal function to register a provider as allowed for addLiquidity during private mode.
     * @param provider The address of the provider to register.
     */
    function _registerProvider(address provider) internal {
        //slither-disable-next-line unused-return
        _addLiquidityAllowed.add(provider);
    }

    /**
     * @dev Internal function to unregister a provider as allowed for addLiquidity during private mode.
     * @param provider The address of the provider to unregister.
     */
    function _unregisterProvider(address provider) internal {
        //slither-disable-next-line unused-return
        _addLiquidityAllowed.remove(provider);
    }

    /**
     * @dev Internal function to get the list of allowed providers for addLiquidity during private mode.
     * @return An array containing the addresses of allowed providers.
     */
    function _allowedProviders() internal view returns (address[] memory) {
        return _addLiquidityAllowed.values();
    }

    /**
     * @dev Internal function to check if a provider is allowed for addLiquidity during private mode.
     * @param provider The address of the provider to check.
     * @return true if the provider is allowed, false otherwise.
     */
    function _containsAllowed(address provider) internal view returns (bool) {
        return _addLiquidityAllowed.contains(provider);
    }

    /**
     * @dev Internal function to set the private mode status.
     * @param isPrivate The new private mode status.
     */
    function _setPrivateMode(bool isPrivate) internal {
        if (_isPrivateMode != isPrivate) {
            emit SetPrivateMode(isPrivate);
            _isPrivateMode = isPrivate;
        }
    }

    /**
     * @dev Internal function to get the current private mode status.
     * @return true if private mode is enabled, false otherwise.
     */
    function _privateMode() internal view returns (bool) {
        return _isPrivateMode;
    }
}
