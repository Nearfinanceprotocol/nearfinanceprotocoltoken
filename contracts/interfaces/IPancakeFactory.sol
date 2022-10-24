// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
