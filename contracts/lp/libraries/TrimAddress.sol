// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library TrimAddress {
    function trimAddress(
        address self,
        uint8 length
    ) internal pure returns (bytes memory converted) {
        converted = new bytes(length);
        bytes memory _base = "0123456789abcdef";
        uint160 value = uint160(self);

        value = value >> (4 * (39 - length));
        for (uint256 i = 0; i < length; i++) {
            value = value >> 4;
            converted[length - i - 1] = _base[uint8(value % 16)];
        }
    }
}
