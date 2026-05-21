// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ts} from "src/main.sol";
import {TrillyERC20, ERC20Data, LibERC20Data} from "src/token/erc20.sol";

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

contract ERC20Wrapper is TrillyERC20 {
    constructor(string memory name_, string memory symbol_) {
        ERC20Data storage e = ts.erc20();
        e.name = name_;
        e.symbol = symbol_;
    }

    function mint(address to, uint256 value) external {
        ts.erc20().mint(to, value);
    }

    function burnFrom(address from, uint256 value) external {
        ts.erc20().burn(from, value);
    }
}

contract ERC20Test is Test {
    ERC20Wrapper token;
    address alice = address(0x420001);
    address bob = address(0x420002);
    address charlie = address(0x420003);

    function setUp() public {
        token = new ERC20Wrapper("TestToken", "TST");
        token.mint(alice, 1000);
        token.mint(bob, 500);
    }

    function test_metadata() public view {
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TST");
        assertEq(token.decimals(), 18);
    }

    function test_totalSupply() public view {
        assertEq(token.totalSupply(), 1500);
    }

    function test_balanceOf() public view {
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.balanceOf(bob), 500);
        assertEq(token.balanceOf(charlie), 0);
    }

    function test_transfer() public {
        vm.prank(alice);
        bool ok = token.transfer(bob, 300);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 700);
        assertEq(token.balanceOf(bob), 800);
    }

    function test_transfer_emitsTransferEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 300);
        token.transfer(bob, 300);
    }

    function test_transfer_zeroValue() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 0);
        bool ok = token.transfer(bob, 0);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.balanceOf(bob), 500);
    }

    function test_transfer_insufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient balance");
        token.transfer(bob, 2000);
    }

    function test_transfer_zeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("ERC20: transfer to zero address");
        token.transfer(address(0), 100);
    }

    function test_approve() public {
        vm.prank(alice);
        bool ok = token.approve(bob, 500);

        assertTrue(ok);
        assertEq(token.allowance(alice, bob), 500);
    }

    function test_approve_emitsApprovalEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 500);
        token.approve(bob, 500);
    }

    function test_approve_overwritesAllowance() public {
        vm.prank(alice);
        token.approve(bob, 500);
        assertEq(token.allowance(alice, bob), 500);

        vm.prank(alice);
        token.approve(bob, 300);
        assertEq(token.allowance(alice, bob), 300);
    }

    function test_transferFrom() public {
        vm.prank(alice);
        token.approve(bob, 400);

        vm.prank(bob);
        bool ok = token.transferFrom(alice, charlie, 400);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 600);
        assertEq(token.balanceOf(charlie), 400);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_transferFrom_emitsTransferEvent() public {
        vm.prank(alice);
        token.approve(bob, 400);

        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, charlie, 400);
        token.transferFrom(alice, charlie, 400);
    }

    function test_transferFrom_insufficientAllowance() public {
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        token.transferFrom(alice, charlie, 200);
    }

    function test_transferFrom_noAllowance() public {
        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        token.transferFrom(alice, charlie, 100);
    }

    function test_transferFrom_insufficientBalance() public {
        vm.prank(alice);
        token.approve(bob, 2000);

        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient balance");
        token.transferFrom(alice, charlie, 2000);
    }

    function test_allowance() public view {
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.allowance(alice, charlie), 0);
    }

    function test_allowanceAfterApprove() public {
        vm.prank(alice);
        token.approve(charlie, 777);
        assertEq(token.allowance(alice, charlie), 777);
    }

    function test_burn() public {
        token.burnFrom(alice, 300);
        assertEq(token.totalSupply(), 1200);
        assertEq(token.balanceOf(alice), 700);
    }

    function test_burn_exceedsBalance() public {
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burnFrom(alice, 2000);
    }
}
