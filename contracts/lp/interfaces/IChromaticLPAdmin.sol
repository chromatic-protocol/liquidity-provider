// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title The IChromaticLPAdmin interface is designed to facilitate the administration of liquidity provider within the Chromatic Protocol.
 * @author
 * @notice
 */
interface IChromaticLPAdmin {
    /**
     * @dev Initiates the creation of a rebalance task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     */
    function createRebalanceTask() external;

    /**
     * @dev Cancels the currently active rebalance task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     */
    function cancelRebalanceTask() external;

    /**
     * @dev Cancels the settle task in the liquidity provider.
     * This is allowed for the owner of LP contract to call
     * @param  receiptId The receipt ID associated with the settle execution.
     */
    function cancelSettleTask(uint256 receiptId) external;

    /**
     * @dev Additional data to be used in the rebalance process.
     * @param _automationFeeReserved The new value for the reserved automation fee.
     */
    function setAutomationFeeReserved(uint256 _automationFeeReserved) external;

    /**
     * @dev Additional data to be used in the rebalance process.
     * @param _minHoldingValueToRebalance The new value for the required minimum amount to trigger rebalance.
     */
    function setMinHoldingValueToRebalance(uint256 _minHoldingValueToRebalance) external;

    /**
     * @dev Retrieves the current suspension mode of the LP.
     * @return The current suspension mode.
     */
    function suspendMode() external view returns (uint8);

    /**
     * @dev Sets the suspension mode for the LP.
     * @param mode The new suspension mode to be set.
     */
    function setSuspendMode(uint8 mode) external;

    /**
     * @dev Sets the private mode for the LP.
     * @param isPrivate The new private mode status.
     */
    function setPrivateMode(bool isPrivate) external;

    /**
     * @dev Retrieves the current private mode status of the LP.
     * @return true if private mode is enabled, false otherwise.
     */
    function privateMode() external view returns (bool);

    /**
     * @dev Registers a provider as allowed for addLiquidity during private mode.
     * @param provider The address of the provider to register.
     */
    function registerProvider(address provider) external;

    /**
     * @dev Unregisters a provider as allowed for addLiquidity during private mode.
     * @param provider The address of the provider to unregister.
     */
    function unregisterProvider(address provider) external;

    /**
     * @dev Retrieves the list of allowed providers for addLiquidity during private mode.
     * @return An array containing the addresses of allowed providers.
     */
    function allowedProviders() external view returns (address[] memory);

    /**
     * @dev Checks if a provider is allowed for addLiquidity during private mode.
     * @param provider The address of the provider to check.
     * @return true if the provider is allowed, false otherwise.
     */
    function isAllowedProvider(address provider) external view returns (bool);

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @dev Retrieves the address of the current owner.
     * @return The address of the owner.
     */
    function owner() external view returns (address);
}
