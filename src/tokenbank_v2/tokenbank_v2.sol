// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./MyToken.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TokenBank {
    address public owner;
    IERC20 public token;
    
    mapping(address => uint256) public deposits;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);
    
    constructor(address _tokenAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        deposits[msg.sender] += _amount;
        
        emit Deposit(msg.sender, _amount);
    }
    
    function withdraw() external onlyOwner {
        uint256 totalBalance = token.balanceOf(address(this));
        require(totalBalance > 0, "No tokens to withdraw");
        
        require(token.transfer(owner, totalBalance), "Transfer failed");
        
        emit Withdraw(owner, totalBalance);
    }
    
    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    function getUserDeposit(address _user) external view returns (uint256) {
        return deposits[_user];
    }
}

contract TokenBankV2 is TokenBank, ITokenReceiver {
    event DepositViaCallback(address indexed user, uint256 amount);
    
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {}
    
    function tokensReceived(address _sender, address _from, uint256 _amount, bytes calldata _data) external override {
        require(msg.sender == address(token), "Only supported token can call this");
        
        deposits[_from] += _amount;
        
        emit Deposit(_from, _amount);
        emit DepositViaCallback(_from, _amount);
    }
}