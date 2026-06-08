// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    address public owner;
    mapping(address => uint256) public balances;
    
    struct TopDepositor {
        address user;
        uint256 amount;
    }
    
    TopDepositor[3] public topDepositors;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);
    event TopDepositorUpdated(address indexed user, uint256 amount, uint256 position);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    receive() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        balances[msg.sender] += msg.value;
        
        updateTopDepositors(msg.sender, balances[msg.sender]);
        
        emit Deposit(msg.sender, msg.value);
    }
    
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        balances[msg.sender] += msg.value;
        
        updateTopDepositors(msg.sender, balances[msg.sender]);
        
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        payable(owner).transfer(amount);
        
        emit Withdrawal(owner, amount);
    }
    
    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Contract has no balance");
        
        payable(owner).transfer(balance);
        
        emit Withdrawal(owner, balance);
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getUserBalance(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function updateTopDepositors(address user, uint256 amount) internal {
        for (uint256 i = 0; i < 3; i++) {
            if (amount > topDepositors[i].amount) {
                for (uint256 j = 2; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = TopDepositor(user, amount);
                emit TopDepositorUpdated(user, amount, i);
                break;
            }
        }
    }
    
    function getTopDepositors() external view returns (TopDepositor[3] memory) {
        return topDepositors;
    }
}