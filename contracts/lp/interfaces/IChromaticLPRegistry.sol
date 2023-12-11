// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";

/**
 * @title IChromaticLPRegistry
 * @dev An interface for the Chromatic LP (Liquidity Provider) Registry, responsible for registering and unregistering LPs.
 */
interface IChromaticLPRegistry {
    /**
     * @notice Emitted when a Chromatic LP is successfully registered.
     * @param market The address of the associated market.
     * @param lp The address of the registered Chromatic LP.
     */
    event ChromaticLPRegistered(address indexed market, address indexed lp);

    /**
     * @notice Emitted when a Chromatic LP is successfully unregistered.
     * @param market The address of the associated market.
     * @param lp The address of the unregistered Chromatic LP.
     */
    event ChromaticLPUnregistered(address indexed market, address indexed lp);

    /**
     * @notice Error thrown when a function is called by an unauthorized user.
     */
    error OnlyAccessableByOwner();

    /**
     * @notice Error thrown when attempting to register an LP that is already registered.
     */
    error AlreadyRegistered();

    /**
     * @notice Error thrown when attempting to unregister an LP that is not registered.
     */
    error NotRegistered();

    /**
     * @notice Registers a new Chromatic LP.
     * @param lp The address of the Chromatic LP contract to be registered.
     */
    function register(IChromaticLP lp) external;

    /**
     * @notice Unregisters an existing Chromatic LP.
     * @param lp The address of the Chromatic LP contract to be unregistered.
     */
    function unregister(IChromaticLP lp) external;

    /**
     * @notice Retrieves the list of all registered Chromatic LP addresses.
     * @return lpAddresses An array of Chromatic LP addresses.
     */
    function lpList() external view returns (address[] memory lpAddresses);

    /**
     * @notice Retrieves the list of Chromatic LP addresses associated with a specific market.
     * @param market The address of the market for which LPs are to be retrieved.
     * @return lpAddresses An array of Chromatic LP addresses associated with the specified market.
     */
    function lpListByMarket(address market) external view returns (address[] memory lpAddresses);

    /**
     * @notice Retrieves the list of Chromatic LP addresses associated with a specific settlement token.
     * @param token The address of the settlement token for which LPs are to be retrieved.
     * @return lpAddresses An array of Chromatic LP addresses associated with the specified settlement token.
     */
    function lpListBySettlementToken(
        address token
    ) external view returns (address[] memory lpAddresses);

}
