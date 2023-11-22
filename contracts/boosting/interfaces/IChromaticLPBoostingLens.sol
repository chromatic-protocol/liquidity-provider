// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {LPBoostingPeriod} from "~/boosting/libraries/LPBoostingState.sol";

interface IChromaticLPBoostingLens {
    function totalRaised() external view returns (uint256 amount);

    function minRaisingTarget() external view returns (uint256 amount);

    function maxRaisingTarget() external view returns (uint256 amount);

    function startTimeOfWarmup() external view returns (uint256 timestamp);

    function endTimeOfWarmup() external view returns (uint256 timestamp);

    function endTimeOfLockup() external view returns (uint256 timestamp);

    function targetLP() external view returns (IChromaticLP lpAddress);

    function settlementToken() external view returns (IERC20 token);

    // function getStatus() external view returns (LPBoostingStatus status);

    function currentPeriod() external view returns (LPBoostingPeriod period);
}
