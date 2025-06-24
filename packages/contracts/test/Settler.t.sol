// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { Settler } from "../src/Settler.sol";
import { MockPriceOracle } from "../src/mockups/MockPriceOracle.sol";
import { MockReservesOracle } from "../src/mockups/MockReservesOracle.sol";
import { MockERC20 } from "../src/mockups/MockToken.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Crypto40 } from "../src/Crypto40.sol";
import { ISettler } from "../src/interfaces/ISettler.sol";

contract SettlerTest is Test {
  Settler public settler;
  address public ADMIN = address(0x01);
  address public GUARDIAN = address(0x02);
  address public INSTITUTION = address(0x03);
  address public INSTITUTION_2 = address(0x04);
  address public MARKET_MAKER = address(0x05);
  address public MARKET_MAKER_2 = address(0x06);
  address public NOT_ALLOWED_INSTITUTION = address(0x07);
  address public NOT_ALLOWED_MARKET_MAKER = address(0x08);
  //TODO: these should be mocks
  MockPriceOracle public TOKEN_PRICE_ORACLE;
  MockReservesOracle public PROOF_OF_RESERVES_ORACLE;
  MockERC20 public USDC = new MockERC20("USDC", "USDC", 6);
  uint256 public openDeadlineConfig = 12 hours;
  uint256 public fillDeadlineConfig = 12 hours;
  Crypto40 public CRYPTO40;
  uint256 public deviation = 50;

  function setUp() public {
    TOKEN_PRICE_ORACLE = new MockPriceOracle();
    PROOF_OF_RESERVES_ORACLE = new MockReservesOracle();

    // Create CRYPTO40 first with a temporary settler address
    CRYPTO40 = new Crypto40(address(0), ADMIN);

    settler = new Settler(
      ADMIN,
      GUARDIAN,
      CRYPTO40,
      TOKEN_PRICE_ORACLE,
      PROOF_OF_RESERVES_ORACLE,
      openDeadlineConfig,
      fillDeadlineConfig,
      deviation
    );

    // Set the price oracle to return 250 USD (250 * 1e8 = 25000000000)
    // This means 1 CRYPTO40 = 250 USD
    TOKEN_PRICE_ORACLE.setPrice(25000000000);
  }

  // Test: should deploy with the correct parameters
  function test_ShouldDeployWithCorrectParameters() public view {
    assertEq(settler.owner(), ADMIN);
    assertEq(settler.GUARDIAN(), GUARDIAN);
    assertEq(settler.openDeadlineConfig(), openDeadlineConfig);
    assertEq(settler.fillDeadlineConfig(), fillDeadlineConfig);
    assertEq(address(settler.TOKEN_PRICE_ORACLE()), address(TOKEN_PRICE_ORACLE));
    assertEq(address(settler.PROOF_OF_RESERVES_ORACLE()), address(PROOF_OF_RESERVES_ORACLE));
    assertEq(settler.deviation(), deviation);
  }

  // test: only admin can update the open and fill deadlines
  function test_OnlyAdminCanUpdateOpenAndFillDeadlines() public {
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setOpenDeadlineConfig(1 hours);
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setFillDeadlineConfig(1 hours);
    vm.startPrank(ADMIN);
    settler.setOpenDeadlineConfig(1 hours);
    settler.setFillDeadlineConfig(1 hours);
    assertEq(settler.openDeadlineConfig(), 1 hours);
    assertEq(settler.fillDeadlineConfig(), 1 hours);
  }

  //test: only admin can set the deviation
  function test_OnlyAdminCanSetTheDeviation() public {
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setDeviation(100);
  }

  //test: only admin can set the deviation
  function test_AdminCanSetTheDeviation() public {
    vm.startPrank(ADMIN);
    settler.setDeviation(100);
    assertEq(settler.deviation(), 100);
  }

  // Test: only guardian can pause the contract
  function test_OnlyGuardianCanPauseTheContract() public {
    vm.expectRevert(ISettler.OnlyGuardian.selector);
    settler.setPaused(true);
    vm.expectRevert(ISettler.OnlyGuardian.selector);
    settler.setPaused(false);
    vm.startPrank(GUARDIAN);
    settler.setPaused(true);
    assertEq(settler.paused(), true);
    settler.setPaused(false);
    assertEq(settler.paused(), false);
  }

  // Test: Only admin can add institutions to allowlist
  function test_OnlyAdminCanAddInstitutionsToAllowlist() public {
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setInstitutionStatus(NOT_ALLOWED_INSTITUTION, true);
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setInstitutionStatus(INSTITUTION_2, true);
    assertEq(settler.allowedInstitutions(INSTITUTION), true);
    assertEq(settler.allowedInstitutions(INSTITUTION_2), true);
    assertEq(settler.allowedInstitutions(NOT_ALLOWED_INSTITUTION), false);
  }

  // Test: Only admin can remove institutions from allowlist
  function test_OnlyAdminCanRemoveInstitutionsFromAllowlist() public {
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setInstitutionStatus(INSTITUTION_2, true);
    settler.setInstitutionStatus(INSTITUTION, false);
    assertEq(settler.allowedInstitutions(INSTITUTION), false);
    assertEq(settler.allowedInstitutions(INSTITUTION_2), true);
    vm.stopPrank();
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setInstitutionStatus(INSTITUTION_2, false);
  }

  // Test: Only admin can add market makers to allowlist
  function test_OnlyAdminCanAddMarketMakersToAllowlist() public {
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setMarketMakerStatus(NOT_ALLOWED_MARKET_MAKER, true);
    vm.startPrank(ADMIN);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    settler.setMarketMakerStatus(MARKET_MAKER_2, true);
    assertEq(settler.allowedMarketMakers(MARKET_MAKER), true);
    assertEq(settler.allowedMarketMakers(MARKET_MAKER_2), true);
    assertEq(settler.allowedMarketMakers(NOT_ALLOWED_MARKET_MAKER), false);
  }

  // Test: Only admin can remove market makers from allowlist
  function test_OnlyAdminCanRemoveMarketMakersFromAllowlist() public {
    vm.startPrank(ADMIN);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    settler.setMarketMakerStatus(MARKET_MAKER_2, true);
    settler.setMarketMakerStatus(MARKET_MAKER, false);
    assertEq(settler.allowedMarketMakers(MARKET_MAKER), false);
    assertEq(settler.allowedMarketMakers(MARKET_MAKER_2), true);
    vm.stopPrank();
    vm.expectRevert(ISettler.OnlyAdmin.selector);
    settler.setMarketMakerStatus(MARKET_MAKER_2, false);
  }

  function test_OrderShouldFailIfTheInstitutionIsNotAllowed() public {
    vm.startPrank(INSTITUTION);
    vm.expectRevert(ISettler.OnlyAllowedInstitutions.selector);
    // 1 CRYPTO40 = 250 USDC
    settler.createOrder(address(USDC), 250 ether);
    vm.stopPrank();
  }

  // Test: Order can only be created if the user transfers the funds to the contract
  function test_OrderCanOnlyBeCreatedIfTheInstitutionApprovesTheFundsToTheContract() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(settler), 0, 250 ether)
    );
    settler.createOrder(address(USDC), 250 ether);
    vm.stopPrank();
  }

  // Test: Order should fail if deviation is higher than set deviation
  function test_OrderShouldFailIfDeviationIsHigherThanSetDeviation() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    vm.expectRevert(ISettler.DeviationTooHigh.selector);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
  }

  // Test: Allowed Institutions can create orders with their deposits
  function test_AllowedInstitutionsCanCreateOrders() public {
    // 1. Approve USDC, Transfer USDC to TCAP, Create order
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    vm.expectEmit(true, true, true, true);
    emit ISettler.OrderCreated(
      1,
      INSTITUTION,
      0,
      1 ether,
      address(USDC),
      250_000_000,
      uint32(block.timestamp + openDeadlineConfig),
      uint32(block.timestamp + fillDeadlineConfig)
    );
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    assertEq(CRYPTO40.balanceOf(INSTITUTION), 0);
    assertEq(USDC.balanceOf(address(settler)), 250_000_000);
    //check the order is created
    assertEq(settler.currentOrderId(), 1);
    (
      int256 orderId,
      uint256 minReceived,
      uint256 nonce,
      address user,
      address inputToken,
      uint256 deposit,
      uint32 openDeadline,
      uint32 fillDeadline
    ) = settler.orders(1);
    assertEq(minReceived, 1 ether);
    assertEq(inputToken, address(USDC));
    assertEq(user, INSTITUTION);
    assertEq(orderId, 1);
    assertEq(nonce, 0);
    assertEq(deposit, 250_000_000);
    assertEq(openDeadline, uint32(block.timestamp + openDeadlineConfig));
    assertEq(fillDeadline, uint32(block.timestamp + fillDeadlineConfig));
    assertEq(settler.usedNonces(INSTITUTION, nonce), true);
    assertEq(uint256(settler.orderStatus(1)), uint256(Settler.OrderStatus.OPEN));
  }

  // Test: Should fail if order is closed by others
  function test_ShouldFailIfOrderIsClosedByOthers() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setInstitutionStatus(INSTITUTION_2, true);
    vm.stopPrank();
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.startPrank(INSTITUTION_2);
    vm.expectRevert(ISettler.NotOrderOwner.selector);
    settler.cancelOrder(1);
    vm.stopPrank();
  }

  // Test: Allow institutions to cancel orders
  function test_AllowInstitutionsToCancelOrders() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.expectEmit(true, true, true, true);
    emit ISettler.OrderCancelled(1, INSTITUTION, 0);
    settler.cancelOrder(1);
    vm.stopPrank();
    assertEq(uint256(settler.orderStatus(1)), uint256(Settler.OrderStatus.CANCELLED));
    (
      int256 orderId,
      uint256 minReceived,
      uint256 nonce,
      address user,
      address inputToken,
      uint256 deposit,
      uint32 openDeadline,
      uint32 fillDeadline
    ) = settler.cancelledOrders(1);
    assertEq(orderId, 1);
    assertEq(minReceived, 1 ether);
    assertEq(nonce, 0);
    assertEq(user, INSTITUTION);
    assertEq(inputToken, address(USDC));
    assertEq(deposit, 250_000_000);
    assertEq(openDeadline, uint32(block.timestamp + openDeadlineConfig));
    assertEq(fillDeadline, uint32(block.timestamp + fillDeadlineConfig));
    assertEq(MockERC20(address(USDC)).balanceOf(INSTITUTION), 250_000_000);
    assertEq(MockERC20(address(USDC)).balanceOf(address(settler)), 0);
  }

  // Test: Should fail if order is closed
  function test_ShouldFailIfOrderIsClosed() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    revert("Not implemented");
  }

  // Test: If time hasnt passed, order should be open
  function test_IfTimeHasntPassedOrderShouldBeOpen() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    settler.updateOrderStatus(1);
    assertEq(uint256(settler.orderStatus(1)), uint256(Settler.OrderStatus.OPEN));
    // TODO: should do the same in the other statuses
  }

  // Test: Anyone can update order status based on time
  function test_AnyoneCanUpdateOrderStatusBasedOnTime() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.prank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.warp(block.timestamp + openDeadlineConfig + 1);
    settler.updateOrderStatus(1);
    assertEq(uint256(settler.orderStatus(1)), uint256(Settler.OrderStatus.EXPIRED));
  }

  // Test: Test deadlines for other actions

  // Test: Only market makers can take orders
  function test_OnlyMarketMakersCanTakeOrders() public {
    vm.startPrank(MARKET_MAKER);
    vm.expectRevert(ISettler.OnlyAllowedMarketMakers.selector);
    settler.takeOrder(1);
    vm.stopPrank();
  }

  // Test: Order cannot be taken if is expired
  function test_OrderCannotBeTakenIfIsExpired() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    vm.stopPrank();
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.warp(block.timestamp + openDeadlineConfig + 1);
    vm.startPrank(MARKET_MAKER);
    vm.expectRevert(ISettler.OrderExpired.selector);
    settler.takeOrder(1);
    vm.stopPrank();
  }

  // Test: Market Makers can grab an order
  function test_MarketMakersCanTakeAnOrder() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    vm.stopPrank();
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.startPrank(MARKET_MAKER);
    vm.expectEmit(true, true, true, true);
    emit ISettler.OrderTaken(1, MARKET_MAKER, 0);
    settler.takeOrder(1);
    vm.stopPrank();
    assertEq(uint256(settler.orderStatus(1)), uint256(Settler.OrderStatus.FILLING));
  }

  // Test: Should fail cancel if order is filling
  function test_ShouldFailCancelIfOrderIsFilling() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    vm.stopPrank();
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.prank(MARKET_MAKER);
    settler.takeOrder(1);
    vm.prank(INSTITUTION);
    vm.expectRevert(ISettler.OrderIsFilling.selector);
    settler.cancelOrder(1);
    vm.stopPrank();
  }

  // Order can only be completed if proof of reserves is updated
  function test_OrderCanOnlyBeCompletedIfProofOfReservesIsUpdated() public {
    // MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    // vm.startPrank(ADMIN);
    // settler.setInstitutionStatus(INSTITUTION, true);
    // settler.setMarketMakerStatus(MARKET_MAKER, true);
    // vm.stopPrank();
    // vm.startPrank(INSTITUTION);
    // MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    // settler.createOrder(address(USDC), 250_000_000);
    // vm.stopPrank();
    // vm.prank(MARKET_MAKER);
    // settler.takeOrder(1);
    // vm.prank(MARKET_MAKER);
    // vm.expectRevert(ISettler.ProofOfReservesNotUpdated.selector);
    // settler.fillOrder(1);
    // vm.stopPrank();
    revert("Not implemented");
  }

  // Test: Only Allowed Market Makers can complete orders
  function test_OnlyAllowedMarketMakersCanFillOrders() public {
    MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    vm.startPrank(ADMIN);
    settler.setInstitutionStatus(INSTITUTION, true);
    settler.setMarketMakerStatus(MARKET_MAKER, true);
    vm.stopPrank();
    vm.startPrank(INSTITUTION);
    MockERC20(address(USDC)).approve(address(settler), 250_000_000);
    settler.createOrder(address(USDC), 250_000_000);
    vm.stopPrank();
    vm.prank(MARKET_MAKER);
    settler.takeOrder(1);
    vm.prank(MARKET_MAKER);
    settler.fillOrder(1);
    vm.stopPrank();
    // crypto 40 should be minted
    // order should be filled
    // event should be emitted
    // order should be update
  }

  // Test: Allowed Market Makers can fulfill orders
  function test_AllowedMarketMakersCanCompleteAnOrder() public {
    // MockERC20(address(USDC)).mint(INSTITUTION, 250_000_000); // 250 USDC
    // vm.startPrank(ADMIN);
    // tcap.addInstitution(INSTITUTION);
    // tcap.addMarketMaker(MARKET_MAKER);
    // vm.stopPrank();
    // vm.startPrank(INSTITUTION);
    // MockERC20(address(USDC)).approve(address(tcap), 250_000_000);
    // tcap.createOrder(address(USDC), 250_000_000);
    // vm.stopPrank();
    // vm.startPrank(MARKET_MAKER);
    // tcap.fillOrder(1);
    // vm.stopPrank();
    revert("Not implemented");
  }

  // Test: Orders deposits can support any ERC20
  function test_OrdersSupportAnyERC20() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Orders only support USDC, USDT, and ETH
  function test_OrdersOnlySupportSpecificTokens() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Market Maker can submit proof and enable minting after PoR update
  function test_MarketMakerCanSubmitProofAfterPoRUpdate() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: TCAP minted amount is related to TCAP price
  function test_TCAPMintAmountRelatedToPrice() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Orders are measured in USD
  function test_OrdersMeasuredInUSD() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Core Team Multisig can control parameters
  function test_CoreTeamMultisigCanControlParameters() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Emergency Signer can pause
  function test_EmergencySignerCanPause() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Oracles are defined at deploy time
  function test_OraclesDefinedAtDeployTime() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Burning TCAP creates an Order
  function test_BurningTCAPCreatesOrder() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Market Makers can fulfill burn orders
  function test_MarketMakersCanFulfillBurnOrders() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: TCAP is burned and USD is released
  function test_TCAPBurnedAndUSDReleased() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Only admin can claim fees
  function test_OnlyAdminCanClaimFees() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Only admin can update the emergency signer
  function test_OnlyAdminCanUpdateEmergencySigner() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // Test: Only admin can claim ETH or ERC20 Tokens
  function test_OnlyAdminCanClaimETHOrERC20Tokens() public {
    // TODO: Implement test
    revert("Not implemented");
  }

  // TODO: it should pause contracts
  // TODO: token shouldn't be transferrable
  // TODO: fuzz some tests
}
