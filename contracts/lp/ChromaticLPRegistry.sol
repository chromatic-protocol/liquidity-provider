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

    event ChromaticLPRegistered(address indexed market, address indexed lp);
    event ChromaticLPUnregistered(address indexed market, address indexed lp);

    error OnlyAccessableByOwner();

    constructor(IChromaticMarketFactory _factory) Ownable() {
        factory = _factory;
    }

    function _checkOwner() internal view override {
        if (owner() != _msgSender()) revert OnlyAccessableByOwner();
    }

    function register(IChromaticLP lp) external onlyOwner {
        address market = lp.market();
        _lpsByMarket[market].add(address(lp));

        _lpsBySettlementToken[lp.settlementToken()].add(address(lp));

        emit ChromaticLPRegistered(market, address(lp));
    }

    function unregister(IChromaticLP lp) external onlyOwner {
        address market = lp.market();
        _lpsByMarket[market].remove(address(lp));

        _lpsBySettlementToken[lp.settlementToken()].remove(address(lp));

        emit ChromaticLPUnregistered(market, address(lp));
    }

    function lpListByMarket(address market) external view returns (address[] memory) {
        return _lpsByMarket[market].values();
    }

    function lpListBySettlementToken(address token) external view returns (address[] memory) {
        return _lpsBySettlementToken[token].values();
    }
}
