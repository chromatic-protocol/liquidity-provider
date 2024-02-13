// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(address(this), (10 ** 8) * (10 ** 18));
    }

    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
