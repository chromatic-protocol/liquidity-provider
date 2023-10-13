// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library LPStateViewLib {
    using LPStateViewLib for LPState;

    function settlementToken(LPState storage s_state) internal view returns (IERC20) {
        return s_state.market.settlementToken();
    }

    function clbToken(LPState storage s_state) internal view returns (IERC1155) {
        return s_state.market.clbToken();
    }
}
