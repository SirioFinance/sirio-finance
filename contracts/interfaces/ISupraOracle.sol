// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {SupraPair} from "../libraries/Types.sol";

/**
 * @title Interface for SupraOraclePull
 * @dev Interface to interact with the oracle to pull verified price data.
 */
interface ISupraOraclePull {
    /**
     * @dev Struct to store price data fetched from the oracle.
     * @param pairs Array of asset pair identifiers.
     * @param prices Array of asset prices corresponding to the pairs.
     * @param decimals Array of decimal places for each price.
     */
    struct PriceData {
        uint256[] pairs;
        uint256[] prices;
        uint256[] decimals;
    }

    /**
     * @notice Verifies oracle proof and returns the price data.
     * @param _bytesproof The proof to be verified by the oracle.
     * @return PriceData Struct containing pairs, prices, and decimals.
     */
    function verifyOracleProof(
        bytes calldata _bytesproof
    ) external returns (PriceData memory);
}

/**
 * @title Interface for SupraSValueFeed
 * @dev Interface for getting derived values of asset pairs.
 */
interface ISupraSValueFeed {
    // Data structure to hold the pair data
    struct priceFeed {
        uint256 round;
        uint256 decimals;
        uint256 time;
        uint256 price;
    }
    /**
     * @dev Struct to store derived data from two asset pairs.
     * @param roundDifference The difference in rounds between two pairs.
     * @param derivedPrice The derived price after operation.
     * @param decimals The decimal precision of the derived price.
     */
    struct derivedData {
        int256 roundDifference;
        uint256 derivedPrice;
        uint256 decimals;
    }

    /**
     * @notice Fetches the derived value between two asset pairs.
     * @param pair_id_1 The first pair identifier.
     * @param pair_id_2 The second pair identifier.
     * @param operation The operation to perform (0 for multiplication, 1 for division).
     * @return derivedData Struct containing the result of the operation.
     */
    function getDerivedSvalue(
        uint256 pair_id_1,
        uint256 pair_id_2,
        uint256 operation
    ) external view returns (derivedData memory);

    /**
     * @notice Retrieve the price feed data for a single data pair.
     * @dev Fetches the price feed for the specified pair index.
     * @param _pairIndex The index of the pair for which the price data is requested.
     * @return priceFeed The price feed data for the specified pair.
     */
    function getSvalue(
        uint256 _pairIndex
    ) external view returns (priceFeed memory);

    /**
     * @notice Fetch the price feed data for multiple data pairs.
     * @dev Fetches the price feed for an array of pair indexes.
     * @param _pairIndexes An array of pair indexes for which the price data is requested.
     * @return priceFeed[] An array of price feed data corresponding to the specified pair indexes.
     */
    function getSvalues(
        uint256[] memory _pairIndexes
    ) external view returns (priceFeed[] memory);
}

/**
 * @title Interface for Supra Price Oracle
 * @dev Interface for price feeds in decentralized finance protocols.
 */
interface ISupraOracle {
    /**
     * @notice Fetches the current price of the given token pair.
     * @dev This function first tries to get the USD price using the `_getUsdPrice` function.
     * If the returned price is zero, it falls back to fetching the backup price using `getBackupPrice`.
     * @param _supra The `SupraPair` structure containing the token pair details.
     * @return uint256 The current price of the token pair in USD (in the smallest unit of the token).
     */

    function getPrice(SupraPair memory _supra) external view returns (uint256);

    /**
     * @notice Updates the oracle contract address.
     * @param _oracle The new oracle contract address.
     */
    function updatePullAddress(address _oracle) external;

    /**
     * @notice Updates the storage contract address.
     * @param _storage The new storage contract address.
     */
    function updateStorageAddress(address _storage) external;

    /**
     * @notice Adds backup feed for price oracle to get a token price
     * @param _feed supra feed id
     * @param _token token which price is requested
     */
    function addBackupFeed(uint256 _feed, address _token) external;

    /**
     * @notice Updates the address of the backup oracle.
     * @dev This function can only be called by the contract owner. It sets a new address for the backup oracle and emits the `UpdateBackupOracle` event.
     * @param _oracle The address of the new backup oracle.
     */
    function updateBackupOracle(address _oracle) external;

    /**
     * @notice Updates the time interval used for delay tolerance.
     * @dev Only the contract owner can call this function.
     * @param _timeInterval The new time interval value to be set (in seconds).
     */
    function updateTimeInterval(uint256 _timeInterval) external;

    /**
     * Events
     */
    event UpdatePullAddress(address pullContract);
    event UpdatePushAddress(address pushContract);
    event PairPrice(uint256 pair, uint256 price, uint256 decimals);
    event AddBackupFeed(uint256 supraPair, address token);
    event UpdateBackupOracle(address oracle);
    event UpdateTimeInterval(uint256 timeInterval);
}
