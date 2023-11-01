// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title The IChromaticLPMeta interface exposes methods that developers can use to obtain metadata information related to Chromatic Protocol liquidity provider. These functions provide details such as the name and tag associated with a liquidity pool.
 */
interface IChromaticLPMeta {
    /**
     * @dev Emitted when the name of the liquidity provider is updated.
     * @param name The new name of the liquidity provider.
     */
    event SetLpName(string name);
    /**
     * @dev Emitted when the tag of the liquidity provider is updated.
     * @param tag The new tag associated with the liquidity provider.
     */
    event SetLpTag(string tag);

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

    /**
     * @dev Sets the name of the Chromatic Protocol liquidity provider.
     * @param lpName The new name for the liquidity provider.
     */
    function setLpName(string memory lpName) external;

    /**
     * @dev Sets the tag associated with the Chromatic Protocol liquidity provider.
     * @param lpTag The new tag for the liquidity provider.
     */
    function setLpTag(string memory lpTag) external;
}
