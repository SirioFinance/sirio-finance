// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {ISwapTWAPOracle} from "../utils/Deployers.sol";
import {Helpers} from "../utils/Helpers.sol";

/**
 * @notice The following fuzz test checks that the different scenarion tests
 * that valid for the fixed amounts are valid for variable user's amount of
 * deposit or borrow and time between actions.
 */
contract HBARProtocolFuzzTest is Helpers {
    address owner;
    address user1;
    address user2;

    uint256 maxTimeElapsed = 1000 days;

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

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

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
     * @notice This test is checks that user can supply tokens while varying
     * the amount of tokens supplied and time between the users actions
     */
    function test_user_supplyAssets(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < (sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1))
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;
        uint256 underlyingAmount2 = 20 * HBARs;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint256 totalShares = sfHBAR.totalShares();
        /// Total shares after supplying should be more than zero
        assert(totalShares > 0);

        uint256 supplyAmount = sfHBAR.getSuppliedAmount(user1);
        /// Supply amount after supplying should be equal supply amount
        assertEq(supplyAmount, underlyingAmount);

        (uint256 shareBalance, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            "after supply"
        );

        uint256 exchangeRate = sfHBAR.getExchangeRateStored();

        uint256 totalBorrows = sfHBAR.totalBorrows();
        /// total borrows should be equal 0 as user doesnt have it
        assert(totalBorrows == 0);

        uint256 exchangeRate1 = sfHBAR.getExchangeRateStored();

        assertEq(borrowedAmount, 0);
        /// as user the one who supply to the protocol
        assertEq(totalShares, shareBalance);

        /// User supply more tokens to the protocol
        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount2}();

        warpTimeForwards(blocksForward);

        supplyAmount = sfHBAR.getSuppliedAmount(user1);

        uint256 totalShares2 = sfHBAR.totalShares();
        uint256 totalBorrows2 = sfHBAR.totalBorrows();
        assert(totalShares2 > totalShares);
        assert(totalBorrows2 == 0);

        uint256 exchangeRate2 = sfHBAR.getExchangeRateStored();

        /// ASSERTIONS
        // exchangeRate should not changed as there is no borrows
        assert(exchangeRate1 == exchangeRate2);
        assertEq(supplyAmount, underlyingAmount + underlyingAmount2);
        assertEq(exchangeRate, 2e6);
    }

    /**
     * @notice The following test checks that the redeem amount of user is equal to the
     * supplied amount and 0 if user borrow max.
     */
    function test_calculate_correct_redeemAmount(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1; // from 1 wei

        vm.startPrank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        assertEq(underlyingAmountToRedeem, underlyingAmount);

        uint256 borrowedAmount = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfHBAR)
        );

        if (borrowedAmount > 0) {
            sfHBAR.borrow(borrowedAmount);

            warpTimeForwards(blocksForward);

            underlyingAmountToRedeem = marketPositionManager
                .getRedeemableAmount(user1, address(sfHBAR));

            uint256 borrowableAmount = marketPositionManager
                .getBorrowableAmount(user1, address(sfHBAR));

            // should be zero if user redeem up to the max cup
            assertEq(borrowableAmount, 0);
            /// @dev 1 wei is can be as leftorver due to the rounding
            assert(underlyingAmountToRedeem <= 1);
        }
    }

    /**
     * @notice The following test checks that user can redeem his supply amount after
     * he supplied by calling `redeemShares` function.
     */
    function test_user_redeemShares(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;
        uint256 balanceOfUserBefore = user1.balance;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        (uint256 shareAmountToRedeem, , , ) = sfHBAR.getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.redeem(shareAmountToRedeem);
        uint256 fee = sfHBAR.accruedProtocolFees();

        // Reading values
        uint256 balanceOfUserAfter = user1.balance;
        assertEq(balanceOfUserAfter, balanceOfUserBefore - fee);

        uint256 totalShares = sfHBAR.totalShares();

        (uint256 shareBalance, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            "after redeem"
        );

        (
            uint256 borrowBalance,
            uint256 accountSupply,
            uint256 claimableInterest
        ) = logAllBalances(user1, "after redeem");

        (uint256 borrowRatePerBlock, uint256 supplyRatePerBlock) = logRates();
        /// ASSERTIONS
        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(borrowBalance, 0);
        assertEq(accountSupply, 0);
        assertEq(totalShares, 0);
        assertEq(claimableInterest, 0);
        assertEq(supplyRatePerBlock, 0);
        assertEq(borrowRatePerBlock, interestRateModelHBAR.baseRatePerBlock());
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice The following test checks that user can redeem his supply amount after
     * he supplied by calling `redeemExactUnderlying` function.
     */
    function test_user_redeem_exactUnderlying(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;
        uint256 balanceOfUserBefore = user1.balance;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        vm.prank(user1);
        sfHBAR.redeemExactUnderlying(underlyingAmountToRedeem);

        uint256 totalShares = sfHBAR.totalShares();
        uint256 balanceOfUserAfter = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        (uint256 shareBalance, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            ""
        );

        (
            uint256 borrowBalance,
            uint256 accountSupply,
            uint256 claimableInterest
        ) = logAllBalances(user1, "");

        (uint256 borrowRatePerBlock, uint256 supplyRatePerBlock) = logRates();

        // ASSERTIONS
        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(borrowBalance, 0);
        assertEq(accountSupply, 0);
        assertEq(totalShares, 0);
        assertEq(claimableInterest, 0);
        assertEq(supplyRatePerBlock, 0);
        assertEq(borrowRatePerBlock, interestRateModelHBAR.baseRatePerBlock());
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice The following test checks that user can borrow assets after he supplies
     * underlying to the pool. Also after user borrow max borrowable amount he
     * cannot borrow more.
     */
    function test_user_borrow(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint256 totalReserves = sfHBAR.totalReserves();
        assert(totalReserves == 0);

        uint256 userBalanceBeforeBorrow = user1.balance;

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100;

        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfHBAR)
        );
        assertEq(borrowAmount, borrowable);

        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        uint256 userBalanceAfterBorrow = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        (, uint256 borrowedAmount, ) = logsAccountSnapshot(user1, "");

        (, uint256 accountSupply, ) = logAllBalances(user1, "");

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        // ASSERTIONS
        assertEq(borrowedAmount, borrowAmount);
        assertEq(accountSupply, underlyingAmount);
        assert(underlyingAmountToRedeem <= 1);

        vm.expectRevert(bytes4(keccak256("UnderCollaterlized()")));
        vm.prank(user1);
        sfHBAR.borrow(1);
    }

    /**
     * @notice The following test checks that user can partially redeem part of his
     * collateral after the borrow.
     */
    function test_user_can_partiallyRedeem_afterBorrowing(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint userBalanceBeforeBorrow = user1.balance;

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100 / 2;
        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        uint userBalanceAfterBorrow = user1.balance;
        uint256 fee = sfHBAR.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfHBAR));

        uint userBalanceBeforeRedeem = user1.balance;

        vm.prank(user1);
        sfHBAR.redeemExactUnderlying(underlyingAmountToRedeem);

        uint userBalanceAfterRedeem = user1.balance;
        uint256 feeRedeem = sfHBAR.accruedProtocolFees() - fee;

        assertEq(
            underlyingAmountToRedeem,
            userBalanceAfterRedeem - userBalanceBeforeRedeem + feeRedeem
        );
    }

    /**
     * @notice The following tests checks that user is able to increase his borrow until
     * the borrow max.
     */
    function test_user_increaseBorrow_stepByStep(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward) * 10;

        uint256 underlyingAmount = _amountToSupply + 1;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        warpTimeForwards(blocksForward);

        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfHBAR)
        );

        if (borrowable >= 10) {
            (
                uint256 borrowRatePerBlock,
                uint256 supplyRatePerBlock
            ) = logRates();
            for (uint256 i = 0; i < 5; i++) {
                vm.prank(user1);

                sfHBAR.borrow(borrowable / 10);

                warpTimeForwards(10); // Not sure that this is needed
                assert(borrowRatePerBlock < sfHBAR.borrowRatePerBlock());
                assert(supplyRatePerBlock < sfHBAR.supplyRatePerBlock());

                (borrowRatePerBlock, supplyRatePerBlock) = logRates();
            }
        }
    }

    /**
     * @notice The following test checks that user can supply, borrow, repay and redeem
     * his collateral back
     */
    function test_user_repay_borrowHBAR(
        uint256 _amountToSupply,
        uint24 _blocksForward
    ) public {
        vm.assume(
            _amountToSupply < sfHBAR.maxProtocolSupplyCap() - (20 * HBARs + 1)
        );
        uint256 blocksForward = uint256(_blocksForward);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.prank(user1);
        sfHBAR.supplyUnderlyingNative{value: underlyingAmount}();

        uint256 borrowAmount = (underlyingAmount * LTV_HBAR) / 100 / 2;
        vm.prank(user1);
        sfHBAR.borrow(borrowAmount);

        logsAccountSnapshot(user1, "Just after borrow");

        warpTimeForwards(blocksForward);

        (, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            "before repay"
        );

        if (borrowAmount > 0) {
            vm.prank(user1);
            sfHBAR.repayBorrowNative{value: borrowedAmount}();
        }

        warpTimeForwards(blocksForward);

        (, uint256 borrowedAmountAfterRepay, ) = logsAccountSnapshot(
            user1,
            "after repay of borrow"
        );

        assertEq(borrowedAmountAfterRepay, 0);

        (uint256 userShareBalanceBeforeRedeem, , , ) = sfHBAR
            .getAccountSnapshot(user1);

        vm.prank(user1);
        sfHBAR.redeem(userShareBalanceBeforeRedeem);

        (uint256 userShareBalance, , , ) = sfHBAR.getAccountSnapshot(user1);

        assertEq(userShareBalance, 0);
    }

    function logsAccountSnapshot(
        address _user,
        string memory _message
    ) internal view returns (uint256, uint256, uint256) {
        (
            uint256 shareBalance,
            uint256 borrowedAmount,
            uint256 exchangeRate,

        ) = sfHBAR.getAccountSnapshot(_user);

        console.log("---------- %s ----------", _message);
        console.log("Share Balance: %d", shareBalance);
        console.log("Borrowed Amount: %d", borrowedAmount);
        console.log("Exchange Rate: %d", exchangeRate);
        console.log("---------- %s ----------", _message);

        return (shareBalance, borrowedAmount, exchangeRate);
    }

    function logRates() internal view returns (uint256, uint256) {
        uint256 borrowRatePerBlock = sfHBAR.borrowRatePerBlock();
        uint256 supplyRatePerBlock = sfHBAR.supplyRatePerBlock();
        console.log("---------- Rates ----------");
        console.log("Borrow Rate per block: %d", borrowRatePerBlock);
        console.log("Supply Rate per block: %d", supplyRatePerBlock);
        console.log("---------- Rates ----------");

        return (borrowRatePerBlock, supplyRatePerBlock);
    }

    function logAllBalances(
        address _user,
        string memory _message
    ) internal view returns (uint256, uint256, uint256) {
        (
            uint256 shareBalance,
            uint256 borrowBalance,
            uint256 accountSupply,
            uint256 claimableInterest
        ) = sfHBAR.getAccountSnapshot(_user);

        console.log("---------- %s ----------", _message);
        console.log("Borrow Balance: %d", borrowBalance);
        console.log("Share Balance: %d", shareBalance);
        console.log("Account Supply: %d", accountSupply);
        console.log("Claimable Interest: %d", claimableInterest);
        console.log("---------- %s ----------", _message);

        return (borrowBalance, accountSupply, claimableInterest);
    }
}
