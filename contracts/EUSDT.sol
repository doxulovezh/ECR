// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EUSDT  is ERC20 {
  uint256 private aproveunlocked=1;
  constructor(uint256 initialSupply) ERC20("Exchange USDT", "EUSDT") {
    _mint(msg.sender, initialSupply);
  }

  function TranferBath(uint256[] calldata amounts,address[] calldata addrs) public approvelock returns  (bool) {
    uint len=addrs.length;
    uint len2=amounts.length;
    require(len==len2,"amounts addrs not equal");
    uint i=0;
        for(i=0;i<len;i++){
        transfer(addrs[i],amounts[i]);
        }
        return true;
    }

    modifier approvelock(){
        require(aproveunlocked==1,"LOCKED");
        aproveunlocked=0;
        _;
        aproveunlocked=1;
    }
}
