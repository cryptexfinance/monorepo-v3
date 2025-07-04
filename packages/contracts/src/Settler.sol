// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { ISettler } from "./interfaces/ISettler.sol";

contract Settler is Ownable, Nonces, ISettler {
  enum OrderStatus {
    OPEN,
    FILLING,
    FILLED,
    CANCELLED,
    EXPIRED
  }

  struct Order {
    int256 orderId;
    uint256 minReceived;
    uint256 nonce;
    address user;
    address inputToken;
    uint256 deposit;
    uint32 openDeadline;
    uint32 fillDeadline;
  }

  address public immutable GUARDIAN;
  IERC20 public immutable TOKEN;
  AggregatorV3Interface public immutable TOKEN_PRICE_ORACLE;
  AggregatorV3Interface public immutable PROOF_OF_RESERVES_ORACLE;
  uint256 public openDeadlineConfig;
  uint256 public fillDeadlineConfig;
  mapping(address => bool) public allowedInstitutions;
  mapping(address => bool) public allowedMarketMakers;
  mapping(int256 => Order) public orders;
  /// @notice Tracks the used nonces for each address.
  mapping(address => mapping(uint256 => bool)) public usedNonces;
  /// @notice Tracks filled orders and their associated data.
  // mapping(bytes32 orderId => FilledOrder filledOrder) public filledOrders;
  /// @notice Tracks the cancelled orders and their associated data.
  mapping(int256 orderId => Order cancelledOrder) public cancelledOrders;
  /// @notice Tracks the status of each order by its ID.
  mapping(int256 orderId => OrderStatus status) public orderStatus;
  bool public paused;
  int256 public currentOrderId;
  uint256 public deviation;

  modifier onlyAdmin() {
    if (msg.sender != owner()) revert OnlyAdmin();
    _;
  }

  modifier onlyGuardian() {
    if (msg.sender != GUARDIAN) revert OnlyGuardian();
    _;
  }

  modifier onlyAllowedInstitutions() {
    if (!allowedInstitutions[msg.sender]) revert OnlyAllowedInstitutions();
    _;
  }

  modifier onlyAllowedMarketMakers() {
    if (!allowedMarketMakers[msg.sender]) revert OnlyAllowedMarketMakers();
    _;
  }

  modifier notExpired(int256 _orderId) {
    if (
      orderStatus[_orderId] == OrderStatus.EXPIRED ||
      block.timestamp > orders[_orderId].openDeadline ||
      block.timestamp > orders[_orderId].fillDeadline
    ) revert OrderExpired();
    _;
  }

  constructor(
    address _ADMIN,
    address _GUARDIAN,
    IERC20 _TOKEN,
    AggregatorV3Interface _TOKEN_PRICE_ORACLE,
    AggregatorV3Interface _PROOF_OF_RESERVES_ORACLE,
    uint256 _openDeadlineConfig,
    uint256 _fillDeadlineConfig,
    uint256 _deviation
  ) Ownable(_ADMIN) {
    GUARDIAN = _GUARDIAN;
    TOKEN = _TOKEN;
    TOKEN_PRICE_ORACLE = _TOKEN_PRICE_ORACLE;
    PROOF_OF_RESERVES_ORACLE = _PROOF_OF_RESERVES_ORACLE;
    openDeadlineConfig = _openDeadlineConfig;
    fillDeadlineConfig = _fillDeadlineConfig;
    deviation = _deviation;
  }

  function setPaused(bool _paused) external onlyGuardian {
    paused = _paused;
  }

  function setInstitutionStatus(address _institution, bool _allowed) external onlyAdmin {
    allowedInstitutions[_institution] = _allowed;
  }

  function setMarketMakerStatus(address _marketMaker, bool _allowed) external onlyAdmin {
    allowedMarketMakers[_marketMaker] = _allowed;
  }

  function setOpenDeadlineConfig(uint256 _openDeadlineConfig) external onlyAdmin {
    openDeadlineConfig = _openDeadlineConfig;
  }

  function setFillDeadlineConfig(uint256 _fillDeadlineConfig) external onlyAdmin {
    fillDeadlineConfig = _fillDeadlineConfig;
  }

  function setDeviation(uint256 _deviation) external onlyAdmin {
    deviation = _deviation;
  }

  function calculateCrypto40Amount(address _inputToken, uint256 _amount) public view returns (uint256) {
    // Get oracle price (in USD with oracle decimals)
    (, int256 oraclePrice, , , ) = TOKEN_PRICE_ORACLE.latestRoundData();
    require(oraclePrice > 0, "Invalid oracle price");

    // Calculate CRYPTO40 amount from the input token amount
    // Step 1: Get all decimal configurations
    uint8 crypto40Decimals = ERC20(address(TOKEN)).decimals();
    uint8 oracleDecimals = TOKEN_PRICE_ORACLE.decimals();
    uint8 inputTokenDecimals = ERC20(_inputToken).decimals();

    // Step 2: Calculate the scaling factors
    uint256 inputTokenScaling = 10 ** inputTokenDecimals;
    uint256 crypto40Scaling = 10 ** crypto40Decimals;
    uint256 oracleScaling = 10 ** oracleDecimals;

    // Step 3: Calculate CRYPTO40 amount from input token amount
    // Formula: (_amount * crypto40Scaling * oracleScaling) / (inputTokenScaling * oraclePrice)
    uint256 numerator = _amount * crypto40Scaling * oracleScaling;
    uint256 denominator = inputTokenScaling * uint256(oraclePrice);
    uint256 calculatedCrypto40Amount = numerator / denominator;

    return calculatedCrypto40Amount;
  }

  function createOrder(address _inputToken, uint256 _amount) external onlyAllowedInstitutions {
    uint256 calculatedCrypto40Amount = calculateCrypto40Amount(_inputToken, _amount);

    uint256 nonce = _useNonce(msg.sender);
    currentOrderId++;
    IERC20(_inputToken).transferFrom(msg.sender, address(this), _amount);
    orders[currentOrderId] = Order({
      orderId: currentOrderId,
      minReceived: calculatedCrypto40Amount,
      nonce: nonce,
      user: msg.sender,
      inputToken: _inputToken,
      deposit: _amount,
      openDeadline: uint32(block.timestamp + openDeadlineConfig),
      fillDeadline: uint32(block.timestamp + fillDeadlineConfig)
    });
    usedNonces[msg.sender][nonce] = true;
    orderStatus[currentOrderId] = OrderStatus.OPEN;
    emit OrderCreated(
      currentOrderId,
      msg.sender,
      nonce,
      calculatedCrypto40Amount,
      _inputToken,
      _amount,
      uint32(block.timestamp + openDeadlineConfig),
      uint32(block.timestamp + fillDeadlineConfig)
    );
  }

  function cancelOrder(int256 _orderId) external onlyAllowedInstitutions notExpired(_orderId) {
    if (orders[_orderId].user != msg.sender) revert NotOrderOwner();
    // TODO: if order is complete revert
    // if (orderStatus[_orderId] != OrderStatus.OPEN) revert OrderNotOpen();
    if (orderStatus[_orderId] == OrderStatus.FILLING) revert OrderIsFilling();
    cancelledOrders[_orderId] = orders[_orderId];
    orderStatus[_orderId] = OrderStatus.CANCELLED;
    IERC20(orders[_orderId].inputToken).transfer(msg.sender, orders[_orderId].deposit);
    emit OrderCancelled(_orderId, msg.sender, orders[_orderId].nonce);
  }

  function takeOrder(int256 _orderId) external onlyAllowedMarketMakers notExpired(_orderId) {
    orderStatus[_orderId] = OrderStatus.FILLING;
    emit OrderTaken(_orderId, msg.sender, orders[_orderId].nonce);
  }

  function fillOrder(int256 _orderId) external onlyAllowedMarketMakers notExpired(_orderId) {}

  function updateOrderStatus(int256 _orderId) external {
    if (block.timestamp > orders[_orderId].openDeadline || block.timestamp > orders[_orderId].fillDeadline) {
      orderStatus[_orderId] = OrderStatus.EXPIRED;
    }
  }
}
