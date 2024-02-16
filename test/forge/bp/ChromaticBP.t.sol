// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AutomateBP} from "~/automation/mate2/AutomateBP.sol";
import {ChromaticBP} from "~/bp/ChromaticBP.sol";
import {BPStatus} from "~/bp/libraries/BPState.sol";
import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {BPHelper} from "./BPHelper.sol";
import "forge-std/console.sol";

contract ChromaticBPTest is BPHelper {
    function setUp() public override {
        super.setUp();

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

    function testConstructErrors() public {
        BPConfig memory baseConfig = BPConfig({
            lp: lp,
            totalReward: 100 ether,
            minRaisingTarget: 500 ether,
            maxRaisingTarget: 600 ether,
            startTimeOfWarmup: (block.timestamp + 60),
            maxDurationOfWarmup: 1 days,
            durationOfLockup: 1 days,
            minDeposit: 3 ether
        });
        BPConfig memory config = baseConfig;
        uint256 minAdd = lp.estimateMinAddLiquidityAmount();
        console.log("utilization target bps:", lp.utilizationTargetBPS());
        console.log("min add liquidity amount:", minAdd);

        config.minDeposit = minAdd - 1;
        vm.expectRevert(TooSmallMinDeposit.selector);
        bpFactory.createBP(config);
        config.minDeposit = baseConfig.minDeposit;

        config.startTimeOfWarmup = block.timestamp;
        vm.expectRevert(StartTimeError.selector);
        bpFactory.createBP(config);
        config.startTimeOfWarmup = block.timestamp + 60;

        config.maxDurationOfWarmup = 1 days - 1;
        vm.expectRevert(InvalidWarmup.selector);
        bpFactory.createBP(config);
        config.maxDurationOfWarmup = baseConfig.maxDurationOfWarmup;
    }

    // function testRoll() public {
    //     console.log("blockTime:", block.timestamp);
    //     console.log("blockHeight:", block.number);
    //     vm.warp(3);
    //     // skip(777);
    //     vm.roll(3);

    //     console.log("blockTime:", block.timestamp);
    //     console.log("blockHeight:", block.number);
    //     // rewind(777);
    //     // console.log("blockTime:", block.timestamp);
    //     // console.log("blockHeight:", block.number);
    //     // rewind(777);
    //     // vm.roll(1);
    //     // console.log("blockTime:", block.timestamp);
    //     // console.log("blockHeight:", block.number);
    // }

    function testDeposit() public returns (address) {
        address user1 = makeAddr("user1");
        deal(address(ctst), user1, 1000 ether);

        vm.startPrank(user1, user1);
        ctst.approve(address(bp), 0);
        vm.stopPrank();

        // NotWarmupPeriod
        // vm.expectRevert(NotWarmupPeriod.selector);
        uint256 amount = bpConfig.minRaisingTarget / 2;
        deposit(user1, amount, NotWarmupPeriod.selector);
        // bp.deposit(amount);

        // warmup start
        vm.warp(bp.startTimeOfWarmup());

        vm.startPrank(user1, user1);
        // console.log("allowance to bp:", ctst.allowance(user1, address(bp)));
        vm.expectRevert("ERC20: insufficient allowance");
        bp.deposit(amount);
        vm.stopPrank();

        // // approve first
        // ctst.approve(address(bp), amount);

        // // min deposit error
        console.log("minDeposit:", bp.minDeposit());
        console.log("maxDeposit:", bp.maxRaisingTarget() - bp.totalRaised());
        deposit(user1, bp.minDeposit() - 1, TooSmallDepositError.selector);

        deposit(user1, amount);

        // // still depositable
        assertEq(bp.isDepositable(), true);

        amount = bp.maxRaisingTarget() - bp.totalRaised() - bp.minDeposit() + 1;
        deposit(user1, amount);

        assertLt(bp.maxRaisingTarget() - bp.totalRaised(), bp.minDeposit());
        // deposit(user1, bp.maxRaisingTarget() - bp.totalRaised());

        vm.startPrank(user1, user1);
        amount = bp.maxRaisingTarget() - bp.totalRaised();
        ctst.approve(address(bp), amount);
        deal(address(ctst), user1, amount);

        vm.expectEmit(true, true, false, true);
        emit BPDeposited(user1, amount);
        vm.expectEmit(false, false, false, true, address(bp));
        // emit BPFullyRaised(bp.maxRaisingTarget());
        emit BPFullyRaised(bp.maxRaisingTarget());
        emit BPBoostTaskCreated();

        bp.deposit(amount);
        vm.stopPrank();

        // vm.warp();
        deposit(user1, amount, NotWarmupPeriod.selector);

        assertEq(bp.endTimeOfWarmup(), block.timestamp);
        assertEq(bp.endTimeOfLockup(), block.timestamp + bpConfig.durationOfLockup);
        assertEq(bp.isDepositable(), false);
        // vm.stopPrank();
        return user1;
    }

    function testBoost() public returns (address) {
        address user1 = testDeposit();

        // vm.prank(address(automate));

        assertTrue(bp.status() == BPStatus.WAIT_BOOST);

        vm.expectEmit(false, false, false, false, address(bp));
        emit BPBoostTaskExecuted();
        automateBP.boost(address(bp));

        assertTrue(bp.status() == BPStatus.WAIT_SETTLE);
        increaseVersion();
        market.settleAll();
        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(bp));

        lp.settle(receiptIds[0]);
        assertTrue(bp.status() == BPStatus.LOCKUP);

        assertTrue(bp.totalSupply() == bp.totalRaised());
        assertTrue(bp.balanceOf(user1) == bp.totalRaised());

        console.log("CLB totalSupply:", bp.totalSupply());
        console.log("CLP totalSupply:", lp.totalSupply());
        console.log("CLP balanceOf(bp):", lp.balanceOf(address(bp)));
        // vm.stopPrank();
        return user1;
    }

    function testLockup() public {
        address user1 = testBoost();
        assertTrue(bp.isDepositable() == false);
        assertTrue(bp.isClaimable() == false);
        assertTrue(bp.isRefundable() == false);

        vm.startPrank(user1);
        vm.expectRevert(RefundError.selector);
        bp.refund();

        uint256 clpBefore = lp.balanceOf(user1);
        assertEq(clpBefore, 0);
        // console.log("CLP balanceOf(bp):", lp.balanceOf(user1));
        vm.expectRevert(ClaimTimeError.selector);
        bp.claimLiquidity();

        // check nontransferable
        address user2 = makeAddr("user2");
        vm.expectRevert(NonTransferable.selector);
        bp.transfer(user2, 1);

        assertTrue(bp.isClaimable() == false);
        vm.warp(bp.endTimeOfLockup() + 1);
        assertTrue(bp.isClaimable() == true);

        console.log("before claim:");
        console.log("CLP balanceOf(user1):", lp.balanceOf(user1));
        console.log("CLB balanceOf(user1):", bp.balanceOf(address(user1)));

        vm.expectEmit(true, false, false, false, address(bp));
        emit BPClaimed(user1, bp.balanceOf(user1), 1 /* any */);
        bp.claimLiquidity();

        console.log("after claim:");
        console.log("CLP balanceOf(bp):", lp.balanceOf(address(bp)));
        console.log("CLP balanceOf(user1):", lp.balanceOf(user1));
        console.log("CLB balanceOf(user1):", bp.balanceOf(address(user1)));

        vm.stopPrank();
    }

    function testRefund() public {
        address user1 = makeAddr("user1");
        vm.warp(bp.startTimeOfWarmup());
        uint256 amount = bp.minRaisingTarget() - 1;
        deposit(user1, amount);

        assertTrue(bp.isRefundable() == false);
        vm.warp(bp.endTimeOfWarmup());
        
        assertTrue(bp.isRefundable() == true);
        assertTrue(bp.isRefundable() == true);
        assertTrue(bp.isDepositable() == false);
        assertTrue(bp.isClaimable() == false);

        vm.startPrank(user1);

        IERC20 token = IERC20(bp.settlementToken());

        assertTrue(token.balanceOf(user1) == 0);
        bp.refund();
        assertTrue(token.balanceOf(user1) == amount);
        vm.stopPrank();
    }
}
