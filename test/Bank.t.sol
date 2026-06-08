// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    receive() external payable {}

    function setUp() public {
        bank = new Bank();
        vm.deal(address(this), 1000 ether);
    }

    function test_deposit_updates_user_balance() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 200 ether);
        
        uint256 initialBalance = bank.getUserBalance(alice);
        assertEq(initialBalance, 0, "Initial balance should be 0");
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        uint256 finalBalance = bank.getUserBalance(alice);
        assertEq(finalBalance, 100 ether, "Balance should be 100 ether after deposit");
        
        vm.prank(alice);
        bank.deposit{value: 50 ether}();
        
        uint256 secondBalance = bank.getUserBalance(alice);
        assertEq(secondBalance, 150 ether, "Balance should be 150 ether after second deposit");
    }

    function test_receive_function_updates_balance() public {
        address bob = makeAddr("bob");
        vm.deal(bob, 200 ether);
        
        uint256 initialBalance = bank.getUserBalance(bob);
        assertEq(initialBalance, 0, "Initial balance should be 0");
        
        vm.prank(bob);
        (bool success, ) = address(bank).call{value: 200 ether}("");
        assertTrue(success, "Receive call should succeed");
        
        uint256 finalBalance = bank.getUserBalance(bob);
        assertEq(finalBalance, 200 ether, "Balance should be 200 ether after receive");
    }

    function test_top_depositors_with_1_user() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        Bank.TopDepositor[3] memory topDepositors = bank.getTopDepositors();
        
        assertEq(topDepositors[0].user, alice, "First top depositor should be alice");
        assertEq(topDepositors[0].amount, 100 ether, "First top amount should be 100 ether");
        assertEq(topDepositors[1].user, address(0), "Second top depositor should be empty");
        assertEq(topDepositors[1].amount, 0, "Second top amount should be 0");
        assertEq(topDepositors[2].user, address(0), "Third top depositor should be empty");
        assertEq(topDepositors[2].amount, 0, "Third top amount should be 0");
    }

    function test_top_depositors_with_2_users() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 200 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        bank.deposit{value: 200 ether}();
        
        Bank.TopDepositor[3] memory topDepositors = bank.getTopDepositors();
        
        assertEq(topDepositors[0].user, bob, "First top depositor should be bob");
        assertEq(topDepositors[0].amount, 200 ether, "First top amount should be 200 ether");
        assertEq(topDepositors[1].user, alice, "Second top depositor should be alice");
        assertEq(topDepositors[1].amount, 100 ether, "Second top amount should be 100 ether");
        assertEq(topDepositors[2].user, address(0), "Third top depositor should be empty");
        assertEq(topDepositors[2].amount, 0, "Third top amount should be 0");
    }

    function test_top_depositors_with_3_users() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 200 ether);
        vm.deal(charlie, 150 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        bank.deposit{value: 200 ether}();
        
        vm.prank(charlie);
        bank.deposit{value: 150 ether}();
        
        Bank.TopDepositor[3] memory topDepositors = bank.getTopDepositors();
        
        assertEq(topDepositors[0].user, bob, "First top depositor should be bob");
        assertEq(topDepositors[0].amount, 200 ether, "First top amount should be 200 ether");
        assertEq(topDepositors[1].user, charlie, "Second top depositor should be charlie");
        assertEq(topDepositors[1].amount, 150 ether, "Second top amount should be 150 ether");
        assertEq(topDepositors[2].user, alice, "Third top depositor should be alice");
        assertEq(topDepositors[2].amount, 100 ether, "Third top amount should be 100 ether");
    }

    function test_top_depositors_with_4_users() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");
        address dave = makeAddr("dave");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 200 ether);
        vm.deal(charlie, 150 ether);
        vm.deal(dave, 250 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        bank.deposit{value: 200 ether}();
        
        vm.prank(charlie);
        bank.deposit{value: 150 ether}();
        
        vm.prank(dave);
        bank.deposit{value: 250 ether}();
        
        Bank.TopDepositor[3] memory topDepositors = bank.getTopDepositors();
        
        assertEq(topDepositors[0].user, dave, "First top depositor should be dave");
        assertEq(topDepositors[0].amount, 250 ether, "First top amount should be 250 ether");
        assertEq(topDepositors[1].user, bob, "Second top depositor should be bob");
        assertEq(topDepositors[1].amount, 200 ether, "Second top amount should be 200 ether");
        assertEq(topDepositors[2].user, charlie, "Third top depositor should be charlie");
        assertEq(topDepositors[2].amount, 150 ether, "Third top amount should be 150 ether");
    }

    function test_top_depositors_same_user_multiple_deposits() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");
        vm.deal(alice, 300 ether);
        vm.deal(bob, 200 ether);
        vm.deal(charlie, 150 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        bank.deposit{value: 200 ether}();
        
        vm.prank(charlie);
        bank.deposit{value: 150 ether}();
        
        vm.prank(alice);
        bank.deposit{value: 200 ether}();
        
        Bank.TopDepositor[3] memory topDepositors = bank.getTopDepositors();
        
        assertEq(topDepositors[0].user, alice, "First top depositor should be alice after second deposit");
        assertEq(topDepositors[0].amount, 300 ether, "First top amount should be 300 ether");
        assertEq(topDepositors[1].user, bob, "Second top depositor should be bob");
        assertEq(topDepositors[1].amount, 200 ether, "Second top amount should be 200 ether");
        assertEq(topDepositors[2].user, charlie, "Third top depositor should be charlie");
        assertEq(topDepositors[2].amount, 150 ether, "Third top amount should be 150 ether");
    }

    function test_owner_can_withdraw() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        uint256 initialContractBalance = bank.getContractBalance();
        assertEq(initialContractBalance, 100 ether, "Contract balance should be 100 ether");
        
        uint256 initialOwnerBalance = address(this).balance;
        
        bank.withdraw(50 ether);
        
        uint256 finalContractBalance = bank.getContractBalance();
        assertEq(finalContractBalance, 50 ether, "Contract balance should be 50 ether after withdrawal");
        
        uint256 finalOwnerBalance = address(this).balance;
        assertEq(finalOwnerBalance, initialOwnerBalance + 50 ether, "Owner balance should increase by 50 ether");
    }

    function test_owner_can_withdraw_all() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        uint256 initialOwnerBalance = address(this).balance;
        
        bank.withdrawAll();
        
        uint256 finalContractBalance = bank.getContractBalance();
        assertEq(finalContractBalance, 0, "Contract balance should be 0 after withdrawAll");
        
        uint256 finalOwnerBalance = address(this).balance;
        assertEq(finalOwnerBalance, initialOwnerBalance + 100 ether, "Owner balance should increase by 100 ether");
    }

    function test_non_owner_cannot_withdraw() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        vm.expectRevert("Only owner can call this function");
        bank.withdraw(50 ether);
    }

    function test_non_owner_cannot_withdraw_all() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.prank(bob);
        vm.expectRevert("Only owner can call this function");
        bank.withdrawAll();
    }

    function test_deposit_zero_amount_reverts() public {
        address alice = makeAddr("alice");
        
        vm.prank(alice);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit{value: 0}();
    }

    function test_withdraw_zero_amount_reverts() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.expectRevert("Withdrawal amount must be greater than 0");
        bank.withdraw(0);
    }

    function test_withdraw_insufficient_balance_reverts() public {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);
        
        vm.prank(alice);
        bank.deposit{value: 100 ether}();
        
        vm.expectRevert("Insufficient contract balance");
        bank.withdraw(200 ether);
    }

    function test_withdraw_all_empty_contract_reverts() public {
        vm.expectRevert("Contract has no balance");
        bank.withdrawAll();
    }
}