// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract MyTokenScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // 构造函数参数：name, symbol
        string memory name_ = "My Sepolia Token";
        string memory symbol_ = "MST";

        vm.startBroadcast(pk);
        MyToken token = new MyToken(name_, symbol_);
        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(token));
    }
}