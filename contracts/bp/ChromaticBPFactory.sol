// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";
import {IChromaticBPFactory} from "~/bp/interfaces/IChromaticBPFactory.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";

/**
 * @title ChromaticBPFactory
 * @dev A contract to create and manage instances of ChromaticBP.
 */
contract ChromaticBPFactory is Ownable, IChromaticBPFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) private _lpToBpSet;
    EnumerableSet.AddressSet private _bpSet;
    IAutomateBP internal _automateBP;

    /**
     * @dev Creates a new ChromaticBPFactory contract.
     */
    constructor(IAutomateBP automate) {
        setAutomateBP(automate);
    }

    /**
     * @dev Checks if the caller is the owner of the contract.
     */
    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    /**
     * @dev Creates a new ChromaticBP instance.
     * @param config The configuration parameters for the ChromaticBP.
     */
    function createBP(BPConfig memory config) external onlyOwner {
        ChromaticBP bp = new ChromaticBP(config, this);

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

    /**
     * @inheritdoc IChromaticBPFactory
     */
    function setAutomateBP(IAutomateBP automate) public override onlyOwner {
        emit SetAutomateBP(address(automate));
        _automateBP = automate;
    }

    /**
     * @inheritdoc IChromaticBPFactory
     */
    function getAutomateBP() external view override returns (IAutomateBP automate) {
        return _automateBP;
    }
}
