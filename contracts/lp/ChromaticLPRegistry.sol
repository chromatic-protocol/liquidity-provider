// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPRegistry} from "~/lp/interfaces/IChromaticLPRegistry.sol";

contract ChromaticLPRegistry is IChromaticLPRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    IChromaticMarketFactory public immutable factory;

    mapping(address => EnumerableSet.AddressSet) _lpsByMarket;
    mapping(address => EnumerableSet.AddressSet) _lpsBySettlementToken;
    EnumerableSet.AddressSet _lpsAll;

    constructor(IChromaticMarketFactory _factory) {
        factory = _factory;
    }

    /**
     * @dev Modifier to restrict access to only the DAO.
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != factory.dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @inheritdoc IChromaticLPRegistry
     */
    function register(IChromaticLP lp) external override onlyDao {
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

    /**
     * @inheritdoc IChromaticLPRegistry
     */
    function unregister(IChromaticLP lp) external override onlyDao {
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

    /**
     * @inheritdoc IChromaticLPRegistry
     */
    function lpList() external view override returns (address[] memory lpAddresses) {
        return _lpsAll.values();
    }

    /**
     * @inheritdoc IChromaticLPRegistry
     */
    function lpListByMarket(address market) external view override returns (address[] memory) {
        return _lpsByMarket[market].values();
    }

    /**
     * @inheritdoc IChromaticLPRegistry
     */
    function lpListBySettlementToken(
        address token
    ) external view override returns (address[] memory) {
        return _lpsBySettlementToken[token].values();
    }

}
