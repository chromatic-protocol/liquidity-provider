// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LPState} from "~/lp/libraries/LPState.sol";
import {ValueInfo} from "~/lp/interfaces/IChromaticLPLens.sol";
import {BPS} from "~/lp/libraries/Constants.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library LPStateValueLib {
    using LPStateValueLib for LPState;
    using Math for uint256;

    function utilization(LPState storage s_state) internal view returns (uint16 currentUtility) {
        ValueInfo memory value = s_state.valueInfo();
        if (value.total == 0) return 0;
        currentUtility = uint16(
            uint256(value.total - (value.holding + value.pendingClb)).mulDiv(BPS, value.total)
        );
    }

    function totalValue(LPState storage s_state) internal view returns (uint256 value) {
        value = (s_state.holdingValue() + s_state.pendingValue() + s_state.totalClbValue());
    }

    function valueInfo(LPState storage s_state) internal view returns (ValueInfo memory info) {
        info = ValueInfo({
            total: 0,
            holding: s_state.holdingValue(),
            pending: s_state.pendingValue(),
            holdingClb: s_state.holdingClbValue(),
            pendingClb: s_state.pendingClbValue()
        });
        info.total = info.holding + info.pending + info.holdingClb + info.pendingClb;
    }

    function holdingValue(LPState storage s_state) internal view returns (uint256) {
        return IERC20(s_state.market.settlementToken()).balanceOf(address(this));
    }

    function pendingValue(LPState storage s_state) internal view returns (uint256) {
        return s_state.pendingAddAmount;
    }

    function holdingClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = s_state.clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    function pendingClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    function totalClbValue(LPState storage s_state) internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_state.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_state.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = s_state.clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i] +
                s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                ++i;
            }
        }
    }

    function clbTokenBalances(
        LPState storage s_state
    ) internal view returns (uint256[] memory _clbTokenBalances) {
        address[] memory _owners = new address[](s_state.feeRates.length);
        for (uint256 i; i < s_state.feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                ++i;
            }
        }
        _clbTokenBalances = IERC1155(s_state.market.clbToken()).balanceOfBatch(
            _owners,
            s_state.clbTokenIds
        );
    }

    function pendingRemoveClbBalances(
        LPState storage s_state
    ) internal view returns (uint256[] memory pendingBalances) {
        uint256 length = s_state.feeRates.length;
        pendingBalances = new uint256[](length);
        for (uint256 i; i < length; ) {
            pendingBalances[i] = s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
        }
    }
}
