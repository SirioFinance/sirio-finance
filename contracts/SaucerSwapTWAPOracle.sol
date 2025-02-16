// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {IUniswapV2Pair} from "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {UniswapV2OracleLibrary} from "lib/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import {FixedPoint} from "./libraries/uniswap/FixedPoint.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IToken} from "./interfaces/IToken.sol";
import {ISwapTWAPOracle} from "./interfaces/ISwapTWAPOracle.sol";

/**
 * @title SaucerSwap TWAP Oracle
 * @notice Implements a Time-Weighted Average Price (TWAP) oracle using Uniswap V2 pairs for HBAR/USDC and other token pairs.
 * @dev This contract provides price feeds based on cumulative price data from Uniswap V2 pairs, using SaucerSwap's pricing strategy.
 * It is based on the `UniswapV2OracleLibrary` for calculating TWAP values and supports multiple pairs.
 */
contract SaucerSwapTWAPOracle is ISwapTWAPOracle, Ownable2Step {
    using FixedPoint for *;

    uint256 private updateIntervalMin = 5 minutes;
    uint256 private updateIntervalMax = 15 minutes;
    address private immutable SaucerSWAPv1Factory;
    address private immutable hbar;
    address private immutable usdc;
    address private immutable hbarUsdcPair;
    uint8 private immutable hbar_decimals;
    uint8 private immutable usdc_decimals;

    mapping(address => PairData) public pairs;
    struct PairData {
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
        uint32 blockTimestampLast;
        bool active;
    }

    /**
     * @notice Deploys the SaucerSwap TWAP Oracle contract.
     * @param _factoryV1 Address of the SaucerSwap V1 Factory.
     * @param _hbar Address of the HBAR token.
     * @param _usdc Address of the USDC token.
     */
    constructor(
        address _factoryV1,
        address _hbar,
        address _usdc
    ) Ownable(msg.sender) {
        SaucerSWAPv1Factory = _factoryV1;
        hbar = _hbar;
        usdc = _usdc;

        usdc_decimals = 6;
        hbar_decimals = 8;

        hbarUsdcPair = IUniswapV2Factory(_factoryV1).getPair(_hbar, _usdc);
    }

    /**
     * Owner function to set new values for updating price intervals
     * @param _updateIntervalMin minimal time interval for updating price
     * @param _updateIntervalMax maximal time interval for updating price
     */
    function setTimeIntervals(
        uint _updateIntervalMin,
        uint _updateIntervalMax
    ) external onlyOwner {
        if (_updateIntervalMin > _updateIntervalMax)
            revert InvalidTimeIntervals();

        updateIntervalMin = _updateIntervalMin;
        updateIntervalMax = _updateIntervalMax;
        emit NewTimeIntervals(_updateIntervalMin, _updateIntervalMax);
    }

    /**
     * @notice Updates the price data for a given pair.
     * @param _saucerPair Address of the Uniswap V2 pair to update.
     * @dev Resets the average price if the time elapsed exceeds `updateIntervalMax`.
     */
    function update(address _saucerPair) public onlyOwner {
        PairData storage pair = pairs[_saucerPair];
        if (!pair.active) {
            /// @notice if pair is not active then we should set initial values
            _setInitialValues(pair, _saucerPair);
        } else {
            /// @notice otherwise we set some initial values
            (
                uint256 price0Cumulative,
                uint256 price1Cumulative,
                uint32 blockTimestamp
            ) = UniswapV2OracleLibrary.currentCumulativePrices(_saucerPair);
            uint32 timeElapsed = blockTimestamp - pair.blockTimestampLast;

            // @notice price should not be updated too frequently and also in case if it was not updated for long time inital
            if (timeElapsed < updateIntervalMin) {
                revert PriceFeedIsActual();
            } else if (timeElapsed > updateIntervalMax) {
                // we set pair to false if price is outdated
                pair.active = false;
                // @dev resets values to zero

                pair.price0Average = FixedPoint.uq112x112(uint224(0));
                pair.price1Average = FixedPoint.uq112x112(uint224(0));
            }

            pair.price0Average = _calculateAveragePrice(
                pair.price0CumulativeLast,
                price0Cumulative,
                timeElapsed
            );

            pair.price1Average = _calculateAveragePrice(
                pair.price1CumulativeLast,
                price1Cumulative,
                timeElapsed
            );

            pair.price0CumulativeLast = price0Cumulative;
            pair.price1CumulativeLast = price1Cumulative;
            pair.blockTimestampLast = blockTimestamp;
        }
    }

    /**
     * @inheritdoc ISwapTWAPOracle
     */
    function getTokenPrice(address _token) external view returns (uint256) {
        return _getTokenPrice(_token);
    }

    /**
     * @notice Calculates the price of a given token in terms of USDC.
     * @dev Uses a two-step calculation approach: HBAR to USDC and then the token to HBAR.
     * If the token is USDC, it returns a stable price of `1 USD = 1e18`.
     * If the token is HBAR, the price is scaled to 18 decimals.
     * Otherwise, calculates the price using the HBAR/Token pair and HBAR/USDC pair.
     * @param _token The address of the token to calculate the price for.
     * @return The price of the token in USD (scaled to 18 decimals).
     */
    function _getTokenPrice(address _token) internal view returns (uint256) {
        if (_token == usdc) {
            // @notice assume that usdc price is stable and cannot be manipulated
            return 10 ** 18;
        }

        PairData storage pairHbarUsdc = pairs[hbarUsdcPair];

        uint256 hbarUSDCPrice = _getPriceFromPair(
            pairHbarUsdc,
            hbarUsdcPair,
            hbar
        );

        if (_token == hbar) {
            return _scaleTo(hbarUSDCPrice, usdc_decimals, 18);
        }
        // @notice if not HBAR we should get HBAR price
        address tokenHbarPair = IUniswapV2Factory(SaucerSWAPv1Factory).getPair(
            hbar,
            _token
        );

        PairData storage pairTokenHbar = pairs[tokenHbarPair];
        uint256 tokenHbarPrice = _getPriceFromPair(
            pairTokenHbar,
            tokenHbarPair,
            _token
        );

        uint256 tokenPrice = (tokenHbarPrice * hbarUSDCPrice) /
            10 ** usdc_decimals;

        return _scaleTo(tokenPrice, hbar_decimals, 18);
    }

    /**
     * @dev public function to adjust amounts based on the token decimal differences
     * @param _amount Amount to be scaled
     * @param _fromDecimal Decimals of the amount's original token
     * @param _toDecimal Target decimal to scale the amount to
     * @return Scaled amount adjusted for decimal differences
     */
    function _scaleTo(
        uint256 _amount,
        uint8 _fromDecimal,
        uint8 _toDecimal
    ) internal pure returns (uint256) {
        if (_fromDecimal < _toDecimal) {
            return _amount * 10 ** (_toDecimal - _fromDecimal);
        } else {
            return _amount / (10 ** (_fromDecimal - _toDecimal));
        }
    }

    /**
     * @notice Calculates the price of a token using the average price from the given `FixedPoint` value.
     * @dev Uses `FixedPoint` arithmetic to calculate the value of `_amountIn` based on `_priceAverage`.
     * @param _priceAverage The average price value stored as `FixedPoint.uq112x112`.
     * @param _amointIn The amount of the token to calculate the price for.
     * @return The price in USD based on `_priceAverage` and `_amountIn`.
     */
    function _getPriceFromAverage(
        FixedPoint.uq112x112 storage _priceAverage,
        uint256 _amointIn
    ) internal view returns (uint256) {
        uint256 price;
        unchecked {
            price = _priceAverage.mul(_amointIn).decode144();
        }
        return price;
    }

    /**
     * @notice Sets the initial price values and timestamps for a newly activated pair.
     * @dev Retrieves cumulative prices and the last timestamp from the Uniswap V2 pair.
     * Initializes the `PairData` struct for the given `_saucerPair`.
     * @param _pair The storage reference to the `PairData` struct to initialize.
     * @param _saucerPair The address of the Uniswap V2 pair to set values for.
     */
    function _setInitialValues(
        PairData storage _pair,
        address _saucerPair
    ) internal {
        _pair.active = true;
        _pair.price0CumulativeLast = IUniswapV2Pair(_saucerPair)
            .price0CumulativeLast();
        _pair.price1CumulativeLast = IUniswapV2Pair(_saucerPair)
            .price1CumulativeLast();
        (, , _pair.blockTimestampLast) = IUniswapV2Pair(_saucerPair)
            .getReserves();
    }

    /**
     * @notice Retrieves the price of a token from the given Uniswap V2 pair.
     * @dev Ensures the pair is active and not outdated before calculating the price.
     * Uses the stored `price0Average` or `price1Average` based on the token's position in the pair.
     * @param pair The storage reference to the `PairData` struct containing cumulative and average price information.
     * @param _saucerPair The address of the Uniswap V2 pair.
     * @param _token The address of the token to retrieve the price for.
     * @return The token's price in terms of the base pair's currency.
     */
    function _getPriceFromPair(
        PairData storage pair,
        address _saucerPair,
        address _token
    ) internal view returns (uint256) {
        if (!pair.active) {
            revert PriceFeedIsNotActive();
        }

        if (block.timestamp - pair.blockTimestampLast > updateIntervalMax) {
            revert PricedFeedIsOutdated();
        }

        uint256 amountIn = 10 ** IToken(_token).decimals();
        return
            IUniswapV2Pair(_saucerPair).token0() == _token
                ? _getPriceFromAverage(pair.price0Average, amountIn)
                : _getPriceFromAverage(pair.price1Average, amountIn);
    }

    /**
     * @dev Internal function to compute the TWAP price for a given pair.
     * @param _priceCumulativeLast Previous cumulative price.
     * @param _priceCumulative Current cumulative price.
     * @param _timeElapsed Time elapsed since the last update.
     * @return averagePrice Average price in `FixedPoint.uq112x112` format.
     */
    function _calculateAveragePrice(
        uint256 _priceCumulativeLast,
        uint256 _priceCumulative,
        uint32 _timeElapsed
    ) internal pure returns (FixedPoint.uq112x112 memory averagePrice) {
        unchecked {
            averagePrice = FixedPoint.uq112x112(
                uint224(
                    (_priceCumulative - _priceCumulativeLast) / _timeElapsed
                )
            );
        }

        return averagePrice;
    }
}
