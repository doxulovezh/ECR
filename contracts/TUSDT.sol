// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract TUSDT is ERC20,Ownable {
  uint256 private aproveunlocked=1;
  constructor(uint256 initialSupply) ERC20("Test USDT", "TUSDT") {
    _mint(msg.sender, initialSupply);
  }
}
