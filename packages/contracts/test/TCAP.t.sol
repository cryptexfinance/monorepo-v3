// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { TCAP } from "../src/TCAP.sol";

contract TCAPTest is Test {
  TCAP public tcap;

  function setUp() public {
    tcap = new TCAP();
  }
}
