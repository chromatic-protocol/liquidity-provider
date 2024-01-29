// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IAutomateLP} from "~/lp/interfaces/IAutomateLP.sol";

/**
 * @title IChromaticLPAutomate
 * @dev Interface for automating tasks related to Chromatic Liquidity Providers (LPs).
 */
interface IChromaticLPAutomate {
    /**
     * @dev Checks whether a rebalance task is needed.
     * @return A boolean indicating whether a rebalance task is needed.
     */
    function checkRebalance() external view returns (bool);

    /**
     * @dev Initiates a rebalance task, providing fees for the keeper.
     * @param feePayee The address to receive the keeper fees.
     * @param keeperFee The amount of native tokens to be paid as keeper fees.
     */
    function rebalance(address feePayee, uint256 keeperFee) external;

    /**
     * @dev Checks whether a settle task is needed for a specific receipt ID.
     * @param receiptId The unique identifier of the receipt associated with the task.
     * @return A boolean indicating whether a settle task is needed.
     */
    function checkSettle(uint256 receiptId) external view returns (bool);

    /**
     * @dev Initiates a settle task for a specific receipt ID, providing fees for the keeper.
     * @param receiptId The unique identifier of the receipt associated with the task.
     * @param feePayee The address to receive the keeper fees.
     * @param keeperFee The amount of native tokens to be paid as keeper fees.
     */
    function settleTask(uint256 receiptId, address feePayee, uint256 keeperFee) external;

    /**
     * @notice Sets the AutomateLP contract address.
     * @param automate The address of the AutomateLP contract.
     */
    function setAutomateLP(IAutomateLP automate) external;

    /**
     * @notice Gets the current AutomateLP contract address.
     * @return The address of the AutomateLP contract.
     */
    function automateLP() external view returns (IAutomateLP);
}
