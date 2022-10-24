// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC20Snapshot} from "./utils/SnapShotToken.sol";
import {IERC20 as IBEP20} from "./interfaces/IERC20.sol";
import {Context} from "./utils/Context.sol";
import {Ownable} from "./utils/Ownable.sol";
import {IPancakeFactory} from "./interfaces/IPancakeFactory.sol";
import {IPancakeRouter02} from "./interfaces/IPancakeRouter02.sol";




struct User {
    uint256 buy;
    uint256 sell;
    bool exists;
}


contract NearFinanceProtocol is ERC20Snapshot, Ownable {

    /**
     * ===================================================
     * ----------------- STATE VARIABLES -----------------
     * ===================================================
     */

    IPancakeRouter02 private pancakeV2Router;
    address public pancakeswapPair;
    string private constant _name = "Near Finance Protocol";
    string private constant _symbol = "NRF";
    uint8 private constant _decimals = 18;
    uint256 private constant MAX = type(uint256).max;
    uint256 private _tTotal = 1000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 public _tFeeTotal;
    uint256 public _NearFinanceProtocolBurned;
    bool public _cooldownEnabled = true;
    bool public tradeAllowed = false;
    bool private liquidityAdded = false;
    bool private inSwap = false;
    bool public swapEnabled = false;
    bool public feeEnabled = false;
    bool private limitTX = false;
    uint256 private _maxTxAmount = _tTotal;
    uint256 private _reflection = 0;
    uint256 private _contractFee = 5;
    uint256 private _NearFinanceProtocolBurn = 0;
    uint256 private _maxBuyAmount;
    uint256 private buyLimitEnd;
    address payable private _development;
    address payable private _boost;
    address public targetToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public boostFund = 0x01dcA19048Ca3A10C46da7a7423b24112BEF08c8;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping (address => User) private cooldown;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isBlacklisted;




    /**
     * =======================================================
     * --------------------- EVENTS --------------------------
     * =======================================================
     */

    event CooldownEnabledUpdated(bool _cooldown);
    event MaxBuyAmountUpdated(uint _maxBuyAmount);
    event MaxTxAmountUpdated(uint256 _maxTxAmount);

    /**
     * =======================================================
     * -------------------- MODIFIER -------------------------
     * =======================================================
     */

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    } // this would be acting as the reentrancy guard

    constructor(address payable addr1, address payable addr2, address addr3) {
        _development = addr1;
        _boost = addr2;
        _rOwned[_msgSender()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_development] = true;
        _isExcludedFromFee[_boost] = true;
        _isExcludedFromFee[addr3] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }



    /**
     * ===================================================
     * ----------------- VIEW FUNCTIONS ------------------
     * ===================================================
     */

    /// @return this returns 
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }




    /**
     * ===================================================
     * ----------------- WRITE FUNCTIONS -----------------
     * ===================================================
     */


    /// @notice address set to this mapping, would not paying fees on transfers 
    /// @param _address: address to be set to be excluded for fees
    /// @param _bool: 
    function setExcludedFromFee(address _address,bool _bool) external onlyOwner {
        address addr3 = _address;
        _isExcludedFromFee[addr3] = _bool;
    }


    /// @notice this function would change the target token contract address
    /// @param _newTargetToken: this is the address of the new target token
    function setTargetToken(address _newTargetToken) external onlyOwner {
        require(_newTargetToken != address(0), "can't be addres zero");
        targetToken = _newTargetToken;
    }

    /// @notice this function would change the target boost wallet address, the is address that would recieve the boost token 
    /// @param _newBoostFund: this is the new address that would be recieving the boost funds
    function boostFundAddress(address _newBoostFund) external onlyOwner {
        require(_newBoostFund != address(0), "can't be addres zero");
        boostFund = _newBoostFund;
    }

    /// @notice this function would be used to blacklist an address, addresses that are blacklisted cannot perfolrm transfers 
    function setAddressIsBlackListed(address _address, bool _bool) external onlyOwner {
        _isBlacklisted[_address] = _bool;
    }

    /// @notice this is a view dunction would be used to see if an address is blaclisted 
    function viewIsBlackListed(address _address) public view returns(bool) {
        return _isBlacklisted[_address];
    }

    /// @notice this is the external function that would be handling token transfer
    /// @param recipient: this is the address that would be recieving the token
    /// @param amount: this is the amount of tokens to be transfered
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /// @notice this is the view function that would show that and address is given allowance
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice this is the address that allows an account to approve another to spend it funds 
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    /// @notice this is the function to call if yoour account has been approved to spend token from another account 
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender,_msgSender(),_allowances[sender][_msgSender()].sub(amount,"BEP20: transfer amount exceeds allowance"));
        return true;
    }
    /// @notice this function is used to toggle the fees on transfer 
    function setFeeEnabled(bool enable) external onlyOwner {
        feeEnabled = enable;
    }
}
