// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";

import {AutomateBP} from "~/automation/mate2/AutomateBP.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";

import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticBPFactory} from "~/bp/ChromaticBPFactory.sol";
import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";

import {IChromaticBPEvents} from "~/bp/interfaces/IChromaticBPEvents.sol";
import {IChromaticBPErrors} from "~/bp/interfaces/IChromaticBPErrors.sol";

import {LPHelper} from "../lp/LPHelper.sol";

contract BPHelper is LPHelper, IChromaticBPEvents, IChromaticBPErrors {
    ChromaticLP lp;

    AutomateBP automateBP;
    ChromaticBP bp;
    ChromaticBPFactory bpFactory;
    BPConfig bpConfig;
    address dao;

    function setUp() public virtual override {
        super.setUp();
        lp = deployLP(
            ChromaticLPStorageCore.ConfigParam({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 500,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: 1 ether,
                minHoldingValueToRebalance: 2 ether
            })
        );

        automateBP = new AutomateBP(automate);
        dao = factory.dao();

        bpFactory = new ChromaticBPFactory(IChromaticMarketFactory(factory), automateBP);
    }

    function deposit(address who, uint256 amount) internal {
        IERC20 token = bp.settlementToken();
        deal(address(token), who, amount);

        vm.startPrank(who);

        token.approve(address(bp), amount);

        vm.expectEmit(true, true, false, true, address(bp));
        emit BPDeposited(who, amount);
        bp.deposit(amount);

        vm.stopPrank();
    }

    function deposit(address who, uint256 amount, bytes4 data) internal {
        IERC20 token = IERC20(bp.settlementToken());
        deal(lp.settlementToken(), who, amount);

        vm.startPrank(who);

        token.approve(address(bp), amount);
        vm.expectRevert(data);
        bp.deposit(amount);
        token.approve(address(bp), 0);

        vm.stopPrank();
    }

    // function depositRevert(address who, uint256 amount, bytes calldata data) {

    // }
}
