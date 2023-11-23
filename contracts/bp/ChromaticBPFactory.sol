// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BPConfig, AutomateParam} from "~/bp/libraries/BPConfig.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";

/**
 * @title ChromaticBPFactory
 * @dev A contract to create and manage instances of ChromaticBP.
 */
contract ChromaticBPFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    error OnlyAccessableByOwner();
    event ChromaticBPCreated(address indexed lp, address bp);

    mapping(address => EnumerableSet.AddressSet) private _lpToBpSet;
    EnumerableSet.AddressSet private _bpSet;

    /**
     * @dev Creates a new ChromaticBPFactory contract.
     */
    constructor() {}

    /**
     * @dev Checks if the caller is the owner of the contract.
     */
    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    /**
     * @dev Creates a new ChromaticBP instance.
     * @param config The configuration parameters for the ChromaticBP.
     * @param automateParam The automation parameters for the ChromaticBP.
     */
    function createBP(
        BPConfig memory config,
        AutomateParam memory automateParam
    ) external onlyOwner {
        ChromaticBP bp = new ChromaticBP(config, automateParam);

        emit ChromaticBPCreated(address(config.lp), address(bp));

        //slither-disable-next-line unused-return
        _lpToBpSet[address(config.lp)].add(address(bp));
        //slither-disable-next-line unused-return
        _bpSet.add(address(bp));
    }

    /**
     * @dev Retrieves the list of ChromaticBP addresses associated with a specific ChromaticLP.
     * @param lp The address of the ChromaticLP.
     * @return bpAddresses An array of ChromaticBP addresses.
     */
    function bpListByLP(address lp) external view returns (address[] memory bpAddresses) {
        return _lpToBpSet[lp].values();
    }

    /**
     * @dev Retrieves the list of all ChromaticBP addresses.
     * @return bpAddresses An array of ChromaticBP addresses.
     */
    function bpList() external view returns (address[] memory bpAddresses) {
        return _bpSet.values();
    }
}
