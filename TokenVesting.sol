// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";


contract TokenVesting{
    IERC20 public  token;
    constructor(address _initialAddress){
        token = IERC20(_initialAddress);
    }
}