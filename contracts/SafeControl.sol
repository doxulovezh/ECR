// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract SafeControl {
    uint256 private unlocked=1;
    modifier lock(){
        require(unlocked==1,"LOCKED");
        unlocked=0;
        _;
        unlocked=1;
    }
}