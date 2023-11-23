// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BPConfig, AutomateParam} from "~/bp/libraries/BPConfig.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";

contract ChromaticBPFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    error OnlyAccessableByOwner();
    event ChromaticBPCreated(address indexed lp, address bp);

    mapping(address => EnumerableSet.AddressSet) _lpToBpSet;
    EnumerableSet.AddressSet _bpSet;

    constructor() {}

    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    function createBP(
        BPConfig memory config,
        AutomateParam memory automateParam
    ) external onlyOwner {
        ChromaticBP bp = new ChromaticBP(config, automateParam);

        emit ChromaticBPCreated(address(config.lp), address(bp));

        _lpToBpSet[address(config.lp)].add(address(bp));
        _bpSet.add(address(bp));
    }

    function boostingsOfLP(address lp) external view returns (address[] memory bpAddresses) {
        return _lpToBpSet[lp].values();
    }

    function allBoostings() external view returns (address[] memory bpAddresses) {
        return _bpSet.values();
    }
}
