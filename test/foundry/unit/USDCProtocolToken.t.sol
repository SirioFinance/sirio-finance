// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";

/**
 * @title USDCProtocolTest Test Suite
 * @dev Test contract for USDCProtocolTest functionalities. Uses foundry for unit testing.
 */
contract USDCProtocolTest is Helpers {
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
        sfUSDC.acceptOwnership();
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

        deal(address(usdc), user1, WBTC_USER_AMOUNT);
        deal(address(usdc), user2, WBTC_USER_AMOUNT);
        deal(address(usdc), owner, WBTC_USER_AMOUNT);
        vm.stopPrank();
    }

    /**
     * @notice Tests if a user can successfully supply assets to the protocol.
     * @dev Supplies USDCs assets, checks the total shares, borrows, and exchange rates.
     */
    function test_user_supplyAssets() public {
        uint256 underlyingAmount = 100 * USDCs;

        supplyUnderlyingUSDC(underlyingAmount, user1);
        vm.startPrank(user1);

        // @dev roll 1 blocks
        vm.warp(block.timestamp + 60);

        uint256 totalShares = sfUSDC.totalShares();
        uint256 supplyAmount = sfUSDC.getSuppliedAmount(user1);

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfUSDC
            .getAccountSnapshot(user1);

        uint256 exchangeRate = sfUSDC.getExchangeRateStored();

        vm.stopPrank();

        /// ASSERTIONS
        assertEq(borrowedAmount, 0);
        assertEq(supplyAmount, underlyingAmount);
        assertEq(exchangeRate, 2e4);
        assertEq(totalShares, shareBalance);
    }

    /**
     * @notice Tests if a user can successfully redeem shares.
     * @dev Supplies assets, and redeems them by checking share balances and borrow amounts.
     */
    function test_user_redeemShares() public {
        uint256 underlyingAmount = 100 * USDCs;
        uint256 balanceOfUserBefore = usdc.balanceOf(user1);

        supplyUnderlyingUSDC(underlyingAmount, user1);

        vm.startPrank(user1);

        vm.warp(block.timestamp + 60);

        (uint256 userShareBalance, , , ) = sfUSDC.getAccountSnapshot(user1);

        sfUSDC.redeem(userShareBalance);

        // Reading values
        uint256 balanceOfUserAfter = usdc.balanceOf(user1);
        uint256 fee = sfUSDC.accruedProtocolFees();
        uint256 totalShares = sfUSDC.totalShares();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfUSDC
            .getAccountSnapshot(user1);

        vm.stopPrank();

        /// ASSERTIONS
        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests if a user can redeem the exact underlying amount.
     * @dev Supplies USDCs, advances blocks, then redeems the exact underlying amount.
     * Checks balances, fees, and share amounts before and after redeeming.
     */
    function test_user_redeem_exactUnderlying() public {
        uint256 underlyingAmount = 100 * USDCs;
        uint256 balanceOfUserBefore = usdc.balanceOf(user1);

        supplyUnderlyingUSDC(underlyingAmount, user1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 60);
        sfUSDC.redeemExactUnderlying(underlyingAmount);

        // Reading values
        uint256 totalShares = sfUSDC.totalShares();
        uint256 balanceOfUserAfter = usdc.balanceOf(user1);
        uint256 fee = sfUSDC.accruedProtocolFees();

        (uint256 shareBalance, uint256 borrowedAmount, , ) = sfUSDC
            .getAccountSnapshot(user1);

        vm.stopPrank();

        assertEq(shareBalance, 0);
        assertEq(borrowedAmount, 0);
        assertEq(totalShares, 0);
        assertEq(balanceOfUserBefore, balanceOfUserAfter + fee);
    }

    /**
     * @notice Tests the calculation of redeemable amounts after borrowing.
     * @dev Supplies assets, borrows, and checks the redeemable amount calculations.
     */
    function test_calculate_correct_redeemAmount() public {
        uint256 underlyingAmount = 100 * USDCs;
        supplyUnderlyingUSDC(underlyingAmount, user1);
        vm.startPrank(user1);

        vm.warp(block.timestamp + 60);
        uint256 borrowAmount = 40 * USDCs;
        sfUSDC.borrow(borrowAmount);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        sfUSDC.redeemExactUnderlying(underlyingAmountToRedeem);

        uint256 redeemable = marketPositionManager.getRedeemableAmount(
            user1,
            address(sfUSDC)
        );

        vm.stopPrank();
        assertEq(redeemable, 0);
    }

    /**
     * @notice Tests if a user can borrow from the protocol after supplying USDCs.
     * @dev Supplies USDCs, advances blocks, then borrows based on the loan-to-value (LTV).
     * Checks balances, fees, and borrowable amounts before and after borrowing.
     */
    function test_user_borrow() public {
        uint256 underlyingAmount = 100 * USDCs;
        supplyUnderlyingUSDC(underlyingAmount, user1);

        vm.startPrank(user1);
        vm.warp(block.timestamp + 60);
        uint256 userBalanceBeforeBorrow = usdc.balanceOf(user1);

        uint256 borrowAmount = marketPositionManager.getBorrowableAmount(
            user1,
            address(sfUSDC)
        );

        sfUSDC.borrow(borrowAmount);

        uint256 userBalanceAfterBorrow = usdc.balanceOf(user1);
        uint256 fee = sfUSDC.accruedProtocolFees();

        assertEq(
            borrowAmount,
            userBalanceAfterBorrow - userBalanceBeforeBorrow + fee
        );

        (, uint256 borrowedAmount, uint256 accountSupply, ) = sfUSDC
            .getAccountSnapshot(user1);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        // ASSERTION
        assertEq(borrowedAmount, borrowAmount);
        assertEq(accountSupply, underlyingAmount);
        assertEq(underlyingAmountToRedeem, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMarketPositionManager.UnderCollaterlized.selector
            )
        );
        sfUSDC.borrow(1000);

        vm.stopPrank();
    }

    /**
     * @notice Tests if a user can successfully repay a borrow in USDCs.
     * @dev Supplies USDCs, borrows, then repays the borrow amount and validates share balances.
     */
    function test_user_repay_borrowSFP() public {
        uint256 underlyingAmount = 100 * USDCs;
        supplyUnderlyingUSDC(underlyingAmount, user1);

        vm.startPrank(user1);

        uint256 borrowAmount = (underlyingAmount * LTV_USDC) / 100 / 2;
        sfUSDC.borrow(borrowAmount);

        vm.warp(block.timestamp + 600);
        console.log(borrowAmount);
        uint256 repayAmount = (borrowAmount * 101_000) / 100_000; // ??? CHECK adds 1 % on top. not sure about it

        sfUSDC.repayBorrow(repayAmount);

        (, uint256 borrowedAmountAfterRepay, , ) = sfUSDC.getAccountSnapshot(
            user1
        );

        assertEq(borrowedAmountAfterRepay, 0);

        uint256 underlyingAmountToRedeem = marketPositionManager
            .getRedeemableAmount(user1, address(sfUSDC));

        uint256 userAmountBefore = usdc.balanceOf(user1);
        uint256 feeBalanceBefore = sfUSDC.accruedProtocolFees();
        (uint256 userShareBalance, , , ) = sfUSDC.getAccountSnapshot(user1);

        sfUSDC.redeem(userShareBalance);

        uint256 userAmountAfter = usdc.balanceOf(user1);
        uint256 feeBalanceAfter = sfUSDC.accruedProtocolFees();

        assertEq(
            roundToDecimals(underlyingAmountToRedeem, 2),
            roundToDecimals(
                (userAmountAfter - userAmountBefore) +
                    (feeBalanceAfter - feeBalanceBefore),
                2
            )
        );
    }
}
