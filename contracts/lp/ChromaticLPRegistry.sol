// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

contract ChromaticLPRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IChromaticMarketFactory public immutable factory;

    mapping(address => EnumerableSet.AddressSet) _lpsByMarket;
    mapping(address => EnumerableSet.AddressSet) _lpsBySettlementToken;
    EnumerableSet.AddressSet _lpsAll;

    event ChromaticLPRegistered(address indexed market, address indexed lp);
    event ChromaticLPUnregistered(address indexed market, address indexed lp);

    error OnlyAccessableByOwner();
    error AlreadyRegistered();
    error NotRegistered();

    constructor(IChromaticMarketFactory _factory) Ownable() {
        factory = _factory;
    }

    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    function register(IChromaticLP lp) external onlyOwner {
        address market = lp.market();

        bool success = _lpsByMarket[market].add(address(lp));
        success = success && _lpsBySettlementToken[lp.settlementToken()].add(address(lp));
        success = success && _lpsAll.add(address(lp));
        if (success) {
            emit ChromaticLPRegistered(market, address(lp));
        } else {
            revert AlreadyRegistered();
        }
    }

    function unregister(IChromaticLP lp) external onlyOwner {
        address market = lp.market();

        bool success = _lpsByMarket[market].remove(address(lp));
        success = success && _lpsBySettlementToken[lp.settlementToken()].remove(address(lp));
        success = success && _lpsAll.remove(address(lp));
        if (success) {
            emit ChromaticLPUnregistered(market, address(lp));
        } else {
            revert NotRegistered();
        }
    }

    function lpList() external view returns (address[] memory lpAddresses) {
        return _lpsAll.values();
    }

    function lpListByMarket(address market) external view returns (address[] memory) {
        return _lpsByMarket[market].values();
    }

    function lpListBySettlementToken(address token) external view returns (address[] memory) {
        return _lpsBySettlementToken[token].values();
    }
}
