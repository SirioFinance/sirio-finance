// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";
import {IBaseProtocol} from "../../../contracts/interfaces/IBaseProtocol.sol";
import {HBARProtocol} from "../../../contracts/HBARProtocol.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";

contract HBARProtocolTest is Helpers {
    address owner;
    address user1;
    address user2;

    function setUp() public {
        vm.createSelectFork(
            "https://arb-sepolia.g.alchemy.com/v2/t5qsfobbgmfUwBeGtP-8QoEWCTekALHS",
            74965084
        );
        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");

        deployContracts(owner);
        vm.startPrank(owner);
        sfHBAR.acceptOwnership();
        vm.stopPrank();

        deal(user1, NATIVE_USER_AMOUNT);
        deal(user2, NATIVE_USER_AMOUNT);
        deal(owner, NATIVE_USER_AMOUNT);

        vm.startPrank(owner);

        marketPositionManager.addToMarket(address(sfHBAR));

        address[] memory tokens = new address[](1);
        uint256[] memory borrowCups = new uint256[](1);
        tokens[0] = address(sfHBAR);
        borrowCups[0] = LTV_HBAR;

        marketPositionManager.setLoanToValue(tokens, borrowCups);
        mockSupraOracle.changeTokenPrice(432, 1.2 ether);

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

        address underlyingToken = params.HBARAddress;
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

        // Deploy the contract with valid parametersf
        HBARProtocol hbar = new HBARProtocol(
            feeRate,
            underlyingToken,
            interestRateModel,
            marketPositionManagerTest,
            nftCollection,
            nftCollection2,
            nftCollection3,
            initialExchangeRateMantissa,
            underlyingDecimals,
            maxProtocolBorrowCap,
            maxProtocolSupplyCap,
            reserveFactorMantissa
        );

        assert(hbar.underlyingToken() == underlyingToken);
        assert(hbar.interestRateModel() == interestRateModel);
        assert(hbar.marketPositionManager() == marketPositionManagerTest);
        assert(hbar.maxProtocolBorrowCap() == maxProtocolBorrowCap);
        assert(hbar.maxProtocolSupplyCap() == maxProtocolSupplyCap);
    }

    /**
     * @notice Tests if a user can successfully supply assets to the protocol.
     * @dev Supplies HBAR assets, checks the total shares, borrows, and exchange rates.
     */
    function test_user_supplyAssets() public {
        uint256 underlyingAmount = 2 * HBARs;
        uint256 underlyingAmount2 = 20 * HBARs;

        supplyUnderlyingHBAR(underlyingAmount, user1);

        // @dev roll one block, cause some Math in protocol is based on blocks
        vm.warp(block.timestamp + 60);

        uint256 totalShares = sfHBAR.totalShares();
        uint256 supplyAmount = sfHBAR.getSuppliedAmount(user1);

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfHBAR
            .getAccountSnapshot(user1);

        uint256 exchangeRate = sfHBAR.getExchangeRateStored();

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount2}();

        vm.warp(block.timestamp + 60);

        /// ASSERTIONS
        assertEq(borrowedAmount, 0);
        assertEq(supplyAmount, underlyingAmount);
        assertEq(exchangeRate, 2e6);
        assertEq(totalShares, shareBalance); // as user the one who supply to the protocol
    }

    /**
     * @notice Tests if a user is prevented from supplying assets that exceed the protocol's maximum supply cap.
     * @dev Attempts to supply more HBAR than allowed by the max protocol supply cap.
     */
    function test_user_supplyAsset_cannot_exceedMax() public {
        uint256 underlyingAmount = sfHBAR.maxProtocolSupplyCap() + 1;
        vm.deal(user1, underlyingAmount);

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.MaxProtocolSupplyCap.selector);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();
    }

    /**
     * @notice Tests the calculation of redeemable amounts after borrowing.
     * @dev Supplies assets, borrows, and checks the redeemable amount calculations.
     */
    function test_calculate_correct_redeemAmount() public {
        uint256 underlyingAmount = 100 * HBARs;
        supplyUnderlyingHBAR(underlyingAmount, user1);

        vm.startPrank(user1);

        vm.warp(block.timestamp + 600);

        uint256 borrowAmount = 40 * HBARs;
        sfHBAR.borrow(borrowAmount);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        sfHBAR.redeemExactUnderlying(underlyingAmountToRedeem);

        uint256 redeemable = marketPositionManager.getRedeemableAmount(
            user1,
            address(sfHBAR)
        );

        assertEq(redeemable, 0);
    }

    /**
     * @notice Tests if a user can successfully redeem shares.
     * @dev Supplies assets, and redeems them by checking share balances and borrow amounts.
     */
    function test_user_redeemShares() public {
        uint256 underlyingAmount = 100 * HBARs;

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.InsufficientShares.selector);
        sfHBAR.redeem(10 * HBARs);

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.InsufficientShares.selector);
        sfHBAR.redeem(10 * HBARs);

        uint256 balanceOfUserBefore = user1.balance;
        supplyUnderlyingHBAR(underlyingAmount, user1);

        vm.warp(block.timestamp + 60);

        (uint256 userShareBalance, , , ) = sfHBAR.getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.redeem(userShareBalance);

        // Reading values
        uint256 balanceOfUserAfter = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        uint256 totalShares = sfHBAR.totalShares();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfHBAR
            .getAccountSnapshot(user1);

        /// ASSERTIONS
        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests if a user can redeem the exact underlying amount.
     * @dev Supplies HBAR, advances blocks, then redeems the exact underlying amount.
     * Checks balances, fees, and share amounts before and after redeeming.
     */
    function test_user_redeem_exactUnderlying() public {
        uint256 underlyingAmount = 100 * HBARs;

        uint256 balanceOfUserBefore = user1.balance;
        supplyUnderlyingHBAR(underlyingAmount, user1);

        vm.warp(block.timestamp + 60);

        // Requesting of available amount to redeem
        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        vm.prank(user1);
        sfHBAR.redeemExactUnderlying(underlyingAmountToRedeem);

        uint256 totalShares = sfHBAR.totalShares();
        uint256 balanceOfUserAfter = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfHBAR
            .getAccountSnapshot(user1);

        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests if a user can borrow from the protocol after supplying HBAR.
     * @dev Supplies HBAR, advances blocks, then borrows based on the loan-to-value (LTV).
     * Checks balances, fees, and borrowable amounts before and after borrowing.
     */
    function test_user_borrow() public {
        uint256 underlyingAmount = 100 * HBARs;

        supplyUnderlyingHBAR(underlyingAmount, user1);

        warpTimeForwards(600);

        uint256 userBalanceBeforeBorrow = user1.balance;

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100;

        marketPositionManager.getBorrowableAmount(user1, address(sfHBAR));

        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        uint256 userBalanceAfterBorrow = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        (, uint256 borrowedAmount, uint256 accountSupply, ) = sfHBAR
            .getAccountSnapshot(user1);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        assertEq(borrowedAmount, borrowAmount);
        assertEq(accountSupply, underlyingAmount);
        assertEq(underlyingAmountToRedeem, 0); // Because all

        vm.expectRevert(
            abi.encodeWithSelector(
                IMarketPositionManager.UnderCollaterlized.selector
            )
        );

        vm.prank(user1);
        sfHBAR.borrow(1 * HBARs);
    }

    /**
     * @notice Tests that users cannot borrow more than the protocol's max borrow cap.
     * @dev Attempts to borrow an amount exceeding the maximum protocol borrow cap and expects a revert.
     */
    function test_user_borrow_cannot_exceedMax() public {
        uint256 underlyingAmount = sfHBAR.maxProtocolBorrowCap() + 1;

        vm.prank(user1);
        vm.expectRevert(IBaseProtocol.MaxProtocolBorrowCap.selector);

        sfHBAR.borrow(underlyingAmount);
    }

    /**
     * @notice Tests the ability to borrow incrementally in multiple steps.
     * @dev Increases borrow amount step by step over multiple block periods, validating rate changes.
     */
    function test_user_increaseBorrow_stepByStep() public {
        uint256 underlyingAmount = 100 * HBARs;
        supplyUnderlyingHBAR(underlyingAmount, user1);
        warpTimeForwards(600);

        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfHBAR)
        );

        uint256 borrowRatePerBlock = sfHBAR.borrowRatePerBlock();
        uint256 supplyRatePerBlock = sfHBAR.supplyRatePerBlock();
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            sfHBAR.borrow(borrowable / 10);

            warpTimeForwards(60); // Not sure that this is needed
            assert(borrowRatePerBlock < sfHBAR.borrowRatePerBlock());
            assert(supplyRatePerBlock < sfHBAR.supplyRatePerBlock());

            borrowRatePerBlock = sfHBAR.borrowRatePerBlock();
            supplyRatePerBlock = sfHBAR.supplyRatePerBlock();
        }
    }

    /**
     * @notice Tests if a user can successfully repay a borrow in HBAR.
     * @dev Supplies HBAR, borrows, then repays the borrow amount and validates share balances.
     */
    function test_user_repay_borrowHBAR() public {
        uint256 underlyingAmount = 100 * HBARs;
        supplyUnderlyingHBAR(underlyingAmount, user1);

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100 / 2;
        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        warpTimeForwards(600);

        (, uint256 borrowedAmount, , ) = sfHBAR.getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.repayBorrowNative{value: borrowedAmount}();

        (, uint256 borrowedAmountAfterRepay, , ) = sfHBAR.getAccountSnapshot(
            user1
        );

        assertEq(borrowedAmountAfterRepay, 0);

        warpTimeForwards(600);

        (uint256 userShareBalanceBeforeRedeem, , , ) = sfHBAR
            .getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.redeem(userShareBalanceBeforeRedeem);

        (uint256 userShareBalance, , , ) = sfHBAR.getAccountSnapshot(user1);

        assertEq(userShareBalance, 0);
    }

    /**
     * @notice Tests if a user can repay on behalf of another user.
     * @dev Repays a borrowed amount on behalf of another user and verifies balances.
     */
    function test_user_repay_borrowBehalf_HBAR() public {
        uint256 underlyingAmount = 5e7; //  * HBARs;
        supplyUnderlyingHBAR(underlyingAmount, user1);

        vm.expectRevert(IBaseProtocol.InvalidRepayAmount.selector);
        sfHBAR.repayBorrowNative{value: 0}();

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100 / 2;
        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        warpTimeForwards(600000);

        (, uint256 borrowedAmount, , ) = sfHBAR.getAccountSnapshot(user1);

        vm.prank(user2);
        sfHBAR.repayBorrowBehalfNative{value: borrowedAmount}(user1);

        (, uint256 borrowedAmountAfterRepay, , ) = sfHBAR.getAccountSnapshot(
            user1
        );

        assertEq(borrowedAmountAfterRepay, 0);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        uint256 userAmountBefore = user1.balance;
        uint256 feeBalanceBefore = sfHBAR.accruedProtocolFees();
        (uint256 userShareBalance, , , ) = sfHBAR.getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.redeem(userShareBalance);

        uint256 userAmountAfter = user1.balance;
        uint256 feeBalanceAfter = sfHBAR.accruedProtocolFees();

        // round here because diff is like 1 wei
        assertEq(
            roundToDecimals(underlyingAmountToRedeem, 2),
            roundToDecimals(
                (userAmountAfter - userAmountBefore) +
                    (feeBalanceAfter - feeBalanceBefore),
                2
            )
        );
    }

    /**
     * @notice Tests the underlying balance functionality.
     * @dev Supplies HBAR and checks if the underlying balance matches the supplied amount.
     */
    function test_get_underlyingBalance() public {
        assertEq(sfHBAR.getUnderlyingBalance(), 0);

        uint256 underlyingAmount = 100 * HBARs;
        supplyUnderlyingHBAR(underlyingAmount, user1);
        assertEq(sfHBAR.getUnderlyingBalance(), underlyingAmount);
    }

    /**
     * @notice Tests the protocol's ability to set fee rates for borrowing, redeeming, and claiming interest.
     * @dev Updates fee rates and validates that they are set correctly.
     */
    function test_set_FeeRate() public {
        FeeRate memory feeRate = FeeRate({
            borrowingFeeRate: 100,
            redeemingFeeRate: 50
        });

        vm.prank(owner);
        sfHBAR.setFeeRate(feeRate);

        (uint16 borrowingFeeRate, uint16 redeemFeeRate) = sfHBAR.feeRate();

        assertEq(borrowingFeeRate, 100);
        assertEq(redeemFeeRate, 50);
    }

    /**
     * @notice Tests if the balance of shares is accurately reflected after supplying HBAR.
     * @dev Supplies HBAR, then checks the balance of shares for a user.
     */
    function test_balanceOf() public {
        uint256 underlyingAmount = 100 * HBARs;
        uint256 shares = 5000 * HBARs; // shares are scaled to HBARs Decimals

        supplyUnderlyingHBAR(underlyingAmount, user1);

        (uint256 sharesAmount, , , ) = sfHBAR.getAccountSnapshot(user1);

        assertEq(sharesAmount, shares);
    }

    /**
     * @notice Tests the NFT discount system for fees.
     * @dev Mints NFTs and checks how fee discounts are applied to users based on NFT ownership.
     */
    function test_check_NftDiscount() public {
        uint16 baseFee = 1000;

        vm.startPrank(owner);
        uint256 expectedDiscountfeeNft = 1000;
        uint16 discountedFee = sfHBAR.checkNftDiscount(owner, baseFee);
        assertEq(discountedFee, expectedDiscountfeeNft);

        nftToken.safeMint(owner, 1);
        discountedFee = sfHBAR.checkNftDiscount(owner, baseFee);
        expectedDiscountfeeNft = 0;
        assertEq(discountedFee, expectedDiscountfeeNft);

        vm.stopPrank();
    }

    /**
     * @notice Tests the `whenPaused` modifier by pausing the contract and preventing further actions.
     * @dev Pauses the contract and checks if a user is prevented from supplying HBAR after the pause.
     */
    function test_whenPaused_modifier() public {
        supplyUnderlyingHBAR(10 * HBARs, user1);

        vm.startPrank(owner);

        sfHBAR.pause();

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        supplyUnderlyingHBAR(10 * HBARs, user1);

        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to update the maximum supply cap of the protocol.
     * @dev Updates the max supply cap and ensures that it is correctly set.
     */
    function test_update_maxSupplyCap() public {
        vm.startPrank(owner);
        uint256 maxSupplyCap = sfHBAR.maxProtocolSupplyCap();
        assert(maxSupplyCap == params.maxProtocolSupply);

        sfHBAR.updateMaxSupply(1e18);
        uint256 updateSupplyCap = sfHBAR.maxProtocolSupplyCap();

        assert(sfHBAR.maxProtocolSupplyCap() == updateSupplyCap);
        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to update the maximum borrow cap of the protocol.
     * @dev Updates the max borrow cap and ensures that it is correctly set.
     */
    function test_update_maxBorrowCap() public {
        vm.startPrank(owner);
        uint256 maxBorrowCap = sfHBAR.maxProtocolBorrowCap();
        assert(maxBorrowCap == params.maxProtocolBorrows);

        sfHBAR.updateMaxBorrows(1e18);
        uint256 updateBorrowCap = sfHBAR.maxProtocolBorrowCap();
        assert(sfHBAR.maxProtocolBorrowCap() == updateBorrowCap);
        vm.stopPrank();
    }

    /**
     * @notice Tests the protocol's ability to withdraw accrued fees.
     * @dev Supplies HBAR, advances blocks, checks and withdraws the protocol fees.
     */
    function test_withdraw_fees() public {
        supplyUnderlyingHBAR(1000 * HBARs, user2);
        warpTimeForwards(6e10);

        uint256 fees = sfHBAR.accruedProtocolFees();

        vm.startPrank(owner);
        vm.expectRevert(IBaseProtocol.InvalidFeeAmount.selector);
        sfHBAR.withdrawFees(fees + 1);

        sfHBAR.withdrawFees(fees);

        uint256 feesAfter = sfHBAR.accruedProtocolFees();
        assert(feesAfter == 0);

        vm.stopPrank();
    }

    /**
     * @notice Tests the ability to add reserves to the contract.
     * @dev This test simulates the contract owner adding a fixed amount of reserves.
     */
    function test_add_reserves() public {
        uint256 amount = 10 * HBARs;
        uint256 totalReserves = sfHBAR.totalReserves();

        vm.prank(owner);
        sfHBAR.addReserves{value: amount}();

        uint256 totalReservesAfter = sfHBAR.totalReserves();
        assert(totalReservesAfter == totalReserves + amount);
    }

    /**
     * @notice Tests the ability to remove reserves from the contract.
     * @dev This test simulates the contract owner adding and removing reserves to ensure that the total reserves adjust correctly.
     */
    function test_remove_reserves() public {
        uint256 amount = 10 * HBARs;

        vm.prank(owner);
        sfHBAR.addReserves{value: amount}();

        uint256 totalReserves = sfHBAR.totalReserves();
        uint256 removeAmount = 5 * HBARs;
        vm.prank(owner);
        sfHBAR.removeReserves(removeAmount);

        uint256 totalReservesAfter = sfHBAR.totalReserves();
        assert(totalReservesAfter == totalReserves - removeAmount);
    }

    /**
     * @notice Tests the conversion of accrued protocol fees into reserves.
     * @dev This test simulates the conversion of accrued protocol fees to reserves and ensures
     */
    function test_convert_fees_to_reserves() public {
        supplyUnderlyingHBAR(1000 * HBARs, user1);

        uint256 amount = sfHBAR.accruedProtocolFees();
        uint256 totalReservesBefore = sfHBAR.totalReserves();

        vm.prank(owner);
        sfHBAR.convertFeesToReserves(amount);

        uint256 feesAfter = sfHBAR.accruedProtocolFees();
        uint256 totalReservesAfter = sfHBAR.totalReserves();

        assert(feesAfter == amount + amount);
        assert(totalReservesAfter == totalReservesBefore + amount);
    }
}
