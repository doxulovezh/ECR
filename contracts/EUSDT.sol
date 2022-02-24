// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract DOTC  is ERC20,ReentrancyGuard,Ownable {
  using SafeERC20 for IERC20;
  uint256 private aproveunlocked=1;
  constructor(uint256 initialSupply) ERC20("Decentralized OTC Trading", "DOT") {
    _mint(msg.sender, initialSupply);
  }

  function TranferBath(uint256[] calldata amounts,address[] calldata addrs) public nonReentrant returns  (bool) {
    uint len=addrs.length;
    uint len2=amounts.length;
    require(len==len2,"amounts addrs not equal");
    uint i=0;
        for(i=0;i<len;i++){
        IERC20(address(this)).safeTransfer(addrs[i],amounts[i]);
        }
        return true;
    }

   
}
