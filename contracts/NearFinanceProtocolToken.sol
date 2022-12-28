// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC20Snapshot} from "./utils/SnapShotToken.sol";
import {IERC20 as IBEP20} from "./interfaces/IERC20.sol";
import {Context} from "./utils/Context.sol";
import {Ownable} from "./utils/Ownable.sol";
import {IPancakeFactory} from "./interfaces/IPancakeFactory.sol";
import {IPancakeRouter02} from "./interfaces/IPancakeRouter02.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";
import {SafeMath} from "./libraries/SafeMath.sol";





struct User {
    uint256 buy;
    uint256 sell;
    bool exists;
}


contract NearFinanceProtocol is ERC20Snapshot, Ownable {
    using SafeMath for uint256;

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
    ITreasury private treasury;

    uint256 private rewardConstant = 365298595200000;
    uint256 private SnapshotInterval = 24 hours;
    uint256 private lastShotTime = block.timestamp; // time is seconds when the last snapshot was taken
    mapping(address => uint256) public claimed;



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

    /// @notice this is a function that would be used to toggle transaction limitation
    function setLimitTx(bool enable) external onlyOwner {
        limitTX = enable;
    }

    /// @notice this function would be used to enable trading after liquidity has been added 
    function enableTrading(bool enable) external onlyOwner {
        require(liquidityAdded);
        tradeAllowed = enable;
        //  first 5 minutes after launch.
        buyLimitEnd = block.timestamp + (300 seconds);
    }

    /// @notice this function woould be used to add the first liquidty 
    function addLiquidity() external onlyOwner() {
        IPancakeRouter02 _pancakeV2Router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pancakeV2Router = _pancakeV2Router;
        _approve(address(this), address(pancakeV2Router), _tTotal);
        pancakeswapPair = IPancakeFactory(_pancakeV2Router.factory()).createPair(address(this), _pancakeV2Router.WETH());
        pancakeV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        liquidityAdded = true;
        feeEnabled = true;
        limitTX = true;
        _maxTxAmount = 100000 * 10**18;
        _maxBuyAmount = 10000 * 10**18; //1% buy cap
        IBEP20(pancakeswapPair).approve(address(pancakeV2Router),type(uint256).max);
    }

    function manualSwapTokensForEth() external onlyOwner() {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function manualDistributeETH() external onlyOwner() {
        uint256 contractETHBalance = address(this).balance;
        distributeETH(contractETHBalance);
    }

    function manualSwapEthForTargetToken(uint amount) external onlyOwner() {
        swapETHfortargetToken(amount);
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        require(maxTxPercent > 0, "Amount must be greater than 0");
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
        emit MaxTxAmountUpdated(_maxTxAmount);
    }

    function setCooldownEnabled(bool onoff) external onlyOwner() {
        _cooldownEnabled = onoff;
        emit CooldownEnabledUpdated(_cooldownEnabled);
    }

    function timeToBuy(address buyer) public view returns (uint) {
        return block.timestamp - cooldown[buyer].buy;
    }

    function timeToSell(address buyer) public view returns (uint) {
        return block.timestamp - cooldown[buyer].sell;
    }

    function amountInPool() public view returns (uint) {
        return balanceOf(pancakeswapPair);
    }

    function tokenFromReflection(uint256 rAmount) private view returns (uint256) {
        require(rAmount <= _rTotal,"Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        _beforeTokenTransfer(from, to, amount);
        if (from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(tradeAllowed);
            require(!_isBlacklisted[from] && !_isBlacklisted[to]);
            if(_cooldownEnabled) {
                if(!cooldown[msg.sender].exists) {
                    cooldown[msg.sender] = User(0,0,true);
                }
            }

            if (from == pancakeswapPair && to != address(pancakeV2Router)) {
                if (limitTX) {
                    require(amount <= _maxTxAmount);
                }
                if(_cooldownEnabled) {
                    if(buyLimitEnd > block.timestamp) {
                        require(amount <= _maxBuyAmount);
                        require(cooldown[to].buy < block.timestamp, "Your buy cooldown has not expired.");
                        //  30sec BUY cooldown
                        cooldown[to].buy = block.timestamp + (30 seconds);
                    }
                    // 30 sec cooldown to SELL after a BUY to ban front-runner bots
                    cooldown[to].sell = block.timestamp + (30 seconds);
                }
                uint contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    swapETHfortargetToken(address(this).balance);
                }
                
            }


            if(to == address(pancakeswapPair) || to == address(pancakeV2Router) ) {
                
                if(_cooldownEnabled) {
                    require(cooldown[from].sell < block.timestamp, "Your sell cooldown has not expired.");
                }
                uint contractTokenBalance = balanceOf(address(this));
                if (!inSwap && from != pancakeswapPair && swapEnabled) {
                    if (limitTX) {
                    require(amount <= balanceOf(pancakeswapPair).mul(3).div(100) && amount <= _maxTxAmount);
                    }
                    uint initialETHBalance = address(this).balance;
                    swapTokensForEth(contractTokenBalance);
                    uint newETHBalance = address(this).balance;
                    uint ethToDistribute = newETHBalance.sub(initialETHBalance);
                    if (ethToDistribute > 0) {
                        distributeETH(ethToDistribute);
                    }
                }
            }
        }
        bool takeFee = true;
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to] || !feeEnabled) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
        restoreAllFee;

        _afterTokenTransfer(from, to, amount);
    }

    function removeAllFee() private {
        if (_reflection == 0 && _contractFee == 0 && _NearFinanceProtocolBurn == 0) return;
        _reflection = 0;
        _contractFee = 0;
        _NearFinanceProtocolBurn = 0;
    }

    function restoreAllFee() private {
        _reflection = 0;
        _contractFee = 5;
        _NearFinanceProtocolBurn = 0;
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 amount) private {
        (uint256 tAmount, uint256 tBurn) = _NearFinanceProtocolEthBurn(amount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getValues(tAmount, tBurn);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _NearFinanceProtocolEthBurn(uint amount) private returns (uint, uint) {
        uint orgAmount = amount;
        uint256 currentRate = _getRate();
        uint256 tBurn = amount.mul(_NearFinanceProtocolBurn).div(100);
        uint256 rBurn = tBurn.mul(currentRate);
        _tTotal = _tTotal.sub(tBurn);
        _rTotal = _rTotal.sub(rBurn);
        _NearFinanceProtocolBurned = _NearFinanceProtocolBurned.add(tBurn);
        return (orgAmount, tBurn);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount, uint256 tBurn) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) = _getTValues(tAmount, _reflection, _contractFee, tBurn);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tTeam, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
    }

    function _getTValues(uint256 tAmount, uint256 taxFee, uint256 teamFee, uint256 tBurn) private pure returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tTeam = tAmount.mul(teamFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam).sub(tBurn);
        return (tTransferAmount, tFee, tTeam);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tTeam, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeV2Router.WETH();
        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

     function swapETHfortargetToken(uint ethAmount) private {
        address[] memory path = new address[](2);
        path[0] = pancakeV2Router.WETH();
        path[1] = address(targetToken);

        _approve(address(this), address(pancakeV2Router), ethAmount);
        pancakeV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(ethAmount,path,address(boostFund),block.timestamp);
    }

    function distributeETH(uint256 amount) private {
        _development.transfer(amount.div(10));
        _boost.transfer(amount.div(2));
    }


    // ====================== Reward Contract Logic ===============================

    /// @dev this function should take the snapshot of all the balances of the user (and allow users the claim their day reward)
    /// @notice this function can be salled by anybody provided the timing is right
    function takePriceSnapshot() public {
        _snapshot(); // this snapshot is been taken here
        lastShotTime = block.timestamp;
    }

    /// @notice this is function would transfer the reward of the user based on their balance during the last snapshot.
    function claimDailyReward() public {
        if(claimed[msg.sender] > _getCurrentSnapshotId()) {
            if(lastShotTime + 24 hours >= block.timestamp) {
                // another snapshot  is due
                takePriceSnapshot();
                // payday reward based on the newly taken snapShot
                uint256 lastSnap__ = _getCurrentSnapshotId();
                uint256 snapBalance__ = balanceOfAt(msg.sender, lastSnap__);
                uint256 amountToTransfer__ = (snapBalance__ * rewardConstant) / 1 ether;
                // transfer(msg.sender, amountToTransfer__);
                treasury.pay_reward(msg.sender, amountToTransfer__);
                claimed[msg.sender] = _getCurrentSnapshotId();
            } else {
                uint256 lastSnap_ = _getCurrentSnapshotId();
                uint256 snapBalance = balanceOfAt(msg.sender, lastSnap_);
                uint256 amountToTransfer = (snapBalance * rewardConstant) / 1 ether;
                treasury.pay_reward(msg.sender, amountToTransfer);
                claimed[msg.sender] = _getCurrentSnapshotId();
            }
        }
    }

    function set_treasury(ITreasury _treasury) external onlyOwner {
        treasury = _treasury;
    }

    receive() external payable {}
}


// I would be doing something interesting.
// 