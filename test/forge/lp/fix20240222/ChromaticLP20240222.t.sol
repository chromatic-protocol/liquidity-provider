// forge test --fork-url "https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_KEY>" --match-contract 'ChromaitcLP20240222Test'

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chromatic-protocol/contracts/core/KeeperFeePayer.sol";
import "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import "~/lp/interfaces/IChromaticLPLens.sol";
import "~/lp/ChromaticLP.sol";
import "~/lp/ChromaticLPLogic.sol";
import "~/lp/base/ChromaticLPStorageCore.sol";
import "~/lp/libraries/ChromaticLPReceipt.sol";
import "~/automation/mate2/AutomateLP.sol";
import "./util.sol";
import "forge-std/console.sol";

contract ChromaitcLP20240222Test is Test {
    ChromaticLP lp;

    function setUp() public virtual {
        vm.rollFork(182825921);

        vm.startPrank(util.MARKET.factory().dao());
        KeeperFeePayer payer = KeeperFeePayer(payable(util.MARKET.factory().keeperFeePayer()));
        payer.setRouter(ISwapRouter(address(0xE592427A0AEce92De3Edee1F18E0157C05861564)));
        payer.approveToRouter(address(util.USDT), true);
        vm.stopPrank();

        ChromaticLPLogic lpLogic = new ChromaticLPLogic();
        lp = new ChromaticLP(
            lpLogic,
            ChromaticLPStorageCore.LPMeta({lpName: "lp pool", tag: "N"}),
            ChromaticLPStorageCore.ConfigParam({
                market: util.MARKET,
                utilizationTargetBPS: util.UTILIZATION_TARGET_BPS,
                rebalanceBPS: 500,
                rebalanceCheckingInterval: 1 hours,
                automationFeeReserved: util.AUTOMATION_FEE_RESERVED,
                minHoldingValueToRebalance: 2 ether
            }),
            util.feeRates(),
            util.distributionRates(),
            util.AUTOMATE_LP
        );

        deal(address(util.USDT), util.USER1, 100000041097);
        deal(address(util.USDT), util.USER2, 998304738);
    }

    function test() public virtual {
        uint256 addLiquidity1 = 25000010274;
        uint256 addLiquidity2 = 75000030823;
        uint256 keeperFee1 = 8367861;
        uint256 keeperFee2 = 8367865;

        phase1(addLiquidity1, addLiquidity2, keeperFee1, keeperFee2);
        phase2(addLiquidity1, addLiquidity2, keeperFee1, keeperFee2);
    }

    function phase1(
        uint256 addLiquidity1,
        uint256 addLiquidity2,
        uint256 keeperFee1,
        uint256 keeperFee2
    ) private {
        /************** version 2204 **********************************/
        setOracleVersion(2204, 1708480146, 52091840000000000000000);

        // USER1
        vm.startPrank(util.USER1);

        util.USDT.approve(address(lp), addLiquidity1 + addLiquidity2);

        console.log("USER1 AddLiquidity: %d", addLiquidity1);
        ChromaticLPReceipt memory receipt1 = lp.addLiquidity(addLiquidity1, util.USER1);
        assertLpValue(18762507748, 6237502526, 0, 0, 0);

        console.log("USER1 AddLiquidity: %d", addLiquidity2);
        ChromaticLPReceipt memory receipt2 = lp.addLiquidity(75000030823, util.USER1);
        assertLpValue(75025030911, 24975010186, 0, 0, 0);

        vm.stopPrank();

        // USER2
        vm.startPrank(util.USER2);

        uint256 addLiquidity3 = 998304738;
        util.USDT.approve(address(lp), addLiquidity3);
        console.log("USER2 AddLiquidity: %d", addLiquidity3);
        ChromaticLPReceipt memory receipt3 = lp.addLiquidity(addLiquidity3, util.USER2);
        assertLpValue(75786259499, 25212086336, 0, 0, 0);

        vm.stopPrank();

        /************** version 2205 **********************************/
        setOracleVersion(2205, 1708480236, 52119116081030000000000);

        // AUTOMATE_LP
        vm.startPrank(address(util.AUTOMATE_LP));

        console.log("Settle: %d", receipt1.id);
        lp.settleTask(receipt1.id, util.KEEPER_REGISTRY, 2774260000000000);
        assertLpValue(75777891638, 18974583810, 6237502526, 0, 24991642413);
        assertEq(
            lp.balanceOf(util.USER1),
            addLiquidity1 - keeperFee1,
            "LP.balanceOf USER1, Receipt1"
        );

        console.log("Settle: %d", receipt3.id);
        lp.settleTask(receipt3.id, util.KEEPER_REGISTRY, 2771749400000000);
        uint256 keeperFee3 = 8360291;
        assertLpValue(75769531347, 18737507660, 6474578676, 0, 25981586860);
        assertEq(
            lp.balanceOf(util.USER2),
            addLiquidity3 - keeperFee3,
            "LP.balanceOf USER2, Receipt3"
        );

        console.log("Settle: %d", receipt2.id);
        uint256 beforeBalance = lp.balanceOf(util.USER1);
        lp.settleTask(receipt2.id, util.KEEPER_REGISTRY, 2774260000000000);
        assertLpValue(75761163482, 0, 25212086336, 0, 100973249818);
        assertEq(
            lp.balanceOf(util.USER1),
            beforeBalance + addLiquidity2 - keeperFee2,
            "LP.balanceOf USER1, Receipt2"
        );

        vm.stopPrank();
    }

    function phase2(
        uint256 addLiquidity1,
        uint256 addLiquidity2,
        uint256 keeperFee1,
        uint256 keeperFee2
    ) private {
        /************** version 2206 **********************************/
        setOracleVersion(2206, 1708480956, 52150801045200000000000);

        // USER1
        vm.startPrank(util.USER1);

        uint256 removeLiquidity1 = lp.balanceOf(util.USER1);
        lp.approve(address(lp), removeLiquidity1);
        console.log("USER1 RemoveLiquidity: %d", removeLiquidity1);
        ChromaticLPReceipt memory receipt4 = lp.removeLiquidity(removeLiquidity1, util.USER1);
        assertLpValue(75761163482, 0, 247179940, 24964906396, 100973249818);

        vm.stopPrank();

        // USER3
        vm.startPrank(util.USER3);

        uint256 addLiquidity4 = 200000000;
        util.USDT.approve(address(lp), addLiquidity4);
        console.log("USER3 AddLiquidity: %d", addLiquidity4);
        ChromaticLPReceipt memory receipt5 = lp.addLiquidity(addLiquidity4, util.USER3);
        assertLpValue(75923663518, 37499964, 247179940, 24964906396, 100973249818);

        vm.stopPrank();

        /************** version 2207 **********************************/
        setOracleVersion(2207, 1708481106, 52119449495180000000000);

        // AUTOMATE_LP
        vm.startPrank(address(util.AUTOMATE_LP));

        console.log("Settle: %d", receipt4.id);
        lp.settleTask(receipt4.id, util.KEEPER_REGISTRY, 4603722200000000);
        uint256 keeperFee4 = 13885985;
        assertLpValue(905264543, 37499964, 247179940, 0, 989944447);
        assertEq(lp.balanceOf(util.USER1), 0, "LP.balanceOf USER1, Receipt4");
        assertEq(
            util.USDT.balanceOf(util.USER1),
            addLiquidity1 + addLiquidity2 - keeperFee1 - keeperFee2 - keeperFee4,
            "USDT.balanceOf USER1, Receipt4"
        );

        console.log("Settle: %d", receipt5.id);
        lp.settleTask(receipt5.id, util.KEEPER_REGISTRY, 3723975400000000);
        uint256 keeperFee5 = 11232452;
        assertLpValue(894032091, 0, 284679904, 0, 1178711995);
        assertEq(lp.balanceOf(util.USER3), addLiquidity4 - keeperFee5, "balanceOf USER3, Receipt5");

        vm.stopPrank();
    }

    function setOracleVersion(uint256 version, uint256 timestamp, int256 price) private {
        bytes memory result = abi.encode(IOracleProvider.OracleVersion(version, timestamp, price));
        vm.mockCall(
            address(util.MARKET.oracleProvider()),
            abi.encodeWithSelector(IOracleProvider.currentVersion.selector),
            result
        );
        vm.mockCall(
            address(util.MARKET.oracleProvider()),
            abi.encodeWithSelector(IOracleProvider.sync.selector),
            result
        );
    }

    function assertLpValue(
        uint256 holding,
        uint256 pending,
        uint256 holdingClb,
        uint256 pendingClb,
        uint256 valueOfSupply
    ) private {
        ValueInfo memory v = lp.valueInfo();
        uint256 _valueOfSupply = lp.valueOfSupply();
        console.log("\tholding: %d, pending: %d", v.holding, v.pending);
        console.log("\tholdingClb: %d, pendingClb: %d", v.holdingClb, v.pendingClb);
        console.log("\tvalueOfSupply: %d", _valueOfSupply);

        assertEq(v.holding, holding, "holding");
        assertEq(v.pending, pending, "pending");
        assertEq(v.holdingClb, holdingClb, "holdingClb");
        assertEq(v.pendingClb, pendingClb, "pendingClb");
        assertEq(_valueOfSupply, valueOfSupply, "valudOfSupply");
    }
}
