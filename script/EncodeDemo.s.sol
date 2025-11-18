// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";

contract EncodeDemoScript is Script {
    function run() external {
        uint x = 10;
        address addr = 0x7A58c0Be72BE218B41C608b7Fe7C5bB630736C71;
        string memory name = "0xAA";
        uint[2] memory array = [uint(5), uint(6)];
        bytes memory result = abi.encode(x, addr, name, array);
        console.logBytes(result);
    }
}
