// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title The IChromaticLPMeta interface exposes methods that developers can use to obtain metadata information related to Chromatic Protocol liquidity provider. These functions provide details such as the name and tag associated with a liquidity pool.
 */
interface IChromaticLPMeta {
    /**
     * @dev Retrieves the name of the Chromatic Protocol liquidity provider.
     * @return The name of the liquidity provider.
     */
    function lpName() external view returns (string memory);

    /**
     * @dev Retrieves the tag associated with the Chromatic Protocol liquidity provider.
     * @return The tag associated with the liquidity provider
     */
    function lpTag() external view returns (string memory);
}
