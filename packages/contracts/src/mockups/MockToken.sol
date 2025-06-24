// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
  uint8 public immutable overridaDecimals;

  constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol) {
    overridaDecimals = _decimals;
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function decimals() public view override returns (uint8) {
    return overridaDecimals;
  }
}
