// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLPLens, ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {Test} from "forge-std/Test.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import "forge-std/console.sol";

contract Taker {
    IChromaticRouter router;

    constructor(IChromaticRouter _router) {
        router = _router;
    }

    function createAccount() public {
        router.createAccount();
    }

    function getAccount() external view returns (address) {
        return router.getAccount();
    }

    function openPosition(
        address market,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (OpenPositionInfo memory) {
        return router.openPosition(market, qty, takerMargin, makerMargin, maxAllowableTradingFee);
    }

    function claimPosition(address market, uint256 positionId) external {
        router.claimPosition(market, positionId);
    }

    function closePosition(address market, uint256 positionId) external {
        router.closePosition(market, positionId);
    }
}

contract LogUtil is Test {
    function logInfo(ChromaticLPReceipt memory receipt, string memory message) public view {
        console.log(message);
        logInfo(receipt);
    }

    function logInfo(ChromaticLPReceipt memory receipt) internal view {
        console.log("{");
        console.log("Receipt");
        console.log("  id:", receipt.id);
        console.log("  oracleVersion:", receipt.oracleVersion);
        console.log("  amount:", receipt.amount / 10 ** 18, "ether");
        console.log("  recipient:", receipt.recipient);
        console.log("  action:", uint256(receipt.action));
        console.log("}");
    }

    function logInfo(IChromaticLPLens lp, string memory message) public view {
        console.log(message);
        logInfo(lp);
    }

    function logInfo(IChromaticLPLens lp) public view {
        console.log("ChromaticLP:");
        console.log("{");
        console.log("{");
        console.log("LP values");
        ValueInfo memory value = lp.valueInfo();
        console.log("  total: ", value.total / 10 ** 18);
        console.log("  holding: ", value.holding / 10 ** 18);
        console.log("  pending: ", value.pending / 10 ** 18);
        console.log("  holdingClb: ", value.holdingClb / 10 ** 18);
        console.log("  pendingClb: ", value.pendingClb / 10 ** 18);
        console.log("  utilizationBPS: ", lp.utilization());
        console.log("}");
    }

    function logCLB(IChromaticLPLens lp) public view {
        uint256[] memory clbBalances = lp.clbTokenBalances();
        int16[] memory feeRates = lp.feeRates();
        console.log("clbBalances:");
        console.log("{");
        for (uint256 i; i < feeRates.length; ++i) {
            if (clbBalances[i] != 0) {
                console.log("  ");
                console.logInt(int256(feeRates[i]));
                console.log(": ");
                console.log(clbBalances[i] / 10 ** 18);
                console.log("  %s: %e", vm.toString(int256(feeRates[i])), clbBalances[i]);
            }
        }
        console.log("}");
    }

    function logInfo(OpenPositionInfo memory info) internal view {
        console.log("OpenPositionInfo:");
        console.log("{");
        console.log("  id:", info.id);
        console.log("  openTimestamp:", info.openTimestamp);
        console.log("  openVersion:", info.openVersion);
        if (info.qty >= 0) {
            console.log("  qty:", uint256(info.qty) / (10 ** 18), "ether");
        } else {
            console.log("  qty: -", uint256(info.qty) / (10 ** 18), "ether");
        }
        console.log("  takerMargin:", info.takerMargin / 10 ** 18, "ether");
        console.log("  makerMargin:", info.makerMargin / 10 ** 18, "ether");
        console.log("  tradingFee:", info.tradingFee / 10 ** 18, "ether");
        console.log("}");
    }

    function logInfo(LpReceipt memory lpReceit) internal view {
        console.log("LpReceipt(market)");
        console.log("{");
        console.log("id:", lpReceit.id);
        console.log("oracleVersion:", lpReceit.oracleVersion);
        console.log("amount:", lpReceit.amount);
        console.log("recipient:", lpReceit.recipient);
        console.log("action:", uint(lpReceit.action));
        if (lpReceit.tradingFeeRate > 0) {
            console.log("tradingFeeRate:", uint16(lpReceit.tradingFeeRate));
        } else {
            console.log("tradingFeeRate: -", uint16(-lpReceit.tradingFeeRate));
        }
        console.log("}");
    }
}
