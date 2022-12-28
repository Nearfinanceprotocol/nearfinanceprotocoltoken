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


    // ======================================
    // -> Custom Errors
    // ======================================
    error NOT_OWNER();
    error NOT_TOKEN_CONTRACT();


    constructor() {
        owner = msg.sender;
    }

    
    /// @notice function would be used to send reward token to users 
    /// @dev this function can only be called by token contract 
    function pay_reward(address _to, uint256 _amount) external {
        only_token_contract;

    }

    function pall_out_lost_tokens(address _token, address _to) external {

    }

    // =====================================
    // -> Auth Guard 
    // ====================================
    function set_owner(address _owner) external {
        only_owner;
        owner = _owner;
    }

    function set_token_contract(IERC20 _token_contract) external {
        only_owner;
        token_contract = _token_contract;
    }

    // =====================================
    // -> Internal Function Modifers
    // =====================================
    function only_token_contract() internal view {
        if(msg.sender != address(token_contract)) {
            revert NOT_TOKEN_CONTRACT();
        }
    }

    function only_owner() internal view {
        if(msg.sender != owner) {
            revert NOT_OWNER();
        }
    }
}
