// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";

/**
 * @title MarketPositionManager Test Suite
 * @dev Test contract for MarketPositionManager functionalities. Uses foundry for unit testing.
 */
contract MarketPositionMangerTest is Helpers {
    address owner;
    address user1;
    address user2;

    /**
     * @dev Sets up the initial state before each test.
     * Initializes users, deploys contracts, assigns ownership, and deals tokens.
     */
    function setUp() public {
        vm.createSelectFork(
            "https://mainnet.infura.io/v3/b812db1f09b54c7aac2fee91b2fc90da",
            19900000
        );

        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");

        deployContracts(owner);

        vm.startPrank(owner);

        marketPositionManager.addToMarket(address(sfHBAR));

        address[] memory tokens = new address[](1);
        uint256[] memory borrowCups = new uint256[](1);
        tokens[0] = address(sfHBAR);
        borrowCups[0] = LTV_HBAR;

        marketPositionManager.setLoanToValue(tokens, borrowCups);

        vm.stopPrank();
    }

    /**
     * @notice Tests if the owner can remove a token market from the market list.
     * @dev The test checks whether the token market is listed, removes it, and verifies the removal.
     */
    function test_remove_markets_asOwner() public {
        vm.startPrank(owner);

        bool isListed = marketPositionManager.markets(address(sfHBAR));
        assertTrue(isListed, "market should be Listed");

        marketPositionManager.removeFromMarket(address(sfHBAR));

        (isListed) = marketPositionManager.markets(address(sfHBAR));
        assertFalse(isListed, "should be removed");

        vm.stopPrank();
    }

    /**
     * @notice Tests removal of a token market by the owner, with a check for an already removed market.
     * @dev Removes a token market from the list and expects a revert if attempting to remove it again.
     */
    function test_remove_fromMarkets_asOwners() public {
        vm.startPrank(owner);

        bool isListed = marketPositionManager.markets(address(sfHBAR));
        assertTrue(isListed, "market should be Listed");

        marketPositionManager.removeFromMarket(address(sfHBAR));

        (isListed) = marketPositionManager.markets(address(sfHBAR));
        assertFalse(isListed, "should be removed");

        vm.expectRevert(abi.encodeWithSignature("AlreadyRemovedFromMarket()"));
        marketPositionManager.removeFromMarket(address(sfHBAR));

        vm.stopPrank();
    }

    /**
     * @notice Tests removal of a token market by a non-owner and expects an unauthorized revert.
     * @dev Attempts to remove a market using a non-owner account and expects a revert for unauthorized access.
     */
    function test_remove_fromMarket_notOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        marketPositionManager.removeFromMarket(address(sfHBAR));
        vm.stopPrank();
    }

    /**
     * @notice Tests adding and removing a token market as the owner.
     * @dev Adds a token market, ensures it is active, then removes it and verifies it is no longer active.
     */
    function test_add_remove_tokenMarket() public {
        vm.startPrank(owner);

        address tokenA = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        assert(marketPositionManager.isMarketActive(tokenA) == false);
        marketPositionManager.addToMarket(tokenA);

        assert(marketPositionManager.isMarketActive(tokenA) == true);

        vm.expectRevert(IMarketPositionManager.AlreadyAddedToMarket.selector);
        marketPositionManager.addToMarket(tokenA);

        marketPositionManager.removeFromMarket(tokenA);
        assert(marketPositionManager.isMarketActive(tokenA) == false);

        vm.stopPrank();
    }

    /**
     * @notice Tests activation and deactivation of a token market by freezing the market.
     * @dev Activates a token market, verifies its status, then freezes it to deactivate and checks status.
     */
    function test_activate_deactivate_tokenMarket() public {
        vm.startPrank(owner);

        address tokenA = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        assert(marketPositionManager.isMarketActive(tokenA) == false);
        marketPositionManager.addToMarket(tokenA);
        assert(marketPositionManager.isMarketActive(tokenA) == true);

        vm.expectRevert(IMarketPositionManager.AlreadyAddedToMarket.selector);
        marketPositionManager.addToMarket(tokenA);
        (tokenA);

        marketPositionManager.freezeTokenMarket(tokenA);
        assert(marketPositionManager.isMarketActive(tokenA) == false);

        vm.stopPrank();
    }

    /**
     * @notice Tests pausing the borrow functionality for specific tokens using the Borrow Guardian role.
     * @dev Pauses borrowing for multiple tokens and verifies the functionality is paused.
     */
    function test_pause_borrowGuardian() public {
        vm.startPrank(owner);

        address tokenA = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address tokenB = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        address[] memory emptyArray = new address[](0);

        vm.expectRevert(IMarketPositionManager.InvalidArrayLength.selector);
        marketPositionManager.pauseBorrowGuardian(emptyArray, true);

        assert(marketPositionManager.borrowGuardianPaused(tokenA) == false);
        assert(marketPositionManager.borrowGuardianPaused(tokenB) == false);

        address[] memory tokens = new address[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;

        marketPositionManager.pauseBorrowGuardian(tokens, true);

        assert(marketPositionManager.borrowGuardianPaused(tokenA) == true);
        assert(marketPositionManager.borrowGuardianPaused(tokenB) == true);

        vm.stopPrank();
    }

    /**
     * @notice Tests pausing the supply functionality for specific tokens using the Supply Guardian role.
     * @dev Pauses supply functionality for multiple tokens and verifies the functionality is paused.
     */
    function test_pause_SupplyBorrowGuardian() public {
        vm.startPrank(owner);

        address tokenA = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address tokenB = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        address[] memory emptyArray = new address[](0);

        vm.expectRevert(IMarketPositionManager.InvalidArrayLength.selector);
        marketPositionManager.pauseSupplyGuardian(emptyArray, true);

        assert(marketPositionManager.supplyGuardianPaused(tokenA) == false);
        assert(marketPositionManager.supplyGuardianPaused(tokenB) == false);

        address[] memory tokens = new address[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;

        marketPositionManager.pauseSupplyGuardian(tokens, true);

        assert(marketPositionManager.supplyGuardianPaused(tokenA) == true);
        assert(marketPositionManager.supplyGuardianPaused(tokenB) == true);
        vm.stopPrank();
    }

    /**
     * @notice Tests that the borrowable amount for a token is 0 when borrowing is paused.
     * @dev Pauses borrowing for a specific token and asserts that no borrowing is allowed.
     */
    function test_getBorrowableAmount_retuns_0_whenPaused() public {
        vm.startPrank(owner);
        address tokenA = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        address[] memory tokens = new address[](1);
        tokens[0] = tokenA;

        marketPositionManager.pauseBorrowGuardian(tokens, true);
        uint256 borrwable = marketPositionManager.getBorrowableAmount(
            owner,
            tokenA
        );
        vm.stopPrank();

        assert(borrwable == 0);
    }

    /**
     * @notice Tests setting the liquidation incentive for the protocol.
     * @dev Sets a valid liquidation incentive and expects a revert for invalid values.
     */
    function test_set_liquidationIncentive() public {
        vm.startPrank(owner);

        vm.expectRevert(
            IMarketPositionManager.InvalidLiquidationIncentive.selector
        );
        marketPositionManager.setLiquidationIncentive(1e19);
        marketPositionManager.setLiquidationIncentive(1e15);

        assert(marketPositionManager.liquidationPercentageProtocol() == 1e15);
        vm.stopPrank();
    }

    /**
     * @notice Tests updating the liquidation risk threshold for the protocol.
     * @dev Sets a new liquidation risk threshold and expects a revert for invalid values.
     */
    function test_update_liquidation_risk_threshold() public {
        vm.startPrank(owner);

        uint256 liquidationRiskThreshold = marketPositionManager
            .liquidateRiskThreshold();

        assert(liquidationRiskThreshold == params.healthcareThresold);
        vm.expectRevert(IMarketPositionManager.InvalidLiquidationRisk.selector);
        marketPositionManager.updateLiquidationRiskThreshold(1e19);

        marketPositionManager.updateLiquidationRiskThreshold(8e17);

        uint256 liquidationRiskAfter = marketPositionManager
            .liquidateRiskThreshold();

        assert(liquidationRiskAfter == 8e17);
        vm.stopPrank();
    }

    /**
     * @notice Tests retrieving account assets for a user.
     * @dev Adds assets to the market, supplies them, and verifies the user’s assets in the account.
     */
    function test_getAccount_assets() public {
        vm.startPrank(owner);

        address token1 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address token2 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        marketPositionManager.addToMarket(token1);
        marketPositionManager.addToMarket(token2);

        vm.stopPrank();

        vm.prank(token1);
        marketPositionManager.validateSupply(owner, token1);

        vm.prank(token2);
        marketPositionManager.validateSupply(owner, token2);

        address[] memory assets = marketPositionManager.getAccountAssets(owner);

        assert(assets.length == 2);
        assert(assets[0] == token1);
        assert(assets[1] == token2);
    }
    /**
     * @notice Tests setting the loan-to-value ratio for a token market and ensures the arrays have valid lengths.
     * @dev Attempts to set loan-to-value ratios and expects a revert for invalid array lengths.
     */
    function test_invalid_setLoanToValue() public {
        vm.startPrank(owner);

        address[] memory tokens = new address[](1);
        uint256[] memory borrowCups = new uint256[](2);
        tokens[0] = address(sfHBAR);
        borrowCups[0] = LTV_HBAR;
        borrowCups[1] = LTV_HBAR;

        vm.expectRevert(IMarketPositionManager.InvalidArrayLength.selector);
        marketPositionManager.setLoanToValue(tokens, borrowCups);

        vm.stopPrank();
    }
}
