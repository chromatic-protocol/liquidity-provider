// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title TrimAddress
 * @dev A library providing a function to trim the hexadecimal representation of an address.
 */
library TrimAddress {
    /**
     * @dev Trims the hexadecimal representation of an address to the specified length.
     * @param self The address to be trimmed.
     * @param length The desired length of the trimmed address.
     * @return converted The trimmed address as a bytes array.
     */
    function trimAddress(
        address self,
        uint8 length
    ) internal pure returns (bytes memory converted) {
        converted = new bytes(length);
        bytes memory _base = "0123456789abcdef";
        uint160 value = uint160(self);

        value = value >> (4 * (39 - length));
        for (uint256 i = 0; i < length; ) {
            value = value >> 4;
            converted[length - i - 1] = _base[uint8(value % 16)];
            unchecked {
                ++i;
            }
        }
    }
}
