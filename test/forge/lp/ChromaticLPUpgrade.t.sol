// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LogUtil, Taker} from "./Helper.sol";
import {LPHelper} from "./LPHelper.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";

import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import "forge-std/console.sol";

interface INewFeature {
    error NotSameValue();

    function setCounter(uint256 init) external;

    function increase() external;

    function decrease() external;

    function assertCounter(uint256 expected) external;
}

contract LogicV2 is ChromaticLPLogic, INewFeature {
    uint256 internal counter;

    constructor(bytes32 version) ChromaticLPLogic(version) {}

    function setCounter(uint256 initialValue) external onlyDao {
        console.log("newFeature called:", initialValue);
        counter = initialValue;
    }

    function increase() external {
        counter += 1;
        console.log("increase:", counter);
    }

    function decrease() external {
        counter -= 1;
        console.log("decrease:", counter);
    }

    function assertCounter(uint256 expected) external {
        if (expected != counter) {
            revert NotSameValue();
        }
    }

    function onUpgrade(bytes calldata data) external override onlyDelegateCall onlyDao {
        console.log("onUpgrade:", string(data));
        console.log("_this:", _this);
    }
}

contract ChromaticLPUpgradeTest is LPHelper, LogUtil, IChromaticLPErrors {
    ChromaticLP lp;
    LogicV2 v2;

    error OnlyDelegateCall();

    function setUp() public override {
        super.setUp();

        lp = deployLP(
            ChromaticLPStorageCore.ConfigParam({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 200,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: 1 ether,
                minHoldingValueToRebalance: 2 ether
            })
        );
        increaseVersion(); // oracle update

        v2 = new LogicV2("version2");
    }

    function test_Upgradeable() public {
        address user1 = makeAddr("user1");

        // test upgrade working
        vm.expectEmit(false, false, false, true);
        emit Upgraded(address(lpLogic), address(v2));
        lp.upgradeTo(address(v2), bytes("upgrade calldata"));

        // fail with invalid address
        vm.expectRevert(UpgradeFailedNotContractAddress.selector);
        lp.upgradeTo(user1, bytes("upgrade calldata"));
        // fail with invalid address
        vm.expectRevert(UpgradeFailedNotContractAddress.selector);
        lp.upgradeTo(address(0), bytes("upgrade calldata"));

        // error when calling directly onUpgrade
        vm.expectRevert(OnlyDelegateCall.selector);
        v2.onUpgrade(bytes("aaa"));

        // test authorized user calling
        vm.startPrank(user1);
        vm.expectRevert(OnlyAccessableByDao.selector);
        INewFeature(address(lp)).setCounter(2);
        vm.stopPrank();

        vm.startPrank(lp.dao());
        INewFeature(address(lp)).setCounter(2);
        vm.stopPrank();

        // test new feature working correctly
        INewFeature(address(lp)).increase();
        INewFeature(address(lp)).assertCounter(3);
        INewFeature(address(lp)).decrease();
        INewFeature(address(lp)).assertCounter(2);
    }

    function test_StateAfterUpgrade() public {
        lp.setSuspendMode(1);
        lp.upgradeTo(address(v2), bytes("this will fail"));
        assertTrue(1 == lp.suspendMode());

        address user1 = makeAddr("user1");
        vm.expectRevert(AddLiquiditySuspended.selector);
        uint256 amount = 100 ether;
        lp.addLiquidity(100 ether, user1);

        lp.setSuspendMode(0);

        // removeLiquidity after upgrade
        ChromaticLPReceipt memory receipt = addLiquidity(lp, 100 ether, user1);
        lp.upgradeTo(address(v2), bytes("upgrade"));

        increaseVersion();
        settle(lp, receipt.id);

        uint256 balance = lp.balanceOf(user1);
        assertTrue(balance == amount);
        receipt = removeLiquidity(lp, lp.balanceOf(user1), user1);
        increaseVersion();
        settle(lp, receipt.id);

        assertTrue(lp.balanceOf(user1) == 0);
    }
}
