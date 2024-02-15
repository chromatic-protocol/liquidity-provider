// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseSetup} from "../BaseSetup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AutomateBP} from "~/automation/mate2/AutomateBP.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";
import {AutomateLP} from "~/automation/mate2/AutomateLP.sol";
import {ChromaticBPFactory} from "~/bp/ChromaticBPFactory.sol";
import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {IChromaticBPEvents} from "~/bp/interfaces/IChromaticBPEvents.sol";
import {LPHelper} from "../lp/LPHelper.sol";

import "forge-std/console.sol";

contract ChromaticBPTest is LPHelper, IChromaticBPEvents {
    using Math for uint256;

    ChromaticLP lp;

    AutomateBP automateBP;
    ChromaticBP bp;
    ChromaticBPFactory bpFactory;
    BPConfig bpConfig;
    address dao;

    function setUp() public override {
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

        bpConfig = BPConfig({
            lp: lp,
            totalReward: 100 ether,
            minRaisingTarget: 500 ether,
            maxRaisingTarget: 600 ether,
            startTimeOfWarmup: (block.timestamp + 60),
            maxDurationOfWarmup: 1 days,
            durationOfLockup: 1 days,
            minDeposit: 3 ether
        });

        bpFactory.createBP(bpConfig);
        bp = ChromaticBP(bpFactory.bpListByLP(address(lp))[0]);
    }

    function testDeposit() public {
        address user1 = makeAddr("user1");
        deal(address(ctst), user1, 1000 ether);

        vm.startPrank(user1, user1);

        vm.expectRevert(abi.encodeWithSignature("NotWarmupPeriod()"));
        uint256 amount = bpConfig.minRaisingTarget / 2;
        bp.deposit(amount);

        vm.warp(bp.startTimeOfWarmup());

        vm.expectRevert("ERC20: insufficient allowance");
        bp.deposit(amount);

        ctst.approve(address(bp), amount);
        vm.expectEmit(true, true, false, true);
        emit BPDeposited(user1, amount);
        bp.deposit(amount);

        ctst.approve(address(bp), amount);
        vm.expectEmit(true, true, false, true);
        emit BPDeposited(user1, amount);
        bp.deposit(amount);
        assertEq(bp.isDepositable(), true);

        amount = bp.maxRaisingTarget() - bp.totalRaised();
        ctst.approve(address(bp), amount);
        vm.expectEmit(true, true, false, true);
        emit BPDeposited(user1, amount);
        vm.expectEmit(true, false, false, true);
        emit BPFullyRaised(bp.maxRaisingTarget());
        bp.deposit(amount);

        assertEq(bp.isDepositable(), false);

        amount = 100 ether;
        ctst.approve(address(bp), amount);
        vm.expectRevert(abi.encodeWithSignature("NotWarmupPeriod()"));
        bp.deposit(amount);

        assertEq(bp.endTimeOfWarmup(), block.timestamp);
        assertEq(bp.endTimeOfLockup(), block.timestamp + bpConfig.durationOfLockup);
        assertEq(bp.isDepositable(), false);
        vm.stopPrank();
    }
}
