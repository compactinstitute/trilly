// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {ts} from "src/main.sol";

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

library LibERC20Data {
    function init(ERC20Data storage) internal {
        // noop
    }

    function decimals(ERC20Data storage self) internal view returns (uint8) {
        return self.INT_decimals == 0 ? 18 : self.INT_decimals;
    }

    function totalSupply(ERC20Data storage self) internal view returns (uint256) {
        return self.INT_totalSupply;
    }

    function balanceOf(ERC20Data storage self, address account) internal view returns (uint256) {
        return self.INT_balanceOf[account];
    }

    function allowance(ERC20Data storage self, address owner, address spender) internal view returns (uint256) {
        return self.INT_allowances[owner][spender];
    }

    function transfer(ERC20Data storage self, address from, address to, uint256 value) internal returns (bool) {
        uint256 fromBalance = self.INT_balanceOf[from];
        require(fromBalance >= value, "ERC20: insufficient balance");
        require(to != address(0), "ERC20: transfer to zero address");

        self.INT_balanceOf[from] = fromBalance - value;
        self.INT_balanceOf[to] += value;

        emit Transfer(from, to, value);
        return true;
    }

    function approve(ERC20Data storage self, address owner, address spender, uint256 value) internal returns (bool) {
        require(spender != address(0), "ERC20: approve to zero address");
        self.INT_allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
        return true;
    }

    function transferFrom(ERC20Data storage self, address spender, address from, address to, uint256 value)
        internal
        returns (bool)
    {
        uint256 currentAllowance = self.INT_allowances[from][spender];
        require(currentAllowance >= value, "ERC20: insufficient allowance");

        self.INT_allowances[from][spender] = currentAllowance - value;

        return transfer(self, from, to, value);
    }

    function mint(ERC20Data storage self, address to, uint256 value) internal {
        require(to != address(0), "ERC20: mint to zero address");

        self.INT_totalSupply += value;
        self.INT_balanceOf[to] += value;

        emit Transfer(address(0), to, value);
    }

    function burn(ERC20Data storage self, address from, uint256 value) internal {
        uint256 fromBalance = self.INT_balanceOf[from];
        require(fromBalance >= value, "ERC20: burn amount exceeds balance");

        self.INT_totalSupply -= value;
        self.INT_balanceOf[from] = fromBalance - value;

        emit Transfer(from, address(0), value);
    }
}

struct ERC20Data {
    string name;
    string symbol;
    uint8 INT_decimals;
    uint256 INT_totalSupply;
    mapping(address => uint256) INT_balanceOf;
    mapping(address => mapping(address => uint256)) INT_allowances;
}

using LibERC20Data for ERC20Data global;

abstract contract TrillyERC20 {
    function name() external view virtual returns (string memory) {
        return ts.erc20().name;
    }

    function symbol() external view virtual returns (string memory) {
        return ts.erc20().symbol;
    }

    function decimals() external view virtual returns (uint8) {
        return ts.erc20().decimals();
    }

    function totalSupply() external view virtual returns (uint256) {
        return ts.erc20().totalSupply();
    }

    function balanceOf(address account) external view virtual returns (uint256) {
        return ts.erc20().balanceOf(account);
    }

    function transfer(address recipient, uint256 amount) external virtual returns (bool) {
        return ts.erc20().transfer(msg.sender, recipient, amount);
    }

    function allowance(address owner, address spender) external view virtual returns (uint256) {
        return ts.erc20().allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) external virtual returns (bool) {
        return ts.erc20().approve(msg.sender, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external virtual returns (bool) {
        return ts.erc20().transferFrom(msg.sender, sender, recipient, amount);
    }
}
