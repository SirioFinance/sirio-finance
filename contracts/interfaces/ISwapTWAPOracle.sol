// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * @title Interface for Price Oracle
 * @dev Interface for price feeds in decentralized finance protocols.
 */
interface ISwapTWAPOracle {
    /**
     * @notice Fetches and returns the price of a token in terms of the base token
     * @param _token Address of the token to get the price of
     * @return Price of the token in base token units
     */
    function getTokenPrice(address _token) external view returns (uint256);

    /**
     * Owner function to set new values for updating price intervals
     * @param _updateIntervalMin minimal time interval for updating price
     * @param _updateIntervalMax maximal time interval for updating price
     */
    function setTimeIntervals(
        uint _updateIntervalMin,
        uint _updateIntervalMax
    ) external;

    event NewTimeIntervals(
        uint256 new_updateIntervalMin,
        uint256 new_updateIntervalMax
    );

    error InvalidBaseTokenAddress();
    error PriceFeedIsNotActive();
    error PriceFeedIsActual();
    error PricedFeedIsOutdated();
    error InvalidTimeIntervals();
}
