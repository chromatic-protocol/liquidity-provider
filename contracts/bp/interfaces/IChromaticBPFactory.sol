// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {IAutomateBP} from "./IAutomateBP.sol";

/**
 * @title IChromaticBPFactory
 * @dev Interface for the Chromatic Boosting Pool (BP) Factory, responsible for creating and managing Chromatic BPs.
 */
interface IChromaticBPFactory {
    /**
     * @dev Emitted when only the owner is allowed to access the function.
     */
    error OnlyAccessableByOwner();

    /**
     * @dev Emitted when a Chromatic BP is successfully created.
     * @param lp The address of the associated Liquidity Provider (LP).
     * @param bp The address of the created Chromatic BP.
     */
    event ChromaticBPCreated(address indexed lp, address bp);

    /**
     * @dev Emitted when the automate contract for Chromatic BPs is set.
     * @param automateBP The address of the set automate contract for Chromatic BPs.
     */
    event SetAutomateBP(address automateBP);

    /**
     * @dev Creates a new Chromatic BP with the provided configuration.
     * @param config The configuration parameters for the new Chromatic BP.
     */
    function createBP(BPConfig memory config) external;

    /**
     * @dev Retrieves the list of Chromatic BPs associated with a specific LP.
     * @param lp The address of the Liquidity Provider (LP).
     * @return bpAddresses The array of Chromatic BP addresses associated with the specified LP.
     */
    function bpListByLP(address lp) external view returns (address[] memory bpAddresses);

    /**
     * @dev Retrieves the list of all Chromatic BPs created by the factory.
     * @return bpAddresses The array of all Chromatic BP addresses.
     */
    function bpList() external view returns (address[] memory bpAddresses);

    /**
     * @dev Sets the automate contract for Chromatic BPs.
     * @param automate The address of the automate contract for Chromatic BPs.
     */
    function setAutomateBP(IAutomateBP automate) external;

    /**
     * @dev Retrieves the automate contract currently set for Chromatic BPs.
     * @return automate The address of the automate contract for Chromatic BPs.
     */
    function getAutomateBP() external view returns (IAutomateBP automate);
}
