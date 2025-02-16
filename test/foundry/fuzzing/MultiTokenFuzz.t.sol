// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";

/**
 * @title MultiToken Borrowing and Liquidation Test
 * @notice This contract is a test suite for multi-token borrowing, liquidation risk, and underlying token management using the Foundry framework.
 * @dev The test cases simulate a scenario where multiple tokens are supplied, borrowed, and monitored for liquidation risk using different configurations.
 */
contract MultiTokenFuzzTest is Helpers {
    address owner;
    address user1;
    address user2;
    address liquidator;
    address borrower;

    address underlyingHBAR;
    address underlyingSFBTC;
    address underlyingSFETH;
    address underlyingSFUSDC;

    uint256 liquidateRiskThreshold;
    uint256 userBalancePreBorrow;

    /**
     * @notice Sets up the initial contract state, forks the blockchain at a specific block number, and deploys the necessary contracts.
     * @dev Initializes mock users, assigns balances, sets up the market, and configures the loan-to-value (LTV) ratios.
     * Also sets mock prices for each of the tokens using `mockSupraOracle`.
     */
    function setUp() public {
        vm.createSelectFork(
            "https://arb-sepolia.g.alchemy.com/v2/t5qsfobbgmfUwBeGtP-8QoEWCTekALHS",
            74965084
        );
        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");
        liquidator = makeAddr("liquidator");
        borrower = makeAddr("borrower");

        deployContractsArb(owner, true);
        vm.startPrank(owner);
        sfHBAR.acceptOwnership();
        sfWBTC.acceptOwnership();
        sfWEth.acceptOwnership();
        sfUSDC.acceptOwnership();
        vm.stopPrank();

        address[] memory users = new address[](8);
        users[0] = user1;
        users[1] = user2;
        users[2] = address(this);
        users[3] = owner;
        users[4] = borrower;
        users[5] = borrower;
        users[6] = liquidator;
        users[7] = liquidator;

        deal(address(wethArb), user1, WBTC_USER_AMOUNT);
        deal(address(wethArb), user2, WBTC_USER_AMOUNT);
        deal(address(wethArb), borrower, WBTC_USER_AMOUNT);
        deal(address(wethArb), liquidator, WBTC_USER_AMOUNT);

        deal(address(wbtc), user1, WBTC_USER_AMOUNT);
        deal(address(wbtc), borrower, WBTC_USER_AMOUNT);
        deal(address(wbtc), liquidator, WBTC_USER_AMOUNT);

        deal(address(usdc), user1, WBTC_USER_AMOUNT);
        deal(address(usdc), user2, WBTC_USER_AMOUNT);
        deal(address(usdc), borrower, WBTC_USER_AMOUNT);
        deal(address(usdc), liquidator, WBTC_USER_AMOUNT);

        deal(user1, NATIVE_USER_AMOUNT);
        deal(user2, NATIVE_USER_AMOUNT);
        deal(borrower, NATIVE_USER_AMOUNT);
        deal(liquidator, NATIVE_USER_AMOUNT);

        vm.startPrank(owner);

        marketPositionManager.addToMarket(address(sfHBAR));
        marketPositionManager.addToMarket(address(sfWBTC));
        marketPositionManager.addToMarket(address(sfWEth));
        marketPositionManager.addToMarket(address(sfUSDC));

        address[] memory tokens = new address[](4);
        uint256[] memory borrowCups = new uint256[](4);
        tokens[0] = address(sfHBAR);
        tokens[1] = address(sfWBTC);
        tokens[2] = address(sfWEth);
        tokens[3] = address(sfUSDC);

        borrowCups[0] = LTV_HBAR;
        borrowCups[1] = LTV_BTC;
        borrowCups[2] = LTV_ETH;
        borrowCups[3] = LTV_USDC;

        marketPositionManager.setLoanToValue(tokens, borrowCups);

        mockSupraOracle.changeTokenPrice(432, 0.5 ether); // hbar price
        mockSupraOracle.changeTokenPrice(0, 2 ether); // btc price
        mockSupraOracle.changeTokenPrice(1, 1.5 ether); // ether price
        mockSupraOracle.changeTokenPrice(427, 1 ether); // usdc price

        liquidateRiskThreshold = marketPositionManager.liquidateRiskThreshold();

        vm.stopPrank();
    }

    /**
     * @notice Tests that the maximum borrow amount does not exceed the liquidation risk threshold.
     * @dev Supplies multiple underlying tokens (ETH, HBAR, USDC) to user1 and borrower, and then attempts to borrow the maximum amount.
     * Ensures that the resulting liquidation risk for the borrower remains below the set threshold.
     */
    function test_borrow_max_cannot_exceed_liquidationRiskThreshold(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 testAmount = _amountToSupply / 2 + 1;

        uint256 blocksForward = uint256(_blocksForward) * 10;

        supplyUnderlyingETHArb(testAmount, user1);
        supplyUnderlyingHBAR(testAmount, user1);
        supplyUnderlyingUSDC(testAmount, user1);

        supplyUnderlyingETHArb(testAmount, borrower);
        supplyUnderlyingHBAR(testAmount, borrower);
        supplyUnderlyingUSDC(testAmount, borrower);

        warpTimeForwards(blocksForward);

        borrowMaxSFProtocolToken(borrower, sfUSDC);
        borrowMaxSFProtocolToken(borrower, sfWEth);
        borrowMaxHBAR(borrower);

        (uint256 liquidationRiskAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);
        assert(liquidationRiskAfter <= liquidateRiskThreshold);
    }

    function test_flow_supply_borrowPartially_repay_redeemExactUnderlying(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(_amountToSupply < 1000000000 * USDCs);

        uint256 underlyingAmount = _amountToSupply + 2 * USDCs; // at least 1 wei
        uint256 blocksForward = uint256(_blocksForward);
        uint256 borrowAmount = (underlyingAmount * 1e18 * 50) / (100 * 1e18);

        supplyUnderlyingUSDC(underlyingAmount, user1);
        supplyUnderlyingUSDC(underlyingAmount, user2);

        borrowSFProtocolToken(borrowAmount, user1, sfUSDC);

        warpTimeForwards(blocksForward);

        uint256 redeemableAmount = marketPositionManager.getRedeemableAmount(
            user1,
            address(sfUSDC)
        );

        vm.prank(user1);
        sfUSDC.redeemExactUnderlying(redeemableAmount);

        (, uint256 borrowAmountUsdc, , ) = sfUSDC.getAccountSnapshot(user1);

        vm.prank(user1);
        sfUSDC.repayBorrow(borrowAmountUsdc);

        uint256 redeemableAmountAfterRepay = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        vm.prank(user1);
        sfUSDC.redeemExactUnderlying(redeemableAmountAfterRepay);

        uint256 redeemableAmountFinal = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        assertEq(redeemableAmountFinal, 0);
    }

    function test_flow_supply_borrowPartially_repay_redeem(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(_amountToSupply < 1000000000 * USDCs);

        uint256 underlyingAmount = _amountToSupply + 2; // at least 2 wei
        uint256 blocksForward = uint256(_blocksForward) * 10;
        uint256 borrowAmount = (underlyingAmount * 1e18 * 50) / (100 * 1e18);

        supplyUnderlyingUSDC(underlyingAmount, user1);
        supplyUnderlyingHBAR(underlyingAmount, user1);

        borrowSFProtocolToken(borrowAmount, user1, sfUSDC);

        warpTimeForwards(blocksForward);

        (, uint256 borrowAmountUsdc, , ) = sfUSDC.getAccountSnapshot(user1);

        vm.prank(user1);
        sfUSDC.repayBorrow(borrowAmountUsdc);

        (uint256 userShareAmount, , , ) = sfUSDC.getAccountSnapshot(user1);

        vm.prank(user1);
        sfUSDC.redeem(userShareAmount);

        uint256 redeemableAmountFinal = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        assertEq(redeemableAmountFinal, 0);
    }
}
