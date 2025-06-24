// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { Crypto40 } from "../src/Crypto40.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Crypto40Test is Test {
  Crypto40 public crypto40;
  address public OWNER = address(0x01);
  address public USER = address(0x02);
  address public USER2 = address(0x03);
  address public ADMIN = address(0x04);

  function setUp() public {
    crypto40 = new Crypto40(OWNER, ADMIN);
  }

  function test_constructor() public view {
    assertEq(crypto40.owner(), OWNER);
    assertEq(crypto40.name(), "Crypto40");
    assertEq(crypto40.symbol(), "CRYPTO40");
    assertEq(crypto40.decimals(), 18);
    assertEq(crypto40.totalSupply(), 0);
    assertEq(crypto40.admin(), ADMIN);
  }

  function test_onlyOwnerCanMint() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    crypto40.mint(USER, 1000);
  }

  function test_mint() public {
    vm.startPrank(OWNER);
    crypto40.mint(OWNER, 1000);
    assertEq(crypto40.balanceOf(OWNER), 1000);
    vm.stopPrank();
  }

  function test_onlyOwnerCanBurn() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    crypto40.burn(USER, 1000);
  }

  function test_burn() public {
    vm.startPrank(OWNER);
    crypto40.mint(OWNER, 1000);
    crypto40.burn(OWNER, 1000);
    vm.stopPrank();
    assertEq(crypto40.transferable(), false);
  }

  function test_tokenCanNotBeTransferred() public {
    vm.startPrank(OWNER);
    crypto40.mint(OWNER, 1000);
    vm.expectRevert(Crypto40.NotTransferable.selector);
    crypto40.transfer(USER, 1000);
    vm.stopPrank();
  }

  function test_tokenscanNotBeTransferredFrom() public {
    vm.startPrank(OWNER);
    crypto40.mint(OWNER, 1000);
    crypto40.approve(USER, 1000);
    vm.stopPrank();
    vm.startPrank(USER);
    vm.expectRevert(Crypto40.NotTransferable.selector);
    crypto40.transferFrom(OWNER, USER, 1000);
    vm.stopPrank();
  }

  function test_onlyAdminCanSetTransferable() public {
    vm.expectRevert(abi.encodeWithSelector(Crypto40.NotAdmin.selector, address(this)));
    crypto40.setTransferable(true);
  }

  function test_adminCanEnableTransfer() public {
    vm.prank(OWNER);
    crypto40.mint(ADMIN, 1000);
    vm.startPrank(ADMIN);
    crypto40.setTransferable(true);
    assertEq(crypto40.transferable(), true);
    crypto40.transfer(USER, 1000);
    vm.stopPrank();
    assertEq(crypto40.balanceOf(USER), 1000);
    assertEq(crypto40.balanceOf(ADMIN), 0);
    vm.prank(USER);
    crypto40.approve(USER2, 1000);
    vm.prank(USER2);
    crypto40.transferFrom(USER, USER2, 1000);
    assertEq(crypto40.balanceOf(USER2), 1000);
    assertEq(crypto40.balanceOf(USER), 0);
    assertEq(crypto40.allowance(USER, USER2), 0);
  }

  function test_ownerCanDisableTransfer() public {
    vm.startPrank(ADMIN);
    crypto40.setTransferable(false);
    vm.stopPrank();
    assertEq(crypto40.transferable(), false);
  }
}
