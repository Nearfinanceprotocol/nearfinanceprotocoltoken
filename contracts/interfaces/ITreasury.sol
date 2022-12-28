// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

// @notice this function interface is going to be used for communicatng with the tresury contract
interface ITreasury {
    function pay_reward(address _to, uint256 _amount) external;
}