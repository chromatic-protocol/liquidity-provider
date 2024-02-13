// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Errors
 * @dev A library containing error messages for the Chromatic Protocol LP.
 */
library Errors {
    /**
     * @dev Error message for withdrawal amount less than the automation fee.
     */
    string constant WITHDRAWAL_LESS_THAN_AUTOMATION_FEE = "WLA";
}
