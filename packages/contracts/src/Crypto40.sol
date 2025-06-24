// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Crypto40 is ERC20, Ownable {
  error NotTransferable();
  error NotAdmin();

  bool public transferable;
  address public admin;

  modifier onlyAdmin() {
    if (msg.sender != admin) revert NotAdmin();
    _;
  }

  constructor(address _owner, address _admin) ERC20("Crypto40", "CRYPTO40") Ownable(_owner) {
    transferable = false;
    admin = _admin;
  }

  function mint(address _to, uint256 _amount) external onlyOwner {
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external onlyOwner {
    _burn(_from, _amount);
  }

  function transfer(address _to, uint256 _amount) public override returns (bool) {
    if (!transferable) revert NotTransferable();
    return super.transfer(_to, _amount);
  }

  function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
    if (!transferable) revert NotTransferable();
    return super.transferFrom(_from, _to, _amount);
  }

  function setTransferable(bool _transferable) external onlyAdmin {
    transferable = _transferable;
  }
}
