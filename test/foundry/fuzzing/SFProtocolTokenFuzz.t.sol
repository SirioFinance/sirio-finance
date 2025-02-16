// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Deployers} from "../utils/Deployers.sol";
import {Helpers} from "../utils/Helpers.sol";

/**
 * @notice The following fuzz test checks that the different scenarion tests
 * that valid for the fixed amounts are valid for variable user's amount of
 * deposit or borrow and time between actions.
 */
contract SFProtocolTestFuzz is Helpers {
    address user1;
    address user2;
    address owner;

    uint256 maxTimeElapsed = 1000 days;

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

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        deal(address(wethArb), user1, WBTC_USER_AMOUNT);
        deal(address(wethArb), user2, WBTC_USER_AMOUNT);
        deal(address(wethArb), owner, WBTC_USER_AMOUNT);

        vm.startPrank(owner);

        marketPositionManager.addToMarket(address(sfWEth));

        address[] memory tokens = new address[](1);
        uint256[] memory borrowCups = new uint256[](1);
        tokens[0] = address(sfWEth);
        borrowCups[0] = LTV_USDC;

        marketPositionManager.setLoanToValue(tokens, borrowCups);
        supraOracle.updateTimeInterval(maxTimeElapsed);
        vm.stopPrank();
    }

    /**
     * @notice This test is checks that user can supply tokens while varying
     * the amount of tokens supplied and time between the users actions
     */
    function test_user_supplyAssets(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        uint256 blocksForward = uint256(_warpTimeForwards) * 10;

        uint256 underlyingAmount = _amountToSupply + 1; // at least 1 wet
        uint256 underlyingAmount2 = 20 * WETHs;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

        uint totalReserves = sfWEth.totalReserves();
        assert(totalReserves == 0);
        uint256 totalShares = sfWEth.totalShares();
        assert(totalShares > 0);

        uint256 supplyAmount = sfWEth.getSuppliedAmount(user1);
        assertEq(supplyAmount, underlyingAmount);

        (uint256 shareBalance, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            "after supply"
        );

        uint256 exchangeRate = sfWEth.getExchangeRateStored();

        uint256 totalBorrows = sfWEth.totalBorrows();
        assert(totalBorrows == 0);

        uint256 exchangeRate1 = sfWEth.getExchangeRateStored();

        assertEq(borrowedAmount, 0);
        /// as user the one who supply to the protocol
        assertEq(totalShares, shareBalance);

        /// User supply more tokens to the protocol
        sfWEth.supplyUnderlying(underlyingAmount2);
        warpTimeForwards(blocksForward);

        supplyAmount = sfWEth.getSuppliedAmount(user1);

        uint256 totalShares2 = sfWEth.totalShares();
        assert(totalShares2 > totalShares);
        uint256 totalBorrows2 = sfWEth.totalBorrows();
        assert(totalBorrows2 == 0);

        uint256 exchangeRate2 = sfWEth.getExchangeRateStored();

        /// ASSERTIONS
        // exchangeRate should not changed as there is no borrows
        assert(exchangeRate1 == exchangeRate2);
        assertEq(supplyAmount, underlyingAmount + underlyingAmount2);
        /// exchangeRate is not change as there is no borrows
        assertEq(exchangeRate, 2e6);
    }

    /**
     * @notice Tests the calculation of redeemable amounts after borrowing.
     * @dev Supplies assets, borrows, and checks the redeemable amount calculations.
     */
    function test_calculate_correct_redeemAmount(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);
        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        console.log(block.timestamp);
        warpTimeForwards(blocksForward);
        console.log(block.timestamp);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        assertEq(underlyingAmountToRedeem, underlyingAmount);

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100;
        if (borrowAmount > 0) {
            sfWEth.borrow(borrowAmount);
            underlyingAmountToRedeem = marketPositionManager
                .getRedeemableAmount(user1, address(sfWEth));

            // should be zero if user redeem up to the max cup
            assertEq(underlyingAmountToRedeem, 0);
        }
    }

    /**
     * @notice The following test checks that user can redeem his supply amount after
     * he supplied by calling `redeemShares` function.
     */
    function test_user_redeemShares(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;
        uint256 balanceOfUserBefore = wethArb.balanceOf(user1);

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

        (uint256 shareAmountToRedeem, , , ) = sfWEth.getAccountSnapshot(user1);

        sfWEth.redeem(shareAmountToRedeem);
        uint256 fee = sfWEth.accruedProtocolFees();

        // Reading values
        uint256 balanceOfUserAfter = wethArb.balanceOf(user1);
        uint256 totalShares = sfWEth.totalShares();

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
        assertEq(borrowRatePerBlock, interestRateModelWBTC.baseRatePerBlock());
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice The following test checks that user can redeem his supply amount after
     * he supplied by calling `redeemExactUnderlying` function.
     */
    function test_user_redeem_exactUnderlying(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        uint256 balanceOfUserBefore = wethArb.balanceOf(user1);

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

        sfWEth.redeemExactUnderlying(underlyingAmount);

        uint256 totalShares = sfWEth.totalShares();
        uint256 balanceOfUserAfter = wethArb.balanceOf(user1);
        uint256 fee = sfWEth.accruedProtocolFees(); // TODO change to address of protocol token later as it will have fees

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
        assertEq(borrowRatePerBlock, interestRateModelWBTC.baseRatePerBlock());
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice The following test checks that user can borrow assets after he supplies
     * underlying to the pool. Also after user borrow max borrowable amount he
     * cannot borrow more.
     */
    function test_user_borrow(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

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

        (, uint256 borrowedAmount, ) = logsAccountSnapshot(user1, "");

        (, uint256 accountSupply, ) = logAllBalances(user1, "");

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        // ASSERTIONS
        assertEq(borrowedAmount, borrowAmount);
        assertEq(accountSupply, underlyingAmount);
        assertEq(
            underlyingAmountToRedeem,
            borrowedAmount != 0 ? 0 : underlyingAmount /// @dev edge case when supply is too low
        );

        vm.expectRevert(bytes4(keccak256("UnderCollaterlized()")));
        sfWEth.borrow(1);
    }

    /**
     * @notice The following tests checks that user is able to increase his borrow until
     * the borrow max.
     */
    function test_user_increaseBorrow_stepByStep(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfWEth)
        );

        if (borrowable >= 10) {
            (
                uint256 borrowRatePerBlock,
                uint256 supplyRatePerBlock
            ) = logRates();
            for (uint256 i = 0; i < 5; i++) {
                sfWEth.borrow(borrowable / 10);

                warpTimeForwards(1); // otherwise interest rate can
                assert(borrowRatePerBlock < sfWEth.borrowRatePerBlock());
                assert(supplyRatePerBlock < sfWEth.supplyRatePerBlock());

                (borrowRatePerBlock, supplyRatePerBlock) = logRates();
            }
        }
    }

    /**
     * @notice The following test checks that user can partially redeem part of his
     * collateral after the borrow.
     */
    function test_user_can_partiallyRedeem_afterBorrowing(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        warpTimeForwards(blocksForward);

        uint userBalanceBeforeBorrow = wethArb.balanceOf(user1);

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100 / 2;
        sfWEth.borrow(borrowAmount);

        uint userBalanceAfterBorrow = wethArb.balanceOf(user1);
        uint256 fee = sfWEth.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        uint userBalanceBeforeRedeem = wethArb.balanceOf(user1);

        sfWEth.redeemExactUnderlying(underlyingAmountToRedeem);

        uint userBalanceAfterRedeem = wethArb.balanceOf(user1);
        uint feeRedeem = sfWEth.accruedProtocolFees() - fee;

        assertEq(
            underlyingAmountToRedeem,
            userBalanceAfterRedeem - userBalanceBeforeRedeem + feeRedeem
        );
    }

    /**
     * @notice The following test checks that user can supply, borrow, repay and redeem
     * his collateral back
     */
    function test_user_repay_borrowSFP(
        uint256 _amountToSupply,
        uint24 _warpTimeForwards
    ) public {
        vm.assume(_amountToSupply < sfWEth.maxProtocolSupplyCap() - 20 * WETHs);
        vm.assume(_warpTimeForwards < maxTimeElapsed);

        uint256 blocksForward = uint256(_warpTimeForwards);
        uint256 underlyingAmount = _amountToSupply + 1;

        vm.startPrank(user1);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(underlyingAmount);

        uint256 underlyingAmountToRedeemBeforeBorrow = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100 / 2;
        sfWEth.borrow(borrowAmount);

        warpTimeForwards(blocksForward);

        logsAccountSnapshot(user1, "Just after borrow");
        warpTimeForwards(blocksForward);

        (, uint256 borrowedAmount, ) = logsAccountSnapshot(
            user1,
            "before repay"
        );

        if (borrowAmount > 0) {
            sfWEth.repayBorrow(borrowedAmount);
        }
        warpTimeForwards(blocksForward);

        (, uint256 borrowedAmountAfterRepay, ) = logsAccountSnapshot(
            user1,
            "after repay of borrow"
        );

        assertEq(borrowedAmountAfterRepay, 0);

        uint256 underlyingAmountToRedeemAfterRepay = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        uint256 diff = (underlyingAmountToRedeemBeforeBorrow * 1e18) /
            underlyingAmountToRedeemAfterRepay;
        assert(diff < 1000005000000000000);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfWEth));

        sfWEth.redeemExactUnderlying(underlyingAmountToRedeem);
    }

    function logsAccountSnapshot(
        address _user,
        string memory _message
    ) internal view returns (uint256, uint256, uint256) {
        (
            uint256 shareBalance,
            uint256 borrowedAmount,
            uint256 exchangeRate,

        ) = sfWEth.getAccountSnapshot(_user);

        console.log("---------- %s ----------", _message);
        console.log("Share Balance: %d", shareBalance);
        console.log("Borrowed Amount: %d", borrowedAmount);
        console.log("Exchange Rate: %d", exchangeRate);
        console.log("---------- %s ----------", _message);

        return (shareBalance, borrowedAmount, exchangeRate);
    }

    function logRates() internal view returns (uint256, uint256) {
        uint256 borrowRatePerBlock = sfWEth.borrowRatePerBlock();
        uint256 supplyRatePerBlock = sfWEth.supplyRatePerBlock();
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
        ) = sfWEth.getAccountSnapshot(_user);

        console.log("---------- %s ----------", _message);
        console.log("Borrow Balance: %d", borrowBalance);
        console.log("Share Balance: %d", shareBalance);
        console.log("Account Supply: %d", accountSupply);
        console.log("Claimable Interest: %d", claimableInterest);
        console.log("---------- %s ----------", _message);

        return (borrowBalance, accountSupply, claimableInterest);
    }
}
