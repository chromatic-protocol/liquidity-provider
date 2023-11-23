// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LPBoostingConfig, AutomateParam} from "~/boosting/libraries/LPBoostingConfig.sol";
import {ChromaticLPBoosting} from "~/boosting/ChromaticLPBoosting.sol";

contract ChromaticLPBoostingFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    error OnlyAccessableByOwner();
    event ChromaticLPBoostingCreated(address indexed lp, address boostingAddress);

    mapping(address => EnumerableSet.AddressSet) _lpToBoosting;
    EnumerableSet.AddressSet _boostingAll;

    constructor() {}

    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    function createLPBoosting(
        LPBoostingConfig memory config,
        AutomateParam memory automateParam
    ) external onlyOwner {
        ChromaticLPBoosting newBoosting = new ChromaticLPBoosting(config, automateParam);

        emit ChromaticLPBoostingCreated(address(config.lp), address(newBoosting));

        _lpToBoosting[address(config.lp)].add(address(newBoosting));
        _boostingAll.add(address(newBoosting));
    }

    function boostingsOfLP(address lp) external view returns (address[] memory boostingAddresses) {
        return _lpToBoosting[lp].values();
    }

    function allBoostings() external view returns (address[] memory boostingAddresses) {
        return _boostingAll.values();
    }
}
