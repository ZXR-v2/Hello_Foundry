// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();

        // 部署 Counter 合约
        Counter counter = new Counter();
        console.log("Counter deployed at:", address(counter));

        // 部署 MyERC20 合约，初始供应量 1000 * 10^18
        // uint256 initialSupply = 1000e18;
        string memory name = vm.envOr("TOKEN_NAME", string("MyToken"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("MTK"));
        MyERC20 token = new MyERC20(name, symbol);
        console.log("MyERC20 deployed at:", address(token));

        vm.stopBroadcast();
    }
}