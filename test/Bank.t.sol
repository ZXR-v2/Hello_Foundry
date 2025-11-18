// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank internal bank;
    address internal alice;
    address internal bob;
    address internal carol;
    address internal dave;

    // Allow the Bank contract to send ETH back to this test (owner) during withdraw
    receive() external payable {}

    function setUp() public {
        bank = new Bank();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");
    }

    function testDepositTracksBalancesAndTotals() public {
        _deposit(alice, 1 ether);
        assertEq(bank.balances(alice), 1 ether);
        assertEq(bank.total(), 1 ether);

        _deposit(alice, 0.5 ether);
        assertEq(bank.balances(alice), 1.5 ether);
        assertEq(bank.total(), 1.5 ether);
    }

    function testReceiveTracksDirectWalletTransfer() public {
        vm.deal(alice, 2 ether);

        vm.prank(alice);
        (bool success, ) = address(bank).call{value: 2 ether}("");
        assertTrue(success, "Direct transfer failed");

        assertEq(bank.balances(alice), 2 ether);
        assertEq(bank.total(), 2 ether);

        address[3] memory leaderboard = bank.top3();
        assertEq(leaderboard[0], alice);
    }

    function testLeaderboardForOneToFourUsers() public {
        _deposit(alice, 1 ether);
        address[3] memory board = bank.top3();
        assertEq(board[0], alice);
        assertEq(board[1], address(0));
        assertEq(board[2], address(0));

        _deposit(bob, 2 ether);
        board = bank.top3();
        assertEq(board[0], bob);
        assertEq(board[1], alice);

        _deposit(carol, 1.5 ether);
        board = bank.top3();
        assertEq(board[0], bob);
        assertEq(board[1], carol);
        assertEq(board[2], alice);

        _deposit(dave, 3 ether);
        board = bank.top3();
        assertEq(board[0], dave);
        assertEq(board[1], bob);
        assertEq(board[2], carol);
    }

    function testLeaderboardUpdatesWhenUserDepositsAgain() public {
        _deposit(alice, 1 ether);
        _deposit(bob, 2 ether);
        _deposit(carol, 1.5 ether);
        _deposit(dave, 0.5 ether);

        _deposit(alice, 3 ether);
        address[3] memory board = bank.top3();
        assertEq(board[0], alice);
        assertEq(board[1], bob);
        assertEq(board[2], carol);

        _deposit(carol, 5 ether);
        board = bank.top3();
        assertEq(board[0], carol);
        assertEq(board[1], alice);
        assertEq(board[2], bob);
    }

    function testOnlyOwnerCanWithdraw() public {
        _deposit(alice, 3 ether);
        _deposit(bob, 1 ether);

        uint256 ownerBalanceBefore = address(this).balance;
        bank.withdraw(2 ether);
        assertEq(address(this).balance, ownerBalanceBefore + 2 ether);
        assertEq(bank.total(), 2 ether);

        vm.prank(alice);
        vm.expectRevert("Caller is not owner");
        bank.withdraw(1 ether);
    }

    function _deposit(address depositor, uint256 amount) internal {
        vm.deal(depositor, amount);
        vm.prank(depositor);
        bank.deposit{value: amount}(depositor);
    }
}
