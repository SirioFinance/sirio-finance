// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";
import {ISwapTWAPOracle} from "../../../contracts/interfaces/ISwapTWAPOracle.sol";
import {IBaseProtocol} from "../../../contracts/interfaces/IBaseProtocol.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";
import {Helpers} from "../utils/Helpers.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LiquidationsTest Test Suite
 * @dev Test contract for LiquidationsTest functionalities. Uses foundry for unit testing.
 */
contract LiquidationsTest is Helpers {
    address owner;
    address user1;
    address user2;
    address liquidator;
    address borrower;

    uint256 underlyingHBAR;
    uint256 underlyingSFBTC;
    uint256 underlyingSFETH;
    uint256 underlyingSFUSDC;

    uint256 liquidateRiskThreshold;
    uint256 userBalancePreBorrow;
    uint256 underlyingAmount;

    /**
     * @notice Sets up the environment for the liquidation tests.
     * @dev Forks the Ethereum mainnet, deploys contracts, and prepares users with balances for testing.
     */
    function setUp() public {
        vm.createSelectFork(
            "https://mainnet.infura.io/v3/b812db1f09b54c7aac2fee91b2fc90da",
            20269878
        );

        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");
        liquidator = makeAddr("liquidator");
        borrower = makeAddr("borrower");

        deployContracts(owner);
        vm.startPrank(owner);
        sfHBAR.acceptOwnership();
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

        dealBunch(users);

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

        borrowCups[0] = 60;
        borrowCups[1] = 80;
        borrowCups[2] = 80;
        borrowCups[3] = 75;

        marketPositionManager.setLoanToValue(tokens, borrowCups);

        underlyingHBAR = 432;
        underlyingSFBTC = 0;
        underlyingSFETH = 1;
        underlyingSFUSDC = 427;

        mockSupraOracle.changeTokenPrice(432, 1 ether); // hbar
        mockSupraOracle.changeTokenPrice(0, 1 ether); // btc
        mockSupraOracle.changeTokenPrice(1, 1 ether); // eth
        mockSupraOracle.changeTokenPrice(427, 1 ether); // usdc

        vm.stopPrank();

        uint256 maxNative = sfHBAR.maxProtocolSupplyCap();
        uint256 maxWBTC = sfWBTC.maxProtocolSupplyCap();
        uint256 maxUSDC = sfUSDC.maxProtocolSupplyCap();

        sfHBAR.supplyUnderlyingNative{value: maxNative / 2}();
        wbtc.approve(address(sfWBTC), type(uint256).max);
        sfWBTC.supplyUnderlying(
            maxWBTC > WBTC_USER_AMOUNT ? WBTC_USER_AMOUNT / 2 : maxWBTC / 2
        );

        usdc.approve(address(sfUSDC), type(uint256).max);
        sfUSDC.supplyUnderlying(
            USDC_USER_AMOUNT > maxUSDC ? maxUSDC / 2 : USDC_USER_AMOUNT / 2
        );

        liquidateRiskThreshold = marketPositionManager.liquidateRiskThreshold();
        underlyingAmount = 100 * HBARs; // 1 wei is minimal amount
        userBalancePreBorrow = user1.balance;

        console.log("LiquidationRisk for tests", liquidateRiskThreshold);
    }

    /**
     * @notice Tests if an healthy position becomes unhealthy when the price of the supplied asset decreases.
     * @dev Simulates a price increase of the underlying token (HBAR) and checks if the position becomes liquidatable.
     */
    function test_healthy_position_becomes_unhealthy_when_priceUnderlying_decreases()
        public
    {
        supplyUnderlyingHBAR(20 * HBARs, user1);
        supplyUnderlyingUSDC(100 * USDCs, user1);
        borrowMaxHBAR(user1);

        (uint256 healthcareBefore, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareBefore <= liquidateRiskThreshold);

        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 0.50 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareAfter > liquidateRiskThreshold);
    }

    /**
     * @notice Tests if an unhealthy position becomes healthy when the price of the supplied asset increases.
     * @dev Simulates a price increase of the underlying token (HBAR) and checks if the position becomes non-liquidatable.
     */
    function test_unhealthy_position_becomes_healthy_when_priceUnderlying_increases()
        public
    {
        supplyUnderlyingHBAR(100 * HBARs, user1);
        supplyUnderlyingUSDC(20 * USDCs, user1);
        borrowMaxSFProtocolToken(user1, sfUSDC);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.5 ether);

        (uint256 healthcareBefore, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareBefore >= liquidateRiskThreshold);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 1 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareAfter < liquidateRiskThreshold);
    }

    /**
     * @notice Ensures that a healthy position cannot be liquidated.
     * @dev Attempts to liquidate a healthy position and expects a revert.
     */
    function test_healthy_position_shouldNotBe_liquidated_when_noAmountSent()
        public
    {
        borrowMaxHBAR(user1);

        (uint256 healthcare, , ) = marketPositionManager.checkLiquidationRisk(
            user1
        );
        // @dev healthcare must be less than healthcare threshold to not trigger liqudations
        assertLt(healthcare, liquidateRiskThreshold);

        supplyUnderlyingHBAR(underlyingAmount, user2);
        supplyUnderlyingBTC(underlyingAmount, user2);

        vm.startPrank(user2);
        vm.expectRevert(
            IMarketPositionManager
                .LiquidationAmountShouldBeMoreThanZero
                .selector
        );
        marketPositionManager.liquidateBorrow(user1, address(sfHBAR));
    }

    /**
     * @notice Tests that a healthy position cannot be liquidated.
     * @dev Simulates an attempt to liquidate a healthy position and verifies it reverts.
     */
    function test_healthy_position_shouldNotBe_liquidated() public {
        supplyUnderlyingHBAR(100 * HBARs, user1);

        borrowMaxHBAR(user1);

        (uint256 healthcare, , ) = marketPositionManager.checkLiquidationRisk(
            user1
        );
        // @dev healthcare must be less than healthcare threshold to not trigger liqudations
        assertLt(healthcare, liquidateRiskThreshold);

        vm.prank(user2);
        vm.expectRevert(
            IMarketPositionManager.PositionIsNotLiquidatable.selector
        );
        marketPositionManager.liquidateBorrow(user1, address(sfHBAR));
    }

    /**
     * @notice Tests that an unhealthy position becomes healthy when the loan is repaid.
     * @dev Simulates repaying part of a loan to improve the position's health factor.
     */
    function test_unhealthy_position_becames_healthy_when_loanRepayed() public {
        supplyUnderlyingHBAR(500 * HBARs, user1);
        supplyUnderlyingUSDC(800 * USDCs, user1);
        borrowMaxSFProtocolToken(user1, sfUSDC);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.4 ether);

        (uint256 healthcareBefore, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareBefore >= liquidateRiskThreshold);

        vm.prank(user1);
        sfUSDC.repayBorrow(200 * USDCs);
        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareAfter < liquidateRiskThreshold);
    }

    /**
     * @notice Tests if an unhealthy position becomes healthy after supplying more underlying collateral.
     * @dev Simulates the scenario where a user supplies more collateral to improve the health factor of their position.
     */
    function test_unhealthy_position_becomes_healthy_when_SupplyMoreUnderlying()
        public
    {
        supplyUnderlyingHBAR(500 * HBARs, user1);
        supplyUnderlyingUSDC(800 * USDCs, user1);
        borrowMaxSFProtocolToken(user1, sfUSDC);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.4 ether);

        (uint256 healthcareBefore, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareBefore >= liquidateRiskThreshold);

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: 600 * HBARs}();

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(user1);

        assert(healthcareAfter < liquidateRiskThreshold);
    }

    /**
     * @notice Tests borrowing one token (HBAR) while using a different token (USDC) as collateral.
     * @dev Simulates a situation where the borrower supplies USDC as collateral and borrows HBAR, with liquidation conditions triggered by price changes.
     */
    function test_oneBorrows_oneCollateral() public {
        // 1. Healthy position shouuld become unhealthy if price of underlying goes down
        // TODO amounts for this liquidation is followed according to the docs
        // initial token prices:
        // USDC - 1 $
        // HBAR - 0.15 $
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Borrower supply 1250 USDC and borrow 3000 HBAR
        // Liquidator supply 3000 HBAR ? likely change to HBAR
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // price changes to:
        // USDC - 1 $
        // HBAR - 0.30 $
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Balances after
        //
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amountUSDCSupplied = 1250 * USDCs;
        uint256 amountHBARBorrowed = 3000 * HBARs;
        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        BorrowSFPHBAR(amountHBARBorrowed, borrower);

        (
            uint256 healthcareBefore,
            uint256 totalDebtBefore,
            uint256 totalCollateralBefore
        ) = marketPositionManager.checkLiquidationRisk(borrower);

        assertApproxEqAbs(healthcareBefore, 36e16, 1e16);
        assertApproxEqAbs(totalCollateralBefore, 125e19, 1e18);
        assertApproxEqAbs(totalDebtBefore, 450e18, 1e18);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.4 ether);

        (
            uint256 healthcareAfter,
            uint256 totalDebtAfter,
            uint256 totalCollateralAfter
        ) = marketPositionManager.checkLiquidationRisk(borrower);

        assert(healthcareAfter >= liquidateRiskThreshold);
        assertApproxEqAbs(healthcareAfter, 96e16, 1e16);
        assertApproxEqAbs(totalCollateralAfter, 125e19, 1e18);
        assertApproxEqAbs(totalDebtAfter, 12e20, 1e18);

        // before liquidation call user2 supply collateral for liquidation, this needs to be same token as liquidation
        supplyUnderlyingHBAR(amountHBARBorrowed, liquidator);
        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 amount_USDC_LiquidatorGet = 1235 * USDCs;
        uint256 amount_USDC_ProtocolGet = 15 * USDCs;

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();

        (, , uint256 balanceOfLiquidatorAfter_sfUSDC, ) = sfUSDC
            .getAccountSnapshot(liquidator);

        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfUSDC,
            amount_USDC_LiquidatorGet,
            10e4,
            6,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            6,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests borrowing one token (HBAR) while using a different token (USDC) as collateral with added interest accumulation.
     * @dev This test builds on the previous one by adding time intervals to account for interest accrued on the borrowed amount.
     */
    function test_oneBorrow_oneCollateral_withInterests() public {
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amountUSDCSupplied = 1250 * USDCs;
        uint256 amountHBARBorrowed = 3000 * HBARs;
        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        BorrowSFPHBAR(amountHBARBorrowed, borrower);

        (
            uint256 healthcareBefore,
            uint256 totalDebtBefore,
            uint256 totalCollateralBefore
        ) = marketPositionManager.checkLiquidationRisk(borrower);

        assertApproxEqAbs(healthcareBefore, 36e16, 1e16);
        assertApproxEqAbs(totalCollateralBefore, 125e19, 1e18);
        assertApproxEqAbs(totalDebtBefore, 450e18, 1e18);
        warpTimeForwards(6000);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.4 ether);

        (
            uint256 healthcareAfter,
            uint256 totalDebtAfter,
            uint256 totalCollateralAfter
        ) = marketPositionManager.checkLiquidationRisk(borrower);

        assert(healthcareAfter >= liquidateRiskThreshold);
        assertApproxEqAbs(healthcareAfter, 96e16, 1e16);
        assertApproxEqAbs(totalCollateralAfter, 125e19, 1e18);
        assertApproxEqAbs(totalDebtAfter, 12e20, 1e18);
        warpTimeForwards(6000);

        // before liquidation call user2 supply collateral for liquidation, this needs to be same token as liquidation

        // add extra 0,1% for liquidator to cover the borrow interests
        uint256 liquidatorSupply = (amountHBARBorrowed * 1001) / 1000;
        supplyUnderlyingHBAR(liquidatorSupply, liquidator);
        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 amount_USDC_LiquidatorGet = 1235 * USDCs;
        uint256 amount_USDC_ProtocolGet = 15 * USDCs;

        (, uint borrowed, , ) = sfHBAR.getAccountSnapshot(borrower);
        assert(borrowed > amountHBARBorrowed);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();

        (, , uint256 balanceOfLiquidatorAfter_sfUSDC, ) = sfUSDC
            .getAccountSnapshot(liquidator);

        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfUSDC,
            amount_USDC_LiquidatorGet,
            10e4,
            8,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests borrowing HBAR while using multiple tokens (USDC and SAUCE) as collateral.
     * @dev This test covers multiple collateral sources and liquidation triggered by changes in token prices.
     */
    function test_oneBorrows_multipleCollateral() public {
        // 1. Healthy position shouuld become unhealthy if price of underlying goes down
        // TODO amounts for this liquidation is followed according to the docs
        // initial token prices:
        // USDC - 1 $
        // SAUCE - 0.15 $
        // HBAR - 0.15 $
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Borrower supply 1000 USDC & 2000 SAUCE and borrow 4000 HBAR
        // Liquidator supply 4000 HBAR
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // price changes to:
        // USDC - 1 $
        // SAUCE - 0.2 $ (Up)
        // HBAR - 0.1 $ (Down)
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Balances after
        //

        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 1 ether);
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amount_USDC_Supplied = 1000 * USDCs;
        uint256 amount_SAUCE_Supplied = 2000 * WBTCs;
        uint256 amount_HBAR_Borrowed = 4000 * WBTCs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.05 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.25 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);

        assert(healthcareAfter >= liquidateRiskThreshold);

        supplyUnderlyingHBAR(4001 * WBTCs, liquidator);

        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesBeforeLiquidation_sfWBTC = sfWBTC.totalReserves();

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        uint256 amount_USDC_LiquidatorGet = 97276e4; //  * USDCs; // 1459.29
        uint256 amount_SAUCE_LiquidatorGet = 194545e6; // * WBTCs; // 2918.57
        uint256 amount_USDC_ProtocolGet = 2727e4; //  * USDCs; // 40.71
        uint256 amount_SAUCE_ProtocolGet = 54545e5; // * WBTCs; // 81,43

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesAfterLiquidation_sfWBTC = sfWBTC.totalReserves();

        (, , uint256 balanceOfLiquidatorAfter_sfUSDC, ) = sfUSDC
            .getAccountSnapshot(liquidator);

        (, , uint256 balanceOfLiquidatorAfter_sfWBTC, ) = sfWBTC
            .getAccountSnapshot(liquidator);

        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfUSDC,
            amount_USDC_LiquidatorGet,
            10e4,
            6,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfWBTC,
            amount_SAUCE_LiquidatorGet, // extra from supplied
            10e6,
            8,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            6,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfWBTC -
                totalReservesBeforeLiquidation_sfWBTC,
            amount_SAUCE_ProtocolGet,
            15e4,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests borrowing HBAR while using multiple tokens (USDC and SAUCE) as collateral, with added interest accumulation.
     * @dev Similar to `test_oneBorrows_MultipleCollateral`, but with time intervals to account for interest on the borrowed amount.
     */
    function test_oneBorrows_multipleCollateral_withInterests() public {
        // The same as above the only difference is the time interval between users actions
        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 1 ether);
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amount_USDC_Supplied = 1000 * USDCs;
        uint256 amount_SAUCE_Supplied = 2000 * WBTCs;
        uint256 amount_HBAR_Borrowed = 4000 * WBTCs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);
        warpTimeForwards(2001);

        (uint256 healthcareBefore, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);
        assert(healthcareBefore < liquidateRiskThreshold);

        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.05 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.25 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);

        assert(healthcareAfter >= liquidateRiskThreshold);
        warpTimeForwards(2001);

        // add extra 0,1% for liquidator to cover the borrow interests
        uint256 liquidatorSupply = (amount_HBAR_Borrowed * 1001) / 1000;

        (, uint borrowed, , ) = sfHBAR.getAccountSnapshot(borrower);
        assert(borrowed > amount_HBAR_Borrowed);

        supplyUnderlyingHBAR(liquidatorSupply, liquidator);
        warpTimeForwards(2001);

        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesBeforeLiquidation_sfWBTC = sfWBTC.totalReserves();

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        uint256 amount_USDC_LiquidatorGet = 97276e4; //  * USDCs; // 1459.29
        uint256 amount_SAUCE_LiquidatorGet = 194545e6; // * WBTCs; // 2918.57
        uint256 amount_USDC_ProtocolGet = 2727e4; //  * USDCs; // 40.71
        uint256 amount_SAUCE_ProtocolGet = 54540e5; // * WBTCs; // 81,43

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesAfterLiquidation_sfWBTC = sfWBTC.totalReserves();

        (, , uint256 balanceOfLiquidatorAfter_sfUSDC, ) = sfUSDC
            .getAccountSnapshot(liquidator);

        (, , uint256 balanceOfLiquidatorAfter_sfWBTC, ) = sfWBTC
            .getAccountSnapshot(liquidator);

        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfUSDC,
            amount_USDC_LiquidatorGet,
            10e4,
            6,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfWBTC,
            amount_SAUCE_LiquidatorGet, // extra from supplied
            10e6,
            8,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            6,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfWBTC -
                totalReservesBeforeLiquidation_sfWBTC,
            amount_SAUCE_ProtocolGet,
            12e5,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests borrowing multiple tokens (SAUCE and HBAR) using a single collateral (USDC).
     * @dev Simulates a situation where a user borrows multiple assets using one collateral and is subject to liquidation after a price change.
     */
    function test_multipleBorrows_oneCollateral() public {
        // 1. Healthy position shouuld become unhealthy if price of underlying goes down
        // amounts for this liquidation is followed according to the docs
        // initial token prices:
        // USDC - 1 $
        // SAUCE - 0.15 $
        // HBAR - 0.15 $
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Borrower supply 1500 USDC and borrow 4000 SAUCE & 2000 HBAR
        // Liquidator supply 4000 HBAR & 2000 SAUCE
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // price changes to:
        // USDC - 1 $
        // SAUCE - 0.25 $ (Up)
        // HBAR - 0.2 $ (Down)
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Balances after
        // the total of Borrower loan is 0,25 * 4000 + 2000 * 0,2 = 1400 $
        // The liquidator should get 1500 - (1500 - 1400) * 30% = 1470 USDC at the end of the liquidation process.
        // the protocol gets 30 USDC at the end of the liquidation processmockPriceOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);

        // INITIAL PRICES
        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 1 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);

        uint256 amount_USDC_Supplied = 1500 * USDCs;
        uint256 amount_SAUCE_Borrowed = 4000 * WBTCs;
        uint256 amount_HBAR_Borrowed = 2000 * HBARs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        borrowSFProtocolToken(amount_SAUCE_Borrowed, borrower, sfWBTC);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        // Change token prices
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.25 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.2 ether);

        uint256 amount_USDC_LiquidatorGet = 1470 * USDCs; //
        uint256 amount_USDC_ProtocolGet = 30 * USDCs; //

        supplyUnderlyingHBAR(amount_HBAR_Borrowed + 1000 * HBARs, liquidator);
        supplyUnderlyingBTC(amount_SAUCE_Borrowed + 1000 * WBTCs, liquidator);

        uint256 totalReservesBeforeLiquidation = sfUSDC.totalReserves();
        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfWBTC));

        uint256 totalReservesAfterLiquidation = sfUSDC.totalReserves();

        // CHECKS
        (, , uint256 balanceOfLiquidatorAfter, ) = sfUSDC.getAccountSnapshot(
            liquidator
        );
        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter,
            amount_USDC_LiquidatorGet,
            10e2,
            8,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation - totalReservesBeforeLiquidation,
            amount_USDC_ProtocolGet,
            10e2,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests borrowing multiple tokens (SAUCE and HBAR) using multiple collateral sources (USDC and SAUCE).
     * @dev Simulates a scenario where liquidation occurs due to price changes in both collateral and borrowed tokens.
     */
    function test_multipleBorrows_multipleCollateral() public {
        // 1. Healthy position shouuld become unhealthy if price of underlying goes down
        // amounts for this liquidation is followed according to the docs
        // initial token prices:
        // USDC - 1 $
        // SAUCE - 0.15 $
        // HBAR - 0.15 $
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Borrower supply 1500 USDC and 3000 SAUCE borrow 4000 SAUCE & 2000 HBAR
        // Liquidator supply 4000 SAUCE & 2000 HBAR
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // price changes to:
        // USDC - 1 $
        // SAUCE - 0.2 $ (Up)
        // HBAR - 0.37 $ (Up)
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // Balances after
        // the total of Borrower loan is 0,2 * 4000 + 3000 * 0,37 = 1910 $
        // The cost of Borrower collateral is 2100 $ =  1500 USDC + 3000 SAUCE * 0,2$
        // The liquidator should get 2100 - (2100 - 1910) * 30% = 2043 $ (1459,29 USDC + 2918.57 SAUCE)  at the end of the liquidation process.
        // the protocol gets 40,71 USDC + 81,43 SAUCE at the end of the liquidation process

        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 1 ether);
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amount_USDC_Supplied = 1500 * USDCs;
        uint256 amount_SAUCE_Supplied = 3000 * WBTCs;
        uint256 amount_SAUCE_Borrowed = 4000 * WBTCs;
        uint256 amount_HBAR_Borrowed = 3000 * HBARs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        borrowSFProtocolToken(amount_SAUCE_Borrowed, borrower, sfWBTC);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        // Change token prices
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.2 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.37 ether);

        uint256 amount_USDC_LiquidatorGet = 145929e4; //  * USDCs; // 1459.29
        uint256 amount_SAUCE_LiquidatorGet = 291857e6; // * WBTCs; // 2918.57
        uint256 amount_USDC_ProtocolGet = 4071e4; //  * USDCs; // 40.71
        uint256 amount_SAUCE_ProtocolGet = 8143e6; // * WBTCs; // 81,43

        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesBeforeLiquidation_sfWBTC = sfWBTC.totalReserves();

        supplyUnderlyingHBAR(amount_HBAR_Borrowed + 100 * HBARs, liquidator);
        supplyUnderlyingBTC(amount_SAUCE_Borrowed + 100 * WBTCs, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfWBTC));

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesAfterLiquidation_sfWBTC = sfWBTC.totalReserves();

        // CHECKS
        (, , uint256 balanceOfLiquidatorAfter_sfUSDC, ) = sfUSDC
            .getAccountSnapshot(liquidator);

        (, , uint256 balanceOfLiquidatorAfter_sfWBTC, ) = sfWBTC
            .getAccountSnapshot(liquidator);

        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfUSDC,
            amount_USDC_LiquidatorGet,
            10e4,
            8,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            balanceOfLiquidatorAfter_sfWBTC,
            amount_SAUCE_LiquidatorGet + (100 * WBTCs), // extra from supplied
            20e4,
            8,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            8,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfWBTC -
                totalReservesBeforeLiquidation_sfWBTC,
            amount_SAUCE_ProtocolGet,
            15e4,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests liquidation of a bad debt position where the borrower has one collateral and one borrow token.
     * @dev Liquidates the borrower's position when their health factor drops below the liquidation threshold.
     */
    function test_liquidate_badDebt_position_oneCollateral_oneBorrow() public {
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amountUSDCSupplied = 1250 * USDCs;
        uint256 amountHBARBorrowed = 3000 * HBARs;
        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        BorrowSFPHBAR(amountHBARBorrowed, borrower);

        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.45 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);

        // @dev liquidation risk after should be more that 100%
        assert(healthcareAfter >= 1e18);

        // add Reserves to liquidate position
        address hbarOwner = sfHBAR.owner();
        vm.prank(hbarOwner);
        sfHBAR.addReserves{value: amountHBARBorrowed}();

        uint256 totalReservesBeforeLiquidation_sfUSDC = sfUSDC.totalReserves();

        address[] memory borrowers = new address[](1);
        borrowers[0] = borrower;

        address marketPositionManagerOwner = marketPositionManager.owner();
        vm.prank(marketPositionManagerOwner);
        marketPositionManager.liquidateBadDebts(borrowers);

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesAfterLiquidation_sfHBAR = sfHBAR.totalReserves();
        // @dev was spend for liquidation of borrow
        uint256 expectedAmount_USDC_forProtocol = 1250 * USDCs;
        // should be equal to the collateral  of the liquidate user
        uint256 expectedAmount_HBAR_forProtocol = 0;

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC -
                totalReservesBeforeLiquidation_sfUSDC,
            expectedAmount_USDC_forProtocol,
            10e4,
            6,
            "balances are not as expected"
        );

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfHBAR,
            expectedAmount_HBAR_forProtocol,
            10e4,
            6,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests liquidation of a bad debt position where the borrower has multiple collateral and multiple borrow tokens.
     * @dev Liquidates the borrower’s position with multiple collateral and borrowed tokens when their health factor drops below the liquidation threshold.
     */
    function test_liquidate_badDebt_position_manyCollateral_manyBorrow()
        public
    {
        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 1 ether);
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.15 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.15 ether);

        uint256 amount_USDC_Supplied = 1500 * USDCs;
        uint256 amount_SAUCE_Supplied = 3000 * WBTCs;
        uint256 amount_SAUCE_Borrowed = 4000 * WBTCs;
        uint256 amount_HBAR_Borrowed = 3000 * HBARs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        borrowSFProtocolToken(amount_SAUCE_Borrowed, borrower, sfWBTC);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        // Change token prices
        mockSupraOracle.changeTokenPrice(underlyingSFBTC, 0.2 ether);
        mockSupraOracle.changeTokenPrice(underlyingHBAR, 0.45 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);

        // @dev liquidation risk after should be more that 100%
        assert(healthcareAfter >= 1e18);

        // add Reserves to liquidate position
        address hbarOwner = sfHBAR.owner();
        vm.prank(hbarOwner);
        sfHBAR.addReserves{value: amount_HBAR_Borrowed}();

        address wbtcOwner = sfWBTC.owner();
        vm.prank(wbtcOwner);
        sfWBTC.addReserves(amount_SAUCE_Borrowed);

        //
        uint256 amount_USDC_ProtocolGet = 1500 * USDCs; //  * USDCs; // 1459.29
        uint256 amount_SAUCE_ProtocolGet = 3000 * WBTCs; // * WBTCs; // 2918.57

        address[] memory borrowers = new address[](1);
        borrowers[0] = borrower;

        address marketPositionManagerOwner = marketPositionManager.owner();
        vm.prank(marketPositionManagerOwner);
        marketPositionManager.liquidateBadDebts(borrowers);

        uint256 totalReservesAfterLiquidation_sfUSDC = sfUSDC.totalReserves();
        uint256 totalReservesAfterLiquidation_sfWBTC = sfWBTC.totalReserves();

        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfUSDC,
            amount_USDC_ProtocolGet,
            10e4,
            8,
            "balances are not as expected"
        );
        vm.assertApproxEqAbsDecimal(
            totalReservesAfterLiquidation_sfWBTC,
            amount_SAUCE_ProtocolGet,
            15e4,
            8,
            "balances are not as expected"
        );
    }

    /**
     * @notice Tests the ability of token owners to add and remove reserves.
     * @dev Verifies that the owner of a token can add and remove protocol reserves.
     */
    function test_owner_ofToken_can_addAndRemove_reserves() public {
        uint256 amount_WBTC = 5000 * WBTCs;
        uint256 amount_HBAR = 10000 * HBARs;

        address hbarOwner = sfHBAR.owner();
        vm.prank(hbarOwner);
        sfHBAR.addReserves{value: amount_HBAR}();

        address wbtcOwner = sfWBTC.owner();
        vm.prank(wbtcOwner);
        sfWBTC.addReserves(amount_WBTC);

        uint256 totalReservesAfterAdd_WBTC = sfWBTC.totalReserves();
        uint256 totalReservesAfterAdd_HBAR = sfHBAR.totalReserves();

        assertEq(totalReservesAfterAdd_WBTC, amount_WBTC);
        assertEq(totalReservesAfterAdd_HBAR, amount_HBAR);

        vm.prank(hbarOwner);
        sfHBAR.removeReserves(amount_HBAR / 2);

        vm.prank(wbtcOwner);
        sfWBTC.removeReserves(amount_WBTC / 2);

        uint256 totalReservesAfterRemove_WBTC = sfWBTC.totalReserves();
        uint256 totalReservesAfterRemove_HBAR = sfHBAR.totalReserves();

        assertEq(totalReservesAfterRemove_WBTC, amount_WBTC / 2);
        assertEq(totalReservesAfterRemove_HBAR, amount_HBAR / 2);
    }

    function test_no_leftover_dust_after_liquidation() public {
        uint256 amountUSDCSupplied = 100 * USDCs;
        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        borrowMaxSFProtocolToken(borrower, sfUSDC);

        vm.prank(owner);
        marketPositionManager.updateLiquidationRiskThreshold(1e10);

        warpTimeForwards(6000);

        uint256 liquidatorSupply = (amountUSDCSupplied * 1001) / 1000;
        supplyUnderlyingUSDC(liquidatorSupply, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfUSDC));

        (
            ,
            uint256 borrowBalanceBorrowerAfter,
            uint256 supplyBalanceBorrowerAfter,

        ) = sfUSDC.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfter == 0);
        assert(borrowBalanceBorrowerAfter == 0);
    }

    function test_bad_debt_liquidation_cannot_be_liquidated_normally() public {
        uint256 amountUSDCSupplied = 100 * USDCs;
        uint256 amountHbarSupplied = 100 * HBARs;

        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        supplyUnderlyingHBAR(amountHbarSupplied, liquidator);

        borrowMaxHBAR(borrower);

        vm.prank(owner);
        marketPositionManager.updateLiquidationRiskThreshold(8e17);

        warpTimeForwards(6000);

        mockSupraOracle.changeTokenPrice(underlyingSFUSDC, 0.4 ether);

        (uint256 healthcareAfter, , ) = marketPositionManager
            .checkLiquidationRisk(borrower);

        assert(healthcareAfter > 1e18);

        vm.expectRevert(IMarketPositionManager.BadDebtLiquidation.selector);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        address[] memory borrowers = new address[](1);
        borrowers[0] = borrower;

        // add Reserves to liquidate position
        address hbarOwner = sfHBAR.owner();
        vm.prank(hbarOwner);
        sfHBAR.addReserves{value: amountHbarSupplied}();

        address marketPositionManagerOwner = marketPositionManager.owner();
        vm.prank(marketPositionManagerOwner);
        marketPositionManager.liquidateBadDebts(borrowers);

        (
            ,
            uint256 borrowBalanceBorrowerAfter,
            uint256 supplyBalanceBorrowerAfter,

        ) = sfHBAR.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfter == 0);
        assert(borrowBalanceBorrowerAfter == 0);
    }
}
