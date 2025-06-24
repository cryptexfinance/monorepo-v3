// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface ISettler {
  event OrderCreated(
    int256 orderId,
    address user,
    uint256 nonce,
    uint256 minReceived,
    address inputToken,
    uint256 amount,
    uint32 openDeadline,
    uint32 fillDeadline
  );
  event OrderCancelled(int256 orderId, address user, uint256 nonce);
  event OrderTaken(int256 orderId, address user, uint256 nonce);
  event OrderFilled(int256 orderId, address marketMaker, uint256 nonce);
  error DeviationTooHigh();
  error OnlyAdmin();
  error OnlyGuardian();
  error OnlyAllowedInstitutions();
  error OnlyAllowedMarketMakers();
  error NotOrderOwner();
  error OrderExpired();
  error OrderIsFilling();
  function setInstitutionStatus(address _institution, bool _status) external;
  function setMarketMakerStatus(address _marketMaker, bool _status) external;
  function setPaused(bool _paused) external;
  function setOpenDeadlineConfig(uint256 _openDeadlineConfig) external;
  function setFillDeadlineConfig(uint256 _fillDeadlineConfig) external;
  function createOrder(address _inputToken, uint256 _amount) external;
  function cancelOrder(int256 _orderId) external;
  function takeOrder(int256 _orderId) external;
  function fillOrder(int256 _orderId) external;
  function updateOrderStatus(int256 _orderId) external;
}
