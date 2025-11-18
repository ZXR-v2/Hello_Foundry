// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/Contract.sol";

contract MyTokenTest is Test {
    MyToken private token;

    function setUp() public {
        token = new MyToken("MyToken", "MTK");
    }

    function testInitialSupplyAssignedToDeployer() public {
        assertEq(token.totalSupply(), token.balanceOf(address(this)));
    }

    function testNameAndSymbol() public {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
    }
}
