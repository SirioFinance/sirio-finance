// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Helpers} from "../utils/Helpers.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";
import {SupraOracle} from "../../../contracts/SupraOracle.sol";
import {ISupraSValueFeed} from "../../../contracts/interfaces/ISupraOracle.sol";
import {MarketPositionManager} from "../../../contracts/MarketPositionManager.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";
import {InterestRateModel} from "../../../contracts/InterestRateModel.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseProtocol} from "../../../contracts/interfaces/IBaseProtocol.sol";

//   HBAR_USD: 432,
//   HBARX_WHBAR: 427,
//   SAUCE_WHBAR: 425,
//   XSAUCE_WHBAR: 426,
//   USDC_USD: 89,
//   HST_WHBAR: 428,

interface ISupraOracleTest {
    event AddBackupFeed(uint256 supraPair, address token);
    event UpdateBackupOracle(address oracle);
}

/**
 * @notice Sets up the initial test environment by deploying contracts and initializing values.
 * Creates a fork of the Arbitrum Sepolia network for testing.
 * Sets up user addresses and assigns tokens to them.
 */
contract SupraOracleTest is Helpers, ISupraOracleTest {
    address user1;
    address user2;
    address owner;

    address underlyingHBAR;
    address underlyingSFBTC;
    address underlyingSFETH;
    address underlyingSFUSDC;

    function setUp() public {
        vm.createSelectFork(
            "https://arb-sepolia.g.alchemy.com/v2/t5qsfobbgmfUwBeGtP-8QoEWCTekALHS",
            74965084
        );

        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");

        vm.startPrank(owner);
        deployContractsArb(owner, false);
        sfWEth.acceptOwnership();
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

        deal(address(wethArb), user1, WBTC_USER_AMOUNT);
        deal(address(wethArb), user2, WBTC_USER_AMOUNT);
        deal(address(wethArb), owner, WBTC_USER_AMOUNT);
        deal(address(usdc), user1, WBTC_USER_AMOUNT);
        deal(address(usdc), user2, WBTC_USER_AMOUNT);
        deal(address(usdc), owner, WBTC_USER_AMOUNT);

        vm.stopPrank();
    }

    // /**
    //  * @notice Tests the decimals and values returned by the Supra Oracle for different pairs.
    //  * @dev Logs the output of the oracle feed data for manual verification.
    //  */
    // function test_supraOracle_decimals() public view {
    //     console.log("SAUCE_wHBAR");
    //     ISupraSValueFeed.priceFeed memory SAUCE_wHBAR = supraOracle
    //         .getMockPrice(425);
    //     console.log("round", SAUCE_wHBAR.round);
    //     console.log("decimals", SAUCE_wHBAR.decimals);
    //     console.log("time", SAUCE_wHBAR.time);
    //     console.log("price", SAUCE_wHBAR.price);

    //     console.log("HBARX_wHBAR");
    //     ISupraSValueFeed.priceFeed memory HBARX_wHBAR = supraOracle
    //         .getMockPrice(427);
    //     console.log("round", HBARX_wHBAR.round);
    //     console.log("decimals", HBARX_wHBAR.decimals);
    //     console.log("time", HBARX_wHBAR.time);
    //     console.log("price", HBARX_wHBAR.price);

    //     console.log("HST_wHBAR");
    //     ISupraSValueFeed.priceFeed memory HST_wHBAR = supraOracle.getMockPrice(
    //         428
    //     );
    //     console.log("round", HST_wHBAR.round);
    //     console.log("decimals", HST_wHBAR.decimals);
    //     console.log("time", HST_wHBAR.time);
    //     console.log("price", HST_wHBAR.price);

    //     console.log("HBAR_USD");
    //     ISupraSValueFeed.priceFeed memory Hbar = supraOracle.getMockPrice(432);
    //     console.log("round", Hbar.round);
    //     console.log("decimals", Hbar.decimals);
    //     console.log("time", Hbar.time);
    //     console.log("price", Hbar.price);

    //     console.log("xSAUCE_wHBAR");
    //     ISupraSValueFeed.priceFeed memory xSAUCE_wHBAR = supraOracle
    //         .getMockPrice(426);
    //     console.log("round", xSAUCE_wHBAR.round);
    //     console.log("decimals", xSAUCE_wHBAR.decimals);
    //     console.log("time", xSAUCE_wHBAR.time);
    //     console.log("price", xSAUCE_wHBAR.price);

    //     console.log("HSUITE_wHBAR");
    //     ISupraSValueFeed.priceFeed memory HSUITE_wHBAR = supraOracle
    //         .getMockPrice(488);
    //     console.log("round", HSUITE_wHBAR.round);
    //     console.log("decimals", HSUITE_wHBAR.decimals);
    //     console.log("time", HSUITE_wHBAR.time);
    //     console.log("price", HSUITE_wHBAR.price);
    // }

    /**
     * @notice Tests the constructor initialization of the Supra Oracle contract.
     * @dev Verifies that the oracle, storage, and backup oracle addresses are correctly set.
     */
    function test_constructor_initialization() public {
        address mockOracle = makeAddr("mockOracle");
        address mockStorage = makeAddr("mockStorage");
        address mockBackupOracle = makeAddr("mockBackupOracle");

        SupraOracle supraOracleInstance = new SupraOracle(
            mockOracle,
            mockStorage,
            mockBackupOracle
        );

        assertEq(
            address(supraOracleInstance.supra_pull()),
            mockOracle,
            "Oracle address should match the provided address"
        );
        assertEq(
            address(supraOracleInstance.supra_storage()),
            mockStorage,
            "Storage address should match the provided address"
        );

        assertEq(
            supraOracleInstance.supraPullAddress(),
            mockOracle,
            "Supra Pull Address should be the provided oracle address"
        );
        assertEq(
            supraOracleInstance.supraPushAddress(),
            mockStorage,
            "Supra Push Address should be the provided storage address"
        );
    }

    // /**
    //  * @notice Tests various Supra Oracle functions and logs price feed data.
    //  */
    // function test_SupraOracle() public {
    //     ISupraSValueFeed.priceFeed memory data = supraOracle.getMockPrice(1);
    //     console.log("round", data.round);
    //     console.log("decimals", data.decimals);
    //     console.log("time", data.time);
    //     console.log("price", data.price);

    //     uint value = (data.price * 1e18) / 10 ** data.decimals;

    //     console.log("value", value);

    //     uint256 underlyingAmount = 1 * WBTCs;

    //     console.log("address", address(sfHBAR));

    //     vm.startPrank(user1);
    //     wethArb.approve(address(sfWEth), type(uint256).max);
    //     sfWEth.supplyUnderlying(underlyingAmount);

    //     // Borrow
    //     uint256 borrowAmount = marketPositionManager.getBorrowableAmount(
    //         user1,
    //         address(sfWEth)
    //     );

    //     //2523845000000000000000 22 decimals
    //     console.log("borrowAmount", borrowAmount);
    // }

    /**
     * @notice Tests updating the storage and pull oracle addresses.
     * @dev Only the contract owner can update these addresses.
     */
    function test_update_storageAndPull_oracle() public {
        address newOracleAddress = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;

        vm.startPrank(owner);

        supraOracle.updatePullAddress(newOracleAddress);
        supraOracle.updateStorageAddress(newOracleAddress);

        address pullOracle = supraOracle.supraPullAddress();
        address pushOracle = supraOracle.supraPushAddress();

        vm.stopPrank();

        assert(pullOracle == newOracleAddress);
        assert(pushOracle == newOracleAddress);

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        supraOracle.updatePullAddress(newOracleAddress);
        vm.stopPrank();
    }

    /**
     * @notice Tests adding a new backup feed to the Supra Oracle.
     * @dev Verifies that only the owner can add a new backup feed and emits the correct event.
     */
    function test_addBackupFeed() public {
        vm.startPrank(owner);

        uint256 mockFeedId = 432; // Example feed ID
        address mockTokenAddress = makeAddr("mockTokenAddress");

        supraOracle.addBackupFeed(mockFeedId, mockTokenAddress);

        vm.expectEmit(true, true, true, true);
        emit AddBackupFeed(mockFeedId, mockTokenAddress);

        supraOracle.addBackupFeed(mockFeedId, mockTokenAddress);

        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        supraOracle.addBackupFeed(mockFeedId, mockTokenAddress);
        vm.stopPrank();
    }

    /**
     * @notice Tests updating the backup oracle address.
     * @dev Verifies that only the owner can update the backup oracle and emits the correct event.
     */
    function test_updateBackupOracle() public {
        vm.startPrank(owner);

        address newBackupOracle = makeAddr("newBackupOracle");
        supraOracle.updateBackupOracle(newBackupOracle);

        vm.expectEmit(true, true, true, true);
        emit UpdateBackupOracle(newBackupOracle);

        supraOracle.updateBackupOracle(newBackupOracle);

        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        supraOracle.updateBackupOracle(newBackupOracle);
        vm.stopPrank();
    }
}
