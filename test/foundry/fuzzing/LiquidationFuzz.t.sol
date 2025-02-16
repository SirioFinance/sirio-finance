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
contract LiquidationsFuzzTest is Helpers {
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

        marketPositionManager.updateLiquidationRiskThreshold(1);
        liquidateRiskThreshold = marketPositionManager.liquidateRiskThreshold();

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

        underlyingAmount = 100 * HBARs; // 1 wei is minimal amount
        userBalancePreBorrow = user1.balance;

        console.log("LiquidationRisk for tests", liquidateRiskThreshold);
    }

    /**
     * @notice Tests borrowing one token (HBAR) while using a different token (USDC) as collateral.
     * @dev Simulates a situation where the borrower supplies USDC as collateral and borrows HBAR, with liquidation conditions triggered by price changes.
     */
    function test_oneBorrows_oneCollateral(
        uint256 _amountToSupply // uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() / 2 - (20 * HBARs)
        );

        uint256 amountUSDCSupplied = _amountToSupply + 10 * HBARs;
        uint256 amountHBARBorrowed = amountUSDCSupplied / 2;

        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        BorrowSFPHBAR(amountHBARBorrowed, borrower);

        // before liquidation call user2 supply collateral for liquidation, this needs to be same token as liquidation
        supplyUnderlyingHBAR(amountHBARBorrowed, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        (
            ,
            uint256 borrowBalanceBorrowerAfter,
            uint256 supplyBalanceBorrowerAfter,

        ) = sfHBAR.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfter == 0);
        assert(borrowBalanceBorrowerAfter == 0);
    }

    /**
     * @notice Tests borrowing one token (HBAR) while using a different token (USDC) as collateral with added interest accumulation.
     * @dev This test builds on the previous one by adding time intervals to account for interest accrued on the borrowed amount.
     */
    function test_oneBorrow_oneCollateral_withInterests(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() / 2 - (20 * HBARs)
        );

        uint256 amountUSDCSupplied = _amountToSupply + 10 * HBARs;
        uint256 amountHBARBorrowed = amountUSDCSupplied / 2;

        supplyUnderlyingUSDC(amountUSDCSupplied, borrower);
        BorrowSFPHBAR(amountHBARBorrowed, borrower);

        warpTimeForwards(_blocksForward);

        // before liquidation call user2 supply collateral for liquidation, this needs to be same token as liquidation

        // add exta supply for liquidator to cover the borrow interests
        uint256 liquidatorSupply = (amountHBARBorrowed * 2);
        supplyUnderlyingHBAR(liquidatorSupply, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        (
            ,
            uint256 borrowBalanceBorrowerAfter,
            uint256 supplyBalanceBorrowerAfter,

        ) = sfHBAR.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfter == 0);
        assert(borrowBalanceBorrowerAfter == 0);
    }

    /**
     * @notice Tests borrowing HBAR while using multiple tokens (USDC and SAUCE) as collateral.
     * @dev This test covers multiple collateral sources and liquidation triggered by changes in token prices.
     */
    function test_oneBorrows_multipleCollateral(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() / 2 - (20 * HBARs)
        );

        uint256 amount_USDC_Supplied = _amountToSupply + 10 * USDCs;
        uint256 amount_SAUCE_Supplied = _amountToSupply / 2 + 10 * USDCs;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        borrowMaxHBAR(borrower);

        warpTimeForwards(_blocksForward);

        (, uint borrowed, , ) = sfHBAR.getAccountSnapshot(borrower);

        supplyUnderlyingHBAR((borrowed * 1010) / 1000, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        (
            ,
            uint256 borrowBalanceBorrowerAfter,
            uint256 supplyBalanceBorrowerAfter,

        ) = sfHBAR.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfter == 0);
        assert(borrowBalanceBorrowerAfter == 0);
    }

    /**
     * @notice Tests borrowing multiple tokens (SAUCE and HBAR) using a single collateral (USDC).
     * @dev Simulates a situation where a user borrows multiple assets using one collateral and is subject to liquidation after a price change.
     */
    function test_multipleBorrows_oneCollateral(
        uint256 _amountToSupply // uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() / 2 - (20 * HBARs)
        );

        uint256 amount_USDC_Supplied = _amountToSupply + 10 * USDCs;
        uint256 amount_SAUCE_Borrowed = (amount_USDC_Supplied * 100) / 1000;
        uint256 amount_HBAR_Borrowed = (amount_USDC_Supplied * 200) / 1000;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        borrowSFProtocolToken(amount_SAUCE_Borrowed, borrower, sfWBTC);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        supplyUnderlyingHBAR(amount_HBAR_Borrowed + 1000 * HBARs, liquidator);
        supplyUnderlyingBTC(amount_SAUCE_Borrowed + 1000 * WBTCs, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfWBTC));

        (
            ,
            uint256 borrowBalanceBorrowerAfterHbar,
            uint256 supplyBalanceBorrowerAfterHbar,

        ) = sfHBAR.getAccountSnapshot(borrower);

        (
            ,
            uint256 borrowBalanceBorrowerAftersfWBTC,
            uint256 supplyBalanceBorrowerAftersfWBTC,

        ) = sfWBTC.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfterHbar == 0);
        assert(supplyBalanceBorrowerAftersfWBTC == 0);

        assert(borrowBalanceBorrowerAfterHbar == 0);
        assert(borrowBalanceBorrowerAftersfWBTC == 0);
    }

    /**
     * @notice Tests borrowing multiple tokens (SAUCE and HBAR) using multiple collateral sources (USDC and SAUCE).
     * @dev Simulates a scenario where liquidation occurs due to price changes in both collateral and borrowed tokens.
     */
    function test_multipleBorrows_multipleCollateral(
        uint256 _amountToSupply
    ) public {
        vm.assume(
            _amountToSupply < sfUSDC.maxProtocolSupplyCap() / 2 - (20 * HBARs)
        );

        uint256 amount_USDC_Supplied = _amountToSupply + 10 * USDCs;
        uint256 amount_SAUCE_Supplied = (amount_USDC_Supplied * 300) / 1000;
        uint256 amount_SAUCE_Borrowed = (amount_USDC_Supplied * 400) / 1000;
        uint256 amount_HBAR_Borrowed = (amount_USDC_Supplied * 400) / 1000;

        supplyUnderlyingUSDC(amount_USDC_Supplied, borrower);
        supplyUnderlyingBTC(amount_SAUCE_Supplied, borrower);
        borrowSFProtocolToken(amount_SAUCE_Borrowed, borrower, sfWBTC);
        BorrowSFPHBAR(amount_HBAR_Borrowed, borrower);

        supplyUnderlyingHBAR(amount_HBAR_Borrowed + 100 * HBARs, liquidator);
        supplyUnderlyingBTC(amount_SAUCE_Borrowed + 100 * WBTCs, liquidator);

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfHBAR));

        vm.prank(liquidator);
        marketPositionManager.liquidateBorrow(borrower, address(sfWBTC));

        (
            ,
            uint256 borrowBalanceBorrowerAfterHbar,
            uint256 supplyBalanceBorrowerAfterHbar,

        ) = sfHBAR.getAccountSnapshot(borrower);

        (
            ,
            uint256 borrowBalanceBorrowerAftersfWBTC,
            uint256 supplyBalanceBorrowerAftersfWBTC,

        ) = sfWBTC.getAccountSnapshot(borrower);

        assert(supplyBalanceBorrowerAfterHbar == 0);
        assert(supplyBalanceBorrowerAftersfWBTC == 0);

        assert(borrowBalanceBorrowerAfterHbar == 0);
        assert(borrowBalanceBorrowerAftersfWBTC == 0);
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
}
