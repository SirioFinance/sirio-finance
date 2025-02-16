// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "contracts/SaucerSwapTWAPOracle.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @title SaucerSwapTWAPOracleTest
 * @notice A test suite for verifying the functionality of the SaucerSwap TWAP Oracle.
 * @dev This contract uses Foundry's `Test` library to test time-weighted average price (TWAP) calculations using the `SaucerSwapTWAPOracle`.
 * It interacts with UniswapV2 pairs and updates the oracle's price data based on the on-chain state.
 */
contract SaucerSwapTWAPOracleTest is Test {
    address factoryV1 = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address factoryV2 = address(0x2);
    address hbar = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH decimals 18
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC decimals 6
    address hbarUsdcPair = address(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    SaucerSwapTWAPOracle oracle;

    address token1 = address(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0); // MATIC decimals 18
    address token2 = address(0xCa14007Eff0dB1f8135f4C25B34De49AB0d42766); // Starknet token 18
    address token3 = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT deciamls 6

    address pair1 = address(0x819f3450dA6f110BA6Ea52195B3beaFa246062dE); // WETH - MATIC
    address pair2 = address(0x311ce099976D72F9e093690FD1408a14Ad4ED4DA); // WETH - STRK
    address pair3 = address(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852); // WETH - usdt

    event NewTimeIntervals(
        uint256 new_updateIntervalMin,
        uint256 new_updateIntervalMax
    );

    function setUp() public {
        vm.createSelectFork(
            "https://mainnet.infura.io/v3/b812db1f09b54c7aac2fee91b2fc90da",
            20876176
        );

        oracle = new SaucerSwapTWAPOracle(factoryV1, hbar, usdc);
    }

    /**
     * @notice Tests the `update` and `getTokenPrice` functionality of the `SaucerSwapTWAPOracle`.
     * @dev This function:
     * 1. Synchronizes the on-chain state of the Uniswap V2 pairs (`sync()`).
     * 2. Updates the oracle's price data for the HBAR/USDC, WETH/MATIC, and WETH/STRK pairs.
     * 3. Warps the block timestamp forward by 10 minutes to simulate time passage.
     * 4. Re-syncs the pairs and updates the oracle again.
     * 5. Asserts the calculated TWAP prices against expected values for MATIC, Starknet, USDC, and HBAR.
     */
    function test_updateAndGetTokenPrice() external {
        IUniswapV2Pair(pair1).sync();
        IUniswapV2Pair(pair2).sync();
        IUniswapV2Pair(pair3).sync();
        IUniswapV2Pair(hbarUsdcPair).sync();

        oracle.update(hbarUsdcPair);
        oracle.update(pair1);
        oracle.update(pair2);
        oracle.update(pair3);

        vm.warp(block.timestamp + 10 minutes);
        // update prices on the pairs
        IUniswapV2Pair(pair1).sync();
        IUniswapV2Pair(pair2).sync();
        IUniswapV2Pair(pair3).sync();
        IUniswapV2Pair(hbarUsdcPair).sync();

        oracle.update(hbarUsdcPair);
        oracle.update(pair1);
        oracle.update(pair2);
        oracle.update(pair3);

        /**
         * @notice adjustmentFactor here is used to adjust the price because contract
         * uses constant decimals values for Hedera Mainnet that is differ from forked values on Ethereum.
         */
        uint256 adjustmentFactor = 1e10;

        uint256 price1 = oracle.getTokenPrice(token1);
        assertApproxEqAbs(price1 / adjustmentFactor, 3822e14, 10e15);
        uint256 price2 = oracle.getTokenPrice(token2);
        assertApproxEqAbs(price2 / adjustmentFactor, 4011e14, 10e15);
        uint256 price3 = oracle.getTokenPrice(usdc);
        assertApproxEqAbs(price3, 1e18, 0);
        uint256 price4 = oracle.getTokenPrice(hbar);
        assertApproxEqAbs(price4, 24828e17, 10e16);
        uint256 price5 = oracle.getTokenPrice(token3);
        assertApproxEqAbs(price5 / adjustmentFactor, 1e18, 1e15);
    }

    /**
     * @notice Tests the `setTimeIntervals` functionality of the `SaucerSwapTWAPOracle`.
     * 1. Owner sets new time intervals for updating the price data, checks that the right event is emited.
     * 2. Checks that the owner can set new time intervals for updating the price data.
     */
    function test_owner_should_be_able_to_set_time_intervals() external {
        vm.expectEmit(true, true, false, true);
        emit NewTimeIntervals(10 minutes, 20 minutes);
        oracle.setTimeIntervals(10 minutes, 20 minutes);

        // Slot 0 - is owner
        // Slot 1 - is pendingOwner
        uint256 slot2 = uint256(vm.load(address(oracle), bytes32(uint256(2))));
        uint256 slot3 = uint256(vm.load(address(oracle), bytes32(uint256(3))));
        assertEq(slot2, 10 minutes);
        assertEq(slot3, 20 minutes);
    }

    /**
     * @notice Tests the `setTimeIntervals` functionality of the `SaucerSwapTWAPOracle`.
     * 1. Owner tries to set invalid time intervals for updating the price data, checks that the
     * function is reverted with the right error message.
     */
    function test_owner_cannot_set_invalid_time_intervals() external {
        /// cast sig "InvalidTimeIntervals()" -> 0x5e70193a
        vm.expectRevert(bytes4(0x5e70193a));
        oracle.setTimeIntervals(20 minutes, 10 minutes);
    }

    /**
     * @notice Tests the `update` functionality of the `SaucerSwapTWAPOracle`.
     * 1. Synchronizes the on-chain state of the Uniswap V2 pair.
     * 2. Updates the oracle's price data for the HBAR/USDC pair.
     * 3. Warps the block timestamp forward by 10 minutes to simulate time passage.
     * 4. Re-syncs the pair and updates the oracle again.
     * 5. Asserts that the price data is not updated if the time elapsed is less than the minimum interval.
     */
    function test_you_should_not_be_able_to_update_price_too_frequent()
        external
    {
        IUniswapV2Pair(pair1).sync();

        oracle.update(hbarUsdcPair);

        vm.warp(block.timestamp + 10 minutes);
        IUniswapV2Pair(hbarUsdcPair).sync();

        oracle.update(hbarUsdcPair);

        /// cast sig "PriceFeedIsActual()" -> 0x9146c3dc
        vm.expectRevert(bytes4(0x9146c3dc));
        oracle.update(hbarUsdcPair);
    }

    /**
     * @notice Tests the `update` functionality of the `SaucerSwapTWAPOracle`.
     * 1. Synchronizes the on-chain state of the Uniswap V2 pair.
     * 2. Updates the oracle's price data for the HBAR/USDC pair.
     * 3. Warps the block timestamp forward by 30 minutes to simulate time passage.
     * 4. Re-syncs the pair and updates the oracle again.
     * 5. Asserts that the price data is reset if the time elapsed exceeds the maximum interval.
     */
    function test_if_price_feed_is_outdated_you_should_not_get_price()
        external
    {
        IUniswapV2Pair(pair1).sync();

        oracle.update(hbarUsdcPair);

        vm.warp(block.timestamp + 10 minutes);
        IUniswapV2Pair(hbarUsdcPair).sync();
        oracle.getTokenPrice(hbar);
        vm.warp(block.timestamp + 30 minutes);

        /// cast sig "PricedFeedIsOutdated()" -> 0x043e9cc8
        vm.expectRevert(bytes4(0x043e9cc8));
        oracle.getTokenPrice(hbar);
    }

    /**
     * @notice Tests the `getTokenPrice` functionality of the `SaucerSwapTWAPOracle`.
     * 1. Asserts that the `getTokenPrice` function will revert if price feed is not active.
     */
    function test_if_price_feed_is_not_active_you_should_not_get_price()
        external
    {
        /// cast sig "PriceFeedIsNotActive()" -> 0xf7b0d1ca
        vm.expectRevert(bytes4(0xf7b0d1ca));
        oracle.getTokenPrice(hbar);
    }
}
