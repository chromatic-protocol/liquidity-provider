// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestSettlementToken is ERC20, Ownable {
    string private _name;
    string private _symbol;
    uint8 _decimals;
    uint256 private _faucetAmount;
    uint256 private _faucetMinInterval;

    mapping(address => uint256) public lastFaucetTimestamp;

    error AlreadyFaucetedInInterval();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 faucetAmount_,
        uint256 faucetMinInterval_
    ) ERC20("", "") {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _faucetAmount = faucetAmount_;
        _faucetMinInterval = faucetMinInterval_;
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function faucet() external {
        if (
            lastFaucetTimestamp[msg.sender] > 0 &&
            block.timestamp - lastFaucetTimestamp[msg.sender] < _faucetMinInterval
        ) {
            revert AlreadyFaucetedInInterval();
        }
        lastFaucetTimestamp[msg.sender] = block.timestamp;
        _mint(msg.sender, _faucetAmount);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function setName(string memory name_) external onlyOwner {
        _name = name_;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function setSymbol(string memory symbol_) external onlyOwner {
        _symbol = symbol_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function faucetAmount() public view virtual returns (uint256) {
        return _faucetAmount;
    }

    function setFaucetAmount(uint256 faucetAmount_) external onlyOwner {
        _faucetAmount = faucetAmount_;
    }

    function faucetMinInterval() public view virtual returns (uint256) {
        return _faucetMinInterval;
    }

    function setFaucetMinInterval(uint256 faucetMinInterval_) external onlyOwner {
        _faucetMinInterval = faucetMinInterval_;
    }
}
