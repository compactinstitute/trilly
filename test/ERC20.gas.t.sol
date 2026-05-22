// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ERC20 as OZERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ts} from "src/main.sol";
import {TrillyERC20, ERC20Data, LibERC20Data} from "src/token/erc20.sol";

contract OZERC20Wrapper is OZERC20 {
    constructor(string memory name_, string memory symbol_) OZERC20(name_, symbol_) {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    function burnFrom(address from, uint256 value) external {
        _burn(from, value);
    }
}

contract TrillyERC20Wrapper is TrillyERC20 {
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

contract ERC20GasBenchmark is Test {
    OZERC20Wrapper ozToken;
    TrillyERC20Wrapper trillyToken;

    address alice = address(0x420001);
    address bob = address(0x420002);
    address charlie = address(0x420003);

    function setUp() public {
        ozToken = new OZERC20Wrapper("TestToken", "TST");
        trillyToken = new TrillyERC20Wrapper("TestToken", "TST");

        ozToken.mint(alice, 1000);
        trillyToken.mint(alice, 1000);

        vm.prank(alice);
        ozToken.approve(bob, 400);
        vm.prank(alice);
        trillyToken.approve(bob, 400);
    }

    function test_gas_deploy_oz() public {
        new OZERC20Wrapper("TestToken", "TST");
    }

    function test_gas_deploy_trilly() public {
        new TrillyERC20Wrapper("TestToken", "TST");
    }

    function test_gas_mint_oz() public {
        ozToken.mint(bob, 500);
    }

    function test_gas_mint_trilly() public {
        trillyToken.mint(bob, 500);
    }

    function test_gas_transfer_oz() public {
        vm.prank(alice);
        ozToken.transfer(bob, 300);
    }

    function test_gas_transfer_trilly() public {
        vm.prank(alice);
        trillyToken.transfer(bob, 300);
    }

    function test_gas_approve_oz() public {
        vm.prank(alice);
        ozToken.approve(charlie, 500);
    }

    function test_gas_approve_trilly() public {
        vm.prank(alice);
        trillyToken.approve(charlie, 500);
    }

    function test_gas_transferFrom_oz() public {
        vm.prank(bob);
        ozToken.transferFrom(alice, charlie, 200);
    }

    function test_gas_transferFrom_trilly() public {
        vm.prank(bob);
        trillyToken.transferFrom(alice, charlie, 200);
    }

    function test_gas_burn_oz() public {
        ozToken.burnFrom(alice, 300);
    }

    function test_gas_burn_trilly() public {
        trillyToken.burnFrom(alice, 300);
    }
}
