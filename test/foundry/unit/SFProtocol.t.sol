// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";
import {IBaseProtocol} from "../../../contracts/interfaces/IBaseProtocol.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";

/**
 * @title SFProtocolTest Test Suite
 * @dev Test contract for SFProtocolTest functionalities. Uses foundry for unit testing.
 */
contract SFProtocolTest is Helpers {
    address user1;
    address user2;
    address owner;

    /**
     * @dev Sets up the initial state before each test.
     * Initializes users, deploys contracts, assigns ownership, and deals tokens.
     */
    function setUp() public {
        vm.createSelectFork(
            "https://arb-sepolia.g.alchemy.com/v2/t5qsfobbgmfUwBeGtP-8QoEWCTekALHS",
            74965084
        );

        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");

        deployContractsArb(owner, false);
        vm.startPrank(owner);
        sfWEth.acceptOwnership();
        supraOracle.acceptOwnership();
        vm.stopPrank();

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

        borrowCups[0] = LTV_BTC;
        borrowCups[1] = LTV_HBAR;
        borrowCups[2] = LTV_ETH;
        borrowCups[3] = LTV_USDC;

        marketPositionManager.setLoanToValue(tokens, borrowCups);
        supraOracle.updateTimeInterval(1 days);

        deal(address(wethArb), user1, 100 * WBTC_USER_AMOUNT);
        deal(address(wethArb), user2, 100 * WBTC_USER_AMOUNT);
        deal(address(wethArb), owner, 100 * WBTC_USER_AMOUNT);
        vm.stopPrank();
    }

    /**
     * @notice Tests the constructor of the HBARProtocol contract.
     * @dev Ensures that the contract is deployed with valid parameters.
     */
    function test_constructor() public {
        address nftCollection = 0x1234567890123456789012345678901234567890;
        address nftCollection2 = 0x1234567890123456789012345678901234567890;
        address nftCollection3 = 0x1234567890123456789012345678901234567890;

        address underlyingToken = params.WETHAddress;
        address marketPositionManagerTest = address(marketPositionManager);
        address interestRateModel = params.supraPullOracle;
        uint256 reserveFactorMantissa = params.reserveFactorMantissa;
        uint256 initialExchangeRateMantissa = params
            .initialExchangeRateMantissa;
        uint8 underlyingDecimals = 8;
        uint256 maxProtocolBorrowCap = params.maxProtocolBorrows;
        uint256 maxProtocolSupplyCap = params.maxProtocolSupply;
        FeeRate memory feeRate = FeeRate({
            borrowingFeeRate: 100,
            redeemingFeeRate: 75
        });

        string memory name = "weth";
        string memory symbol = "WETH";

        // Deploy the contract with valid parameters
        SFProtocolToken sfeth = new SFProtocolToken(
            feeRate,
            underlyingToken,
            interestRateModel,
            marketPositionManagerTest,
            nftCollection,
            nftCollection2,
            nftCollection3,
            initialExchangeRateMantissa,
            params.HBARAddress,
            name,
            symbol,
            underlyingDecimals,
            maxProtocolBorrowCap,
            maxProtocolSupplyCap,
            reserveFactorMantissa
        );

        assert(sfeth.underlyingToken() == underlyingToken);
        assert(sfeth.interestRateModel() == interestRateModel);
        assert(sfeth.marketPositionManager() == marketPositionManagerTest);
        assert(sfeth.maxProtocolBorrowCap() == maxProtocolBorrowCap);
        assert(sfeth.maxProtocolSupplyCap() == maxProtocolSupplyCap);
        assert(
            keccak256(abi.encodePacked(sfeth.name())) ==
                keccak256(abi.encodePacked(name))
        );
        assert(
            keccak256(abi.encodePacked(sfeth.symbol())) ==
                keccak256(abi.encodePacked(symbol))
        );

        assert(sfeth.HBARaddress() == params.HBARAddress);
    }

    /**
     * @notice Tests if a user can successfully supply assets to the protocol.
     * @dev Supplies WETHs assets, checks the total shares, borrows, and exchange rates.
     */
    function test_user_supplyAssets() public {
        uint256 underlyingAmount = 100 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        // @dev roll 1 blocks
        vm.warp(block.timestamp + 60);

        uint256 totalShares = sfWEth.totalShares();
        uint256 supplyAmount = sfWEth.getSuppliedAmount(user1);

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfWEth
            .getAccountSnapshot(user1);

        uint256 exchangeRate = sfWEth.getExchangeRateStored();

        vm.stopPrank();

        /// ASSERTIONS
        assertEq(borrowedAmount, 0);
        assertEq(supplyAmount, underlyingAmount);
        assertEq(exchangeRate, 2e6);
        assertEq(totalShares, shareBalance); // as user the one who supply to the protocol
    }

    /**
     * @notice Tests if a user can successfully redeem shares.
     * @dev Supplies assets, and redeems them by checking share balances and borrow amounts.
     */

    function test_user_redeemShares() public {
        uint256 underlyingAmount = 100 * WETHs;

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.InsufficientShares.selector);
        sfWEth.redeem(10 * WETHs);

        uint256 balanceOfUserBefore = wethArb.balanceOf(user1);
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);
        vm.warp(block.timestamp + 60);

        (uint256 userShareBalance, , , ) = sfWEth.getAccountSnapshot(user1);

        sfWEth.redeem(userShareBalance);

        // Reading values
        uint256 balanceOfUserAfter = wethArb.balanceOf(user1);
        uint256 fee = sfWEth.accruedProtocolFees();
        uint256 totalShares = sfWEth.totalShares();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfWEth
            .getAccountSnapshot(user1);

        vm.stopPrank();

        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests if a user can redeem the exact underlying amount.
     * @dev Supplies WETHs, advances blocks, then redeems the exact underlying amount.
     * Checks balances, fees, and share amounts before and after redeeming.
     */
    function test_user_redeem_exactUnderlying() public {
        uint256 underlyingAmount = 100 * WETHs;

        uint256 balanceOfUserBefore = wethArb.balanceOf(user1);
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        vm.warp(block.timestamp + 60);

        sfWEth.redeemExactUnderlying(underlyingAmount);

        // Reading values
        uint256 totalShares = sfWEth.totalShares();
        uint256 balanceOfUserAfter = wethArb.balanceOf(user1);
        uint256 fee = sfWEth.accruedProtocolFees();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfWEth
            .getAccountSnapshot(user1);

        vm.stopPrank();
        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests if a user is prevented from supplying assets that exceed the protocol's maximum supply cap.
     * @dev Attempts to supply more WETHs than allowed by the max protocol supply cap.
     */
    function test_user_supplyAsset_cannot_exceedMax() public {
        uint256 underlyingAmount = sfWEth.maxProtocolSupplyCap() + 1;

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.MaxProtocolSupplyCap.selector);
        sfWEth.supplyUnderlying(underlyingAmount);
    }

    /**
     * @notice Tests the calculation of redeemable amounts after borrowing.
     * @dev Supplies assets, borrows, and checks the redeemable amount calculations.
     */
    function test_calculate_correct_redeemAmount() public {
        uint256 underlyingAmount = 100 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        uint256 borrowAmount = 40 * WETHs;
        sfWEth.borrow(borrowAmount);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        sfWEth.redeemExactUnderlying(underlyingAmountToRedeem);

        uint256 redeemable = marketPositionManager.getRedeemableAmount(
            user1,
            address(sfWEth)
        );

        vm.stopPrank();
        assertEq(redeemable, 0);
    }

    /**
     * @notice Tests if a user can borrow from the protocol after supplying WETHs.
     * @dev Supplies WETHs, advances blocks, then borrows based on the loan-to-value (LTV).
     * Checks balances, fees, and borrowable amounts before and after borrowing.
     */
    function test_user_borrow() public {
        uint256 underlyingAmount = 100 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        vm.warp(block.timestamp + 60);

        uint256 userBalanceBeforeBorrow = wethArb.balanceOf(user1);
        uint256 borrowAmount = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfWEth)
        );

        sfWEth.borrow(borrowAmount);

        uint256 userBalanceAfterBorrow = wethArb.balanceOf(user1);
        uint256 fee = sfWEth.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        (, uint256 borrowedAmount, uint256 accountSupply, ) = sfWEth
            .getAccountSnapshot(user1);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        // ASSERTION
        assertEq(borrowedAmount, borrowAmount);
        assertEq(accountSupply, underlyingAmount);
        assertEq(underlyingAmountToRedeem, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMarketPositionManager.UnderCollaterlized.selector
            )
        );
        sfWEth.borrow(1000);

        vm.stopPrank();
    }

    /**
     * @notice Tests that users cannot borrow more than the protocol's max borrow cap.
     * @dev Attempts to borrow an amount exceeding the maximum protocol borrow cap and expects a revert.
     */
    function test_user_borrow_cannot_exceedMax() public {
        uint256 underlyingAmount = sfWEth.maxProtocolBorrowCap() + 1;

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.MaxProtocolBorrowCap.selector);
        sfWEth.borrow(underlyingAmount);
    }

    /**
     * @notice Tests the ability to borrow incrementally in multiple steps.
     * @dev Increases borrow amount step by step over multiple block periods, validating rate changes.
     */
    function test_user_increaseBorrow_stepByStep() public {
        uint256 underlyingAmount = 100 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        warpTimeForwards(600);

        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfWEth)
        );

        uint256 borrowRatePerBlock = sfWEth.borrowRatePerBlock();
        uint256 supplyRatePerBlock = sfWEth.supplyRatePerBlock();
        for (uint256 i = 0; i < 5; i++) {
            sfWEth.borrow(borrowable / 10);

            warpTimeForwards(60);
            assert(borrowRatePerBlock < sfWEth.borrowRatePerBlock());
            assert(supplyRatePerBlock < sfWEth.supplyRatePerBlock());

            borrowRatePerBlock = sfWEth.borrowRatePerBlock();
            supplyRatePerBlock = sfWEth.supplyRatePerBlock();
        }
        vm.stopPrank();
    }

    /**
     * @notice Tests if a user can successfully repay a borrow in WETHs.
     * @dev Supplies WETHs, borrows, then repays the borrow amount and validates share balances.
     */
    function test_user_repay_borrowSFP() public {
        uint256 underlyingAmount = 1 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100 / 2;
        sfWEth.borrow(borrowAmount);

        vm.warp(block.timestamp + 600);

        (, uint256 borrowedAmount, , ) = sfWEth.getAccountSnapshot(user1);

        sfWEth.repayBorrow(borrowedAmount);

        (, uint256 borrowedAmountAfterRepay, , ) = sfWEth.getAccountSnapshot(
            user1
        );

        assertEq(borrowedAmountAfterRepay, 0);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        uint256 userAmountBefore = wethArb.balanceOf(user1);
        uint256 feeBalanceBefore = sfWEth.accruedProtocolFees();

        (uint256 userShareBalance, , , ) = sfWEth.getAccountSnapshot(user1);

        sfWEth.redeem(userShareBalance);

        uint256 userAmountAfter = wethArb.balanceOf(user1);
        uint256 feeBalanceAfter = sfWEth.accruedProtocolFees();

        // round here because diff is like 1 wei
        assertEq(
            roundToDecimals(underlyingAmountToRedeem, 6),
            roundToDecimals(
                (userAmountAfter - userAmountBefore) +
                    (feeBalanceAfter - feeBalanceBefore),
                4
            )
        );
        vm.stopPrank();
    }

    /**
     * @notice Tests if a user can repay on behalf of another user.
     * @dev Repays a borrowed amount on behalf of another user and verifies balances.
     */

    function test_user_repay_borrowBehalf_SFP() public {
        uint256 underlyingAmount = 1 * WETHs;
        supplyUnderlyingETHArb(underlyingAmount, user1);

        vm.startPrank(user1);

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100 / 2;
        sfWEth.borrow(borrowAmount);

        vm.warp(block.timestamp + 600);

        (, uint256 borrowedAmount, , ) = sfWEth.getAccountSnapshot(user1);

        vm.stopPrank();

        vm.startPrank(user2);
        wethArb.approve(address(sfWEth), type(uint256).max);
        vm.stopPrank();

        vm.prank(user2);
        sfWEth.repayBorrowBehalf(user1, borrowedAmount);

        (, uint256 borrowedAmountAfterRepay, , ) = sfWEth.getAccountSnapshot(
            user1
        );

        assertEq(borrowedAmountAfterRepay, 0);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        uint256 userAmountBefore = wethArb.balanceOf(user1);
        uint256 feeBalanceBefore = sfWEth.accruedProtocolFees();

        (uint256 userShareBalance, , , ) = sfWEth.getAccountSnapshot(user1);

        vm.prank(user1);
        sfWEth.redeem(userShareBalance);

        uint256 userAmountAfter = wethArb.balanceOf(user1);
        uint256 feeBalanceAfter = sfWEth.accruedProtocolFees();
        // round here because diff is like 1 wei
        assertEq(
            roundToDecimals(underlyingAmountToRedeem, 6),
            roundToDecimals(
                (userAmountAfter - userAmountBefore) +
                    (feeBalanceAfter - feeBalanceBefore),
                4
            )
        );

        vm.stopPrank();
    }

    /**
     * @notice Tests the protocol's ability to set fee rates for borrowing, redeeming, and claiming interest.
     * @dev Updates fee rates and validates that they are set correctly.
     */
    function test_set_feeRate() public {
        FeeRate memory feeRate = FeeRate({
            borrowingFeeRate: 100,
            redeemingFeeRate: 50
        });

        vm.prank(owner);
        sfWEth.setFeeRate(feeRate);

        (uint16 borrowingFeeRate, uint16 redeemFeeRate) = sfWEth.feeRate();

        assertEq(borrowingFeeRate, 100);
        assertEq(redeemFeeRate, 50);
    }

    /**
     * @notice Tests the NFT discount system for fees.
     * @dev Mints NFTs and checks how fee discounts are applied to users based on NFT ownership.
     */
    function test_checkNftDiscount() public {
        uint16 baseFee = 1000;

        vm.startPrank(owner);
        uint256 expectedDiscountfeeNft = 1000;
        uint16 discountedFee = sfWEth.checkNftDiscount(owner, baseFee);
        assertEq(discountedFee, expectedDiscountfeeNft);

        nftToken.safeMint(owner, 1);
        discountedFee = sfWEth.checkNftDiscount(owner, baseFee);
        expectedDiscountfeeNft = 0;
        assertEq(discountedFee, expectedDiscountfeeNft);

        vm.stopPrank();
    }

    /**
     * @notice Tests the `whenPaused` modifier by pausing the contract and preventing further actions.
     * @dev Pauses the contract and checks if a user is prevented from supplying HBAR after the pause.
     */
    function test_whenPaused_modifier() public {
        supplyUnderlyingETHArb(10 * WETHs, user1);
        vm.startPrank(owner);

        sfWEth.pause();

        vm.stopPrank();

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        sfWEth.supplyUnderlying(10 * WETHs);
        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to update the maximum supply cap of the protocol.
     * @dev Updates the max supply cap and ensures that it is correctly set.
     */
    function test_update_maxSupplyCap() public {
        vm.startPrank(owner);
        uint256 maxSupplyCap = sfWEth.maxProtocolSupplyCap();
        assert(maxSupplyCap == params.maxProtocolSupply);

        sfWEth.updateMaxSupply(1e18);
        uint256 updateSupplyCap = sfWEth.maxProtocolSupplyCap();
        assert(sfWEth.maxProtocolSupplyCap() == updateSupplyCap);
        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to update the maximum borrow cap of the protocol.
     * @dev Updates the max borrow cap and ensures that it is correctly set.
     */
    function test_update_maxBorrowCap() public {
        vm.startPrank(owner);
        uint256 maxBorrowCap = sfWEth.maxProtocolBorrowCap();
        assert(maxBorrowCap == params.maxProtocolBorrows);

        sfWEth.updateMaxBorrows(1e18);
        uint256 updateBorrowCap = sfWEth.maxProtocolBorrowCap();
        assert(sfWEth.maxProtocolBorrowCap() == updateBorrowCap);
        vm.stopPrank();
    }

    /**
     * @notice Tests the protocol's ability to withdraw accrued fees.
     * @dev Supplies WETHs, advances blocks, checks and withdraws the protocol fees.
     */
    function test_withdraw_fees() public {
        supplyUnderlyingETHArb(1000 * WETHs, user2);
        warpTimeForwards(6e10);

        uint256 fees = sfWEth.accruedProtocolFees();

        vm.startPrank(owner);
        vm.expectRevert(IBaseProtocol.InvalidFeeAmount.selector);
        sfWEth.withdrawFees(fees + 1);

        sfWEth.withdrawFees(fees);

        uint256 feesAfter = sfWEth.accruedProtocolFees();
        assert(feesAfter == 0);

        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to add reserves to the contract.
     * @dev This test simulates the contract owner adding a fixed amount of reserves.
     */
    function test_add_reserves() public {
        uint256 amount = 10 * WETHs;
        uint256 totalReserves = sfWEth.totalReserves();

        vm.startPrank(owner);
        wethArb.approve(address(sfWEth), amount);
        sfWEth.addReserves(amount);
        vm.stopPrank();

        uint256 totalReservesAfter = sfWEth.totalReserves();
        assert(totalReservesAfter == totalReserves + amount);
    }

    /**
     * @notice Tests the ability to remove reserves from the contract.
     * @dev This test simulates the contract owner adding and removing reserves to ensure that the total reserves adjust correctly.
     */
    function test_remove_reserves() public {
        uint256 amount = 10 * WETHs;

        vm.startPrank(owner);
        wethArb.approve(address(sfWEth), amount);
        sfWEth.addReserves(amount);
        vm.stopPrank();

        uint256 totalReserves = sfWEth.totalReserves();

        uint256 removeAmount = 5 * WETHs;
        vm.prank(owner);
        sfWEth.removeReserves(removeAmount);

        uint256 totalReservesAfter = sfWEth.totalReserves();
        assert(totalReservesAfter == totalReserves - removeAmount);
    }

    /**
     * @notice Tests the conversion of accrued protocol fees into reserves.
     * @dev This test simulates the conversion of accrued protocol fees to reserves and ensures
     */
    function test_convert_fees_to_reserves() public {
        supplyUnderlyingETHArb(1000 * WETHs, user1);
        uint256 amount = sfWEth.accruedProtocolFees();
        uint256 totalReservesBefore = sfWEth.totalReserves();

        vm.prank(owner);
        sfWEth.convertFeesToReserves(amount);

        uint256 feesAfter = sfWEth.accruedProtocolFees();
        uint256 totalReservesAfter = sfWEth.totalReserves();

        assert(feesAfter == amount + amount);
        assert(totalReservesAfter == totalReservesBefore + amount);
    }

    /**
     * @notice Tests `syncReserves` when `underlyingBalanceActual > totalReserves`.
     * @dev Ensures that the surplus amount is correctly added to the reserves.
     */
    function test_syncReserves_withSurplus() public {
        uint256 initialReserves = sfWEth.totalReserves();
        uint256 initialBorrows = sfWEth.totalBorrows();
        uint256 protocolFees = sfWEth.accruedProtocolFees();

        uint256 extraTokens = 50 * WETHs;
        deal(address(wethArb), address(sfWEth), extraTokens);

        vm.startPrank(owner);
        sfWEth.syncReserves();

        // Calculate expected reserves after syncing
        uint256 contractBalance = wethArb.balanceOf(address(sfWEth));
        uint256 expectedUnderlyingBalance = contractBalance -
            protocolFees +
            initialBorrows;
        uint256 surplusAmount = expectedUnderlyingBalance - initialReserves;

        assertEq(
            sfWEth.totalReserves(),
            initialReserves + surplusAmount,
            "Total reserves should be increased by the surplus amount."
        );

        vm.stopPrank();
    }

    /**
     * @notice Tests `syncReserves` when `underlyingBalanceActual <= totalReserves`.
     * @dev Ensures that reserves remain unchanged if no surplus exists.
     */
    function test_syncReserves_noSurplus() public {
        uint256 initialReserves = sfWEth.totalReserves();
        uint256 initialBorrows = sfWEth.totalBorrows();
        uint256 protocolFees = sfWEth.accruedProtocolFees();

        // Set contract balance such that `underlyingBalanceActual <= totalReserves`
        uint256 requiredBalance = initialReserves +
            protocolFees -
            initialBorrows;

        deal(address(wethArb), address(sfWEth), requiredBalance);
        vm.startPrank(owner);
        sfWEth.syncReserves();

        assertEq(
            sfWEth.totalReserves(),
            initialReserves,
            "Total reserves should remain the same when no surplus exists."
        );

        vm.stopPrank();
    }
}
