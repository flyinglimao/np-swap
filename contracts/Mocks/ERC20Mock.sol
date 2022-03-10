//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function faucet(uint256 amount) public {
        faucet(amount, msg.sender);
    }
    function faucet(uint256 amount, address to) public {
        _mint(to, amount);
    }
}
