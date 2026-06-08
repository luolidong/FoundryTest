// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/tokenbank_v2/mytoken.sol";

contract MyTokenTest is Test {
    MyToken public token;

    function setUp() public {
        token = new MyToken();
    }

    function test_transfer_basic_functionality() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        
        uint256 initialSupply = token.totalSupply();
        
        // 部署者应该有全部代币
        assertEq(token.balanceOf(address(this)), initialSupply);
        
        // 转账给 alice
        uint256 transferAmount = 1000 * 10**18;
        token.transfer(alice, transferAmount);
        
        assertEq(token.balanceOf(address(this)), initialSupply - transferAmount);
        assertEq(token.balanceOf(alice), transferAmount);
        
        // alice 转账给 bob
        vm.prank(alice);
        uint256 aliceTransferAmount = 500 * 10**18;
        token.transfer(bob, aliceTransferAmount);
        
        assertEq(token.balanceOf(alice), transferAmount - aliceTransferAmount);
        assertEq(token.balanceOf(bob), aliceTransferAmount);
        
        // 总量保持不变
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_transferFrom_functionality() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");
        
        uint256 initialSupply = token.totalSupply();
        
        // 部署者转账给 alice
        uint256 transferAmount = 1000 * 10**18;
        token.transfer(alice, transferAmount);
        
        // alice 授权 charlie 花费代币
        vm.prank(alice);
        uint256 approveAmount = 500 * 10**18;
        token.approve(charlie, approveAmount);
        
        assertEq(token.allowance(alice, charlie), approveAmount);
        
        // charlie 从 alice 转账给 bob
        vm.prank(charlie);
        uint256 transferFromAmount = 300 * 10**18;
        token.transferFrom(alice, bob, transferFromAmount);
        
        assertEq(token.balanceOf(alice), transferAmount - transferFromAmount);
        assertEq(token.balanceOf(bob), transferFromAmount);
        assertEq(token.allowance(alice, charlie), approveAmount - transferFromAmount);
        
        // 总量保持不变
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_insufficient_balance_transfer_reverts() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        
        // alice 没有代币，尝试转账应该失败
        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        token.transfer(bob, 100 * 10**18);
    }

    function test_ten_addresses_transfer_preserves_total_supply() public {
        address[10] memory addresses;
        
        // 创建10个测试地址
        for (uint256 i = 0; i < 10; i++) {
            addresses[i] = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
        }
        
        uint256 initialSupply = token.totalSupply();
        
        // 部署者分发代币给10个地址
        uint256 distributeAmount = initialSupply / 10;
        for (uint256 i = 0; i < 10; i++) {
            token.transfer(addresses[i], distributeAmount);
        }
        
        // 验证每个地址都收到了代币
        for (uint256 i = 0; i < 10; i++) {
            assertEq(token.balanceOf(addresses[i]), distributeAmount);
        }
        
        // 执行多次随机转账
        // 转账1: 0 -> 1, 100 tokens
        vm.prank(addresses[0]);
        token.transfer(addresses[1], 100 * 10**18);
        
        // 转账2: 1 -> 2, 200 tokens
        vm.prank(addresses[1]);
        token.transfer(addresses[2], 200 * 10**18);
        
        // 转账3: 2 -> 3, 150 tokens
        vm.prank(addresses[2]);
        token.transfer(addresses[3], 150 * 10**18);
        
        // 转账4: 3 -> 4, 300 tokens
        vm.prank(addresses[3]);
        token.transfer(addresses[4], 300 * 10**18);
        
        // 转账5: 4 -> 5, 100 tokens
        vm.prank(addresses[4]);
        token.transfer(addresses[5], 100 * 10**18);
        
        // 转账6: 5 -> 6, 250 tokens
        vm.prank(addresses[5]);
        token.transfer(addresses[6], 250 * 10**18);
        
        // 转账7: 6 -> 7, 180 tokens
        vm.prank(addresses[6]);
        token.transfer(addresses[7], 180 * 10**18);
        
        // 转账8: 7 -> 8, 120 tokens
        vm.prank(addresses[7]);
        token.transfer(addresses[8], 120 * 10**18);
        
        // 转账9: 8 -> 9, 200 tokens
        vm.prank(addresses[8]);
        token.transfer(addresses[9], 200 * 10**18);
        
        // 转账10: 9 -> 0, 150 tokens
        vm.prank(addresses[9]);
        token.transfer(addresses[0], 150 * 10**18);
        
        // 验证总量保持不变
        assertEq(token.totalSupply(), initialSupply);
        
        // 验证所有地址余额总和等于总量
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < 10; i++) {
            totalBalance += token.balanceOf(addresses[i]);
        }
        totalBalance += token.balanceOf(address(this));
        
        assertEq(totalBalance, initialSupply);
    }

    function test_self_transfer() public {
        address alice = makeAddr("alice");
        uint256 initialSupply = token.totalSupply();
        
        // 部署者转账给 alice
        uint256 transferAmount = 1000 * 10**18;
        token.transfer(alice, transferAmount);
        
        // alice 给自己转账
        vm.prank(alice);
        uint256 selfTransferAmount = 500 * 10**18;
        bool success = token.transfer(alice, selfTransferAmount);
        
        assertTrue(success);
        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_transfer_zero_amount() public {
        address alice = makeAddr("alice");
        
        // 转账0个代币应该成功
        bool success = token.transfer(alice, 0);
        assertTrue(success);
    }
}