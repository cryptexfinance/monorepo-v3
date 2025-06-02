// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { TCAP } from "../src/TCAP.sol";

contract TCAPScript is Script {
  TCAP public tcap;

  function setUp() public {}

  function run() public {
    vm.startBroadcast();

    tcap = new TCAP();

    vm.stopBroadcast();
  }
}
