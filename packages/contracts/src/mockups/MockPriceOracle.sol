// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceOracle is AggregatorV3Interface {
  int256 public price = 25000000000;

  function getLatestRoundData() public view returns (int256) {
    return price;
  }

  function setPrice(int256 _price) public {
    price = _price;
  }

  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
    return (0, price, 0, 0, 0);
  }

  function latestRoundData()
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (0, price, 0, 0, 0);
  }

  function decimals() public view returns (uint8) {
    return 8;
  }

  function description() public view returns (string memory) {
    return "Mock Price Oracle";
  }

  function version() public view returns (uint256) {
    return 1;
  }
}
