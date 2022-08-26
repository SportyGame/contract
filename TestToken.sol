// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestToken is ERC20 {
    uint8 constant _decimals = 5;
    function decimals() public pure override returns (uint8) { return _decimals; }
    constructor(uint256 initialSupply) ERC20("TEST", "TET") {
        _mint(msg.sender, initialSupply);
    }
}