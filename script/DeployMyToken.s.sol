// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "src/Contract.sol";

contract DeployMyToken is Script {
    function run() external returns (MyToken token) {
        string memory name = vm.envOr("TOKEN_NAME", string("MyToken"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("MTK"));

        vm.startBroadcast();
        token = new MyToken(name, symbol);
        vm.stopBroadcast();
    }
}
