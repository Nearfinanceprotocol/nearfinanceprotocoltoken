// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {IERC20} from "./interfaces/IERC20.sol";

/// @notice this contract would be used to store the reward token and dispense reward token
contract Tresury {
    // =======================================
    // -> State Variables
    // =======================================
    IERC20 public token_contract;
    address public owner;


    constructor() {
        owner = msg.sender;
    }

    
    /// @notice function would be used to send reward token to users 
    /// @dev this function can only be called by token contract 
    function pay_reward(address _to, uint256 _amount) external {

    }

    function pall_out_lost_tokens(address _token, address _to) external {

    }

    // =====================================
    // -> Auth Guard 
    // ====================================
    function set_owner(address _new_owner) external {

    }

    function set_token_contract(address _token_contract) external {

    }

    // =====================================
    // -> Internal Function Modifers
    // =====================================
    function only_token_contract() internal view {

    }

    function only_owner() internal view {

    }
}
