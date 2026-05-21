# Trilly

Trilly is an ergonomic library for building Ethereum applications.

Unaudited and not production-ready.

## Installation

```
bun install https://github.com/compactinstitute/trilly
```

When installing from the GitHub repository, you should add the following to your
`remappings.txt`:

```
trilly=node_modules/trilly/src/
```

## Usage

Trilly supports both composition and inheritance patterns. Composition makes it
your responsibility as a developer to expose the functions you want, while
inheritance handles this for you - though with slightly less freedom. The two
patterns are shown below.

```sol
import {ts} from "trilly/main.sol";
import {TrillyERC20} from "trilly/token/erc20.sol"

// Composition
contract TrillyDollar {
  constructor() {
    ERC20Data storage erc20 = ts.erc20();
    erc20.name = "Trilly Dollar";
    erc20.symbol = "TRD";
    erc20.mint(msg.sender, 21_000_000 ether);
  }

  function name() external view returns (string memory) {
    return ts.erc20().name;
  }

  function symbol() external view returns (string memory) {
    return ts.erc20().symbol;
  }

  function decimals() external view returns (uint8) {
    return ts.erc20().decimals();
  }
  
  function totalSupply() external view returns (uint256) {
    return ts.erc20().totalSupply();
  }

  function balanceOf(address account) external view returns (uint256) {
    return ts.erc20().balanceOf(account);
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
    return ts.erc20().transfer(msg.sender, recipient, amount);
  }
  
  function allowance(address owner, address spender) external view returns (uint256) {
    return ts.erc20().allowance(owner, spender);
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    return ts.erc20().approve(msg.sender, spender, amount);
  }

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    return ts.erc20().transferFrom(msg.sender, sender, recipient, amount);
  }
}

// Inheritance
contract TrillyDollar2 is TrillyERC20 {
  constructor() {
    ERC20Data storage erc20 = ts.erc20();

    erc20.name = "Trilly Dollar";
    erc20.symbol = "TRD";
    erc20.mint(msg.sender, 21_000_000 ether);
  }
}
```

## Contributing

Contributions accepted! Please either open a new issue for feature requests or
create a pull request to close an issue!

## License

Trilly is an explicitly ideological project in the service of Free Software.

Free Software is not a matter of price, but of freedom. It is the idea that the
operator of a given system has the natural right to use, modify and share their
code. In operating systems such as Microsoft Windows, you are restricted by law
from studying the source code: men with guns will come to your home and take you
away for releasing your changes, while they themselves rely on the work of many
thousands of permissive and unpaid maintainers.

Free Software is not a matter of practicality either. Often, we must accept that
much of the software of the modern world is built to restrict our freedom and
thus must reject their usage, making our lives harder in the short run in the
service of personal virtue - though in many cases, there exist Free programs
which perform similarly or even better to proprietary counterparts, and without
creating a culture of dependency on a given maintaining entity.

As such, Trilly is licensed under the **GNU General Public License 3.0** in
order to ensure the work, and all combined works, are as copylefted as possible
under law.

To the extent possible under law, [the copyrights and related or neighboring
rights to the documentation and art assets are fully waived](https://creativecommons.org/publicdomain/zero/1.0/).
