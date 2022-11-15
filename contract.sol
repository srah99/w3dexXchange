// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakeToken is Pausable, Ownable, ReentrancyGuard {
    IERC20 token; //Link token address

    AggregatorV3Interface internal priceFeed;
    
    // 90 Days
    uint256 public constant MIN_STAKING_DAYS = 7776000;

    uint16 public interestRate;
    uint256 public extratime = 604800;

    struct StakeInfo {        
        uint256 startTS;
        uint256 endTS;        
        uint256 amount; 
        uint256 stakingDays;
        bool claimed;
        uint256 fee;
        uint256 interest;
        uint256 initialPrice; 
        uint256 finalPrice;
        uint256 finalAmount;
    }
    
    event Staked(address indexed from, uint256 amount);
    event Claimed(address indexed from, uint256 amount);
    
    mapping(address => StakeInfo[]) public stakeInfos;
    mapping(address => bool) public addressStaked;

    constructor(address _tokenAddress, uint16 _interestRate, address _priceFeed) {
        require(address(_tokenAddress) != address(0),"Token Address cannot be address 0");   
        token = IERC20(_tokenAddress);
        setInterestRate(_interestRate);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function transferToken(address to, uint256 amount) external onlyOwner{
        require(token.transfer(to, amount), "Token transfer failed!");
    }

    function getAmountStaked() public view returns(uint256) {
        require (addressStaked[_msgSender()] == true, "You are not participated");

        return stakeInfos[msg.sender][stakeInfos[msg.sender].length - 1].amount;
    }

    function claimReward(address _to) external nonReentrant returns (bool){
        require(addressStaked[_to] == true, "You are not participated");
        require(stakeInfos[_to][stakeInfos[msg.sender].length - 1].endTS < block.timestamp, "Stake Time is not over yet");
        require(stakeInfos[_to][stakeInfos[msg.sender].length - 1].claimed == false, "Already claimed");

        if (stakeInfos[_to][stakeInfos[msg.sender].length - 1].endTS + extratime > block.timestamp) {
            stakeInfos[_to][stakeInfos[msg.sender].length - 1].finalPrice = getLatestPrice();
            uint256 stakeAmount = stakeInfos[_to][stakeInfos[msg.sender].length - 1].amount;
            
            uint256 totalTokens = stakeAmount + tokensToPay(_to);
            
            stakeInfos[_to][stakeInfos[msg.sender].length - 1].finalAmount = totalTokens;

            token.transfer(_to, totalTokens);
            
            emit Claimed(_to, totalTokens);
        }
        else {
            stakeInfos[_to][stakeInfos[msg.sender].length - 1].claimed = true;
            addressStaked[_msgSender()] = false;

            return false;
        }

        return true;
    }

    function getTokenExpiry() external view returns (uint256) {
        require(addressStaked[_msgSender()] == true, "You are not participated");

        return stakeInfos[_msgSender()][stakeInfos[msg.sender].length - 1].endTS;
    }

    // stakeAmount must be scale by a factor of 10^18, that is we are working with microTokensToStake
    function stakeToken(uint256 microTokensToStake, uint256 _stakingDays) external nonReentrant {
        require(microTokensToStake > 0, "Stake amount should be correct");
        require(_stakingDays >= MIN_STAKING_DAYS , "Staking days must be greaten than min expired");
        require(addressStaked[_msgSender()] == false, "You already participated");

        token.transferFrom(_msgSender(), address(this), microTokensToStake);
        
        addressStaked[_msgSender()] = true;

        uint256 fee = getFee(_stakingDays);

        StakeInfo memory stakeInfo;

        stakeInfo.startTS = block.timestamp;
        stakeInfo.endTS = block.timestamp + _stakingDays;
        stakeInfo.amount = microTokensToStake;
        stakeInfo.stakingDays = _stakingDays / 86400;
        stakeInfo.claimed = false;
        stakeInfo.fee = fee;
        stakeInfo.interest = interestRate;
        stakeInfo.initialPrice = getLatestPrice();
        stakeInfo.finalPrice = getLatestPrice();
        stakeInfo.finalAmount = 0;

        stakeInfos[_msgSender()].push(stakeInfo);
        
        emit Staked(_msgSender(), microTokensToStake);
    }

    function getFee(uint256 _stakingDays) internal pure returns(uint256) {
        uint256 _fee;

        if (_stakingDays <= 15552000) {
            _fee = 50;
        }
        else if (_stakingDays > 15552000 && _stakingDays <= 31536000) {
            _fee = 30;
        }
        else {
            _fee = 0;
        }

        return _fee;
    }

    function setInterestRate(uint16 _interestRate) public onlyOwner{
        interestRate = _interestRate;
    }

    function getInterestRate() external view returns(uint256) {
        return interestRate;
    }

    function getLatestPrice() internal view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();

        return uint256(latestPrice);
    }

    function calculationOfTheAmountOfInterest(address _user) public view returns(uint256){
        require (addressStaked[_msgSender()] == true, "you are not participated");

        uint256 _stakeAmount = stakeInfos[_user][stakeInfos[msg.sender].length - 1].amount;
        uint256 _interestRate = stakeInfos[_user][stakeInfos[msg.sender].length - 1].interest;
        uint256 _stakingDays = stakeInfos[_user][stakeInfos[msg.sender].length - 1].stakingDays;
        // return _stakeAmount * _interestRate/10000 * stakingDays/365;
        
        //_interestRate is yearly
        return (_stakeAmount * _interestRate * _stakingDays) / 100 * 365;
    }

    // IF we trade BTCUSD, we will need to read prices from chainlink oracles

    function tokenCalculationToCoverDepreciation(address _user) internal view returns(uint256){
        require (addressStaked[_msgSender()] == true, "you are not participated");

        uint256 _stakeAmount = stakeInfos[_user][stakeInfos[msg.sender].length - 1].amount;
        uint256 _initialPrice = stakeInfos[_user][stakeInfos[msg.sender].length - 1].initialPrice;
        uint256 _finalPrice = stakeInfos[_user][stakeInfos[msg.sender].length - 1].finalPrice;

        return (_stakeAmount * (_initialPrice - _finalPrice)) / _finalPrice;
    }

    function tokensToPay(address _user) internal view returns(uint256){
        uint256 _initialPrice = stakeInfos[_user][stakeInfos[msg.sender].length - 1].initialPrice;
        uint256 _finalPrice = stakeInfos[_user][stakeInfos[msg.sender].length - 1].finalPrice;
        uint256 tokensNeededForDepreciation = tokenCalculationToCoverDepreciation(_user);
        uint256 interestAmount = calculationOfTheAmountOfInterest(_user);

        uint256 max;
    
        if (_initialPrice >= _finalPrice){
            if (tokensNeededForDepreciation > interestAmount){
                max = tokensNeededForDepreciation - (tokensNeededForDepreciation * stakeInfos[_user][stakeInfos[msg.sender].length - 1].fee / 1000);
            } else {
                max = interestAmount - (interestAmount * stakeInfos[_user][stakeInfos[msg.sender].length - 1].fee / 1000);
            }
        } else {
            max = interestAmount - (interestAmount * stakeInfos[_user][stakeInfos[msg.sender].length - 1].fee / 1000);
        }

        return max;
    }
}
