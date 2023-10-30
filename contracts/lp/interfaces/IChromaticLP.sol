// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLPLiquidity} from "./IChromaticLPLiquidity.sol";
import {IChromaticLPAdmin} from "./IChromaticLPAdmin.sol";
import {IChromaticLPLens} from "./IChromaticLPLens.sol";
import {IChromaticLPMeta} from "./IChromaticLPMeta.sol";
import {IChromaticLPEvents} from "./IChromaticLPEvents.sol";

import {IChromaticLPErrors} from "./IChromaticLPErrors.sol";

/**
 * @title The IChromaticLP interface consolidates several other interfaces, allowing developers to access a wide range of functionalities related to Chromatic Protocol liquidity providers. It includes methods from liquidity management, metadata retrieval, lens queries, administration, event tracking, and error handling.
 */
interface IChromaticLP is
    IChromaticLPLiquidity,
    IChromaticLPLens,
    IChromaticLPMeta,
    IChromaticLPAdmin,
    IChromaticLPEvents,
    IChromaticLPErrors
{
    /**
     * @dev Retrieves the address of the market associated with the Chromatic Protocol liquidity provider.
     * @return The address of the market associated with the liquidity provider.
     */
    function market() external view returns (address);

    /**
     * @dev Retrieves the address of the settlement token associated with the Chromatic Protocol liquidity provider.
     * @return The address of the settlement token used in the liquidity provider.
     */
    function settlementToken() external view returns (address);

    /**
     * @dev Retrieves the address of the LP token associated with the Chromatic Protocol liquidity provider.
     * @return The address of the LP (Liquidity Provider) token issued by the liquidity provider.
     */
    function lpToken() external view returns (address);
}
