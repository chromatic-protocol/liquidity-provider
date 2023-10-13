// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";

library LPStateViewLib {
    using LPStateViewLib for LPState;

    function settlementToken(LPState storage s_state) internal view returns (IERC20) {
        return s_state.market.settlementToken();
    }

    function clbToken(LPState storage s_state) internal view returns (IERC1155) {
        return s_state.market.clbToken();
    }

    function getReceipt(
        LPState storage s_state,
        uint256 receiptId
    ) internal view returns (ChromaticLPReceipt memory) {
        return s_state.receipts[receiptId];
    }

    function binCount(LPState storage s_state) internal view returns (uint256) {
        return s_state.feeRates.length;
    }
}
