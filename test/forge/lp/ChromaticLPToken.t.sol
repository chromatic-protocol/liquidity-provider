// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {OpenPositionInfo, CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {ChromaticLPStorageCore} from "~/lp/base/ChromaticLPStorageCore.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ChromaticLP} from "~/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "~/lp/ChromaticLPLogic.sol";
import {IChromaticLPEvents} from "~/lp/interfaces/IChromaticLPEvents.sol";
import {IChromaticLPErrors} from "~/lp/interfaces/IChromaticLPErrors.sol";
import {LogUtil, Taker} from "./Helper.sol";
import {LPHelper} from "./LPHelper.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import "forge-std/console.sol";

contract ChromaticLPTokenTest is LPHelper, FoundryRandom, LogUtil {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    ChromaticLP lp;

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
        increaseVersion();
    }

    function makeRandomAddr(uint256 maxAccount) internal returns (address) {
        string memory label = Strings.toString(maxAccount);
        return makeAddr(label);
    }

    function randomUser(uint256 maxAccount) internal returns (address) {
        address user = randomHolder();
        if (user == address(0) || randomNumber(1) == 0) {
            return makeRandomAddr(maxAccount);
        }
        return user;
    }

    function randomHolder() internal returns (address) {
        if (holders.length() > 0) {
            return holders.at(randomNumber(holders.length() - 1));
        } else {
            return address(0);
        }
    }

    function randomAddOrRmove(
        uint256 reservedAddAmount,
        uint256 maxAccount
    ) internal returns (ChromaticLPReceipt memory receipt) {
        uint256 action = randomNumber(1);
        address user;
        if (holders.length() == 0) {
            action = 0;
        } else if (type(uint256).max - lp.totalSupply() < reservedAddAmount) {
            action = 1;
        }

        // if (action == 1) {
        //     user = holders.at(randomNumber(holders.length() - 1));
        //     if (lp.balanceOf(user) == 0) {
        //         action = 0;
        //     }
        // }

        if (action == 0) {
            user = randomUser(maxAccount);

            uint256 amount = randomNumber(
                lp.estimateMinAddLiquidityAmount(),
                type(uint256).max - lp.totalSupply()
            );

            console.log("AddLiquidity", user, amount);
            receipt = addLiquidity(lp, amount, user);
        } else {
            user = randomHolder();
            uint256 amount;
            uint256 balance = lp.balanceOf(user);
            if (balance > lp.estimateMinRemoveLiquidityAmount()) {
                amount = randomNumber(lp.estimateMinRemoveLiquidityAmount(), lp.balanceOf(user));
                if (balance - amount < lp.estimateMinRemoveLiquidityAmount()) {
                    amount = lp.balanceOf(user);
                }
            } else {
                amount = balance;
            }

            console.log("AddLiquidity", user, amount);
            receipt = removeLiquidity(lp, amount, user);

            if (lp.balanceOf(user) == 0) {
                holders.remove(user);
            }
        }
    }

    function test_makeRandomAddr(uint256 maxAccount, uint256 loop) external {
        for (uint i = 0; i < loop; i++) {
            makeRandomAddr(maxAccount);
        }
    }

    function randomActions(uint256 actionCount, uint256 maxAccount, uint256 reservedAdd) internal {
        for (uint256 i = 0; i < actionCount; i++) {
            console.log("randomAction i(th):", i);
            receiptIds.add(randomAddOrRmove(reservedAdd, maxAccount).id);
        }
    }

    function randomActionsWithReserved(
        uint256 actionCount,
        uint256 maxAccount,
        address user,
        uint256 reservedAmount,
        ChromaticLPAction action
    ) internal {
        bool neccesaryActionDone = false;

        for (uint256 i = 0; i < actionCount; i++) {
            console.log("randomAction i(th):", i);
            receiptIds.add(randomAddOrRmove(reservedAmount, maxAccount).id);
            if (!neccesaryActionDone && randomNumber(actionCount) == 0) {
                receiptIds.add(actionLiquidity(lp, user, action, reservedAmount).id);
                neccesaryActionDone = true;
            }
        }
        if (!neccesaryActionDone) {
            receiptIds.add(actionLiquidity(lp, user, action, reservedAmount).id);
        }
    }

    function settleAll() internal {
        uint256 i;
        while (receiptIds.length() > 0) {
            console.log("settleAll (i)th: ", ++i);
            uint256 id = receiptIds.at(randomNumber(receiptIds.length() - 1));
            uint256[] memory marketReceiptIds = lp.getMarketReceiptsOf(id);
            LpReceipt[] memory lpReceits = market.getLpReceipts(marketReceiptIds);

            for (uint j = 0; j < lpReceits.length; j++) {
                logInfo(lpReceits[j]);
            }
            settle(lp, id);

            console.log("settleAll.remove receiptId:", id);
            receiptIds.remove(id);
        }
    }

    function test_TransactionsSameRound(uint256 actionCount, uint256 amount) external {
        // uint256 actionCount = 2;
        // uint256 amount = 100 ether;

        uint256 maxAccount = 10;

        vm.assume(amount >= lp.estimateMinAddLiquidityAmount());
        vm.assume(amount < type(uint256).max / 2);

        console.log("actionCount:", actionCount);
        address user1 = makeAddr("user1");
        uint256 minted = addMint(lp, amount, user1);

        address user2 = makeAddr("user2");

        console.log("randomActions");
        // addLiquidity only in first time
        holders.remove(user1);
        holders.remove(user2);

        randomActions(actionCount, maxAccount, amount);
        increaseVersion();

        settleAll();
        holders.remove(user1);
        holders.remove(user2);

        // randomly addLiquidity/removeLiquidity occurs
        randomActionsWithReserved(
            actionCount,
            maxAccount,
            user2,
            amount,
            ChromaticLPAction.ADD_LIQUIDITY
        );
        increaseVersion();

        uint256 balanceBefore2 = lp.balanceOf(user2);

        settleAll();
        holders.remove(user1);
        holders.remove(user2);

        uint256 minted2 = lp.balanceOf(user2) - balanceBefore2;

        console.log("user1 minted:", user1, minted);
        console.log("user2 minted:", user2, minted2);
        assertEq(minted, minted2);

        console.log("test burn");

        // test remove and burned amount
        uint256 burned = removeBurn(lp, lp.balanceOf(user1), user1);

        // exclude user2 for preventing randomly execute removeLiquidity
        balanceBefore2 = lp.balanceOf(user2);
        console.log("balanceOf User2 before remove:", lp.balanceOf(user2));

        holders.remove(user1);
        holders.remove(user2);

        // randomly addLiquidity/removeLiquidity occurs
        randomActionsWithReserved(
            actionCount,
            maxAccount,
            user2,
            lp.balanceOf(user2),
            ChromaticLPAction.REMOVE_LIQUIDITY
        );

        increaseVersion();
        settleAll();

        uint256 burned2 = balanceBefore2 - lp.balanceOf(user2);
        console.log("user1 burned:", burned);
        console.log("user2 balanceOf:", lp.balanceOf(user2));
        console.log("user2 burned:", burned2);

        // console.log("user2 burned:", burned2);
        // assertEq(burned, burned2);
    }
}
