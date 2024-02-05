// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {BPPeriod, BPStatus} from "~/bp/libraries/BPState.sol";

/**
 * @title IChromaticBPLens
 * @dev Interface for viewing the parameters and state of Chromatic Boosting Pool.
 */
interface IChromaticBPLens {
    /**
     * @dev Retrieves the total amount raised in the boosting pool.
     * @return amount The total raised amount.
     */
    function totalRaised() external view returns (uint256 amount);

    /**
     * @dev Retrieves the minimum raising target amount.
     * @return amount The minimum raising target amount.
     */
    function minRaisingTarget() external view returns (uint256 amount);

    /**
     * @dev Retrieves the maximum raising target amount.
     * @return amount The maximum raising target amount.
     */
    function maxRaisingTarget() external view returns (uint256 amount);

    /**
     * @dev Retrieves the minimum deposit amount.
     * @return amount The minimum deposit amount.
     */
    function minDeposit() external view returns (uint256 amount);

    /**
     * @dev Retrieves the start time of the warm-up period.
     * @return timestamp The timestamp of the start time of the warm-up period.
     */
    function startTimeOfWarmup() external view returns (uint256 timestamp);

    /**
     * @dev Retrieves the end time of the warm-up period.
     * @return timestamp The timestamp of the end time of the warm-up period.
     */
    function endTimeOfWarmup() external view returns (uint256 timestamp);

    /**
     * @dev Retrieves the end time of the lock-up period.
     * @return timestamp The timestamp of the end time of the lock-up period.
     */
    function endTimeOfLockup() external view returns (uint256 timestamp);

    /**
     * @dev Retrieves the address of the target Chromatic Protocol liquidity provider.
     * @return lpAddress The address of the target liquidity provider.
     */
    function targetLP() external view returns (IChromaticLP lpAddress);

    /**
     * @dev Retrieves the settlement token used in the boosting pool.
     * @return token The ERC20 token used for settlement.
     */
    function settlementToken() external view returns (IERC20 token);

    /**
     * @dev Retrieves the current period of the boosting pool.
     * @return period The current boosting pool period.
     */
    function currentPeriod() external view returns (BPPeriod period);

    /**
     * @dev Checks if it is possible to make a deposit.
     * @return true if a deposit can be made, false otherwise.
     */
    function isDepositable() external view returns (bool);

    /**
     * @dev Checks if a refund can be initiated.
     * @return true if a refund can be initiated, false otherwise.
     */
    function isRefundable() external view returns (bool);

    /**
     * @dev Checks if a claim can be made.
     * @return true if a claim can be made, false otherwise.
     */
    function isClaimable() external view returns (bool);

    /**
     * @dev Retrieves the total reward available in the boosting pool.
     * @return totalReward The total reward amount.
     */
    function totalReward() external view returns (uint256);

    /**
     * @dev Retrieves the current status of the boosting pool.
     * @return status The current status of the boosting pool.
     */
    function status() external view returns (BPStatus);

    /**
     * @dev Retrieves the address of ChromaticBPFactory.
     * @return The address of ChromaticBPFactory.
     */
    function bpFactory() external view returns (address);

    /**
     * @dev Retrieves the automate contract currently set for the Chromatic BP.
     * @return The address of the automate contract for this Chromatic BP.
     */
    function automateBP() external view returns (address);
}
