// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol";

contract ChromaticVaultMock is ChromaticVault {
    constructor(
        IChromaticMarketFactory _factory,
        IVaultEarningDistributor _earningDistributor
    ) ChromaticVault(_factory, _earningDistributor) {}

    function setPendingMarketEarnings(address market, uint256 earning) external {
        pendingMarketEarnings[market] = earning;
    }

    function createMakerEarningDistributionTask(address token) external override {
        // dummy
    }

    function createMarketEarningDistributionTask(address market) external override {
        // dummy
    }
}
