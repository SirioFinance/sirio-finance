// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ISupraOracle, ISupraOraclePull, ISupraSValueFeed} from "./interfaces/ISupraOracle.sol";
import {ISwapTWAPOracle} from "./interfaces/ISwapTWAPOracle.sol";
import {SupraPair} from "./libraries/Types.sol";

/**
 * @title SupraOracle Contract
 * @notice Integrates with oracle to fetch and derive asset prices.
 * @dev Inherits from Ownable2Step for ownership management.
 */
contract SupraOracle is Ownable2Step, ISupraOracle {
    /** @notice The oracle contract instance for pulling data. */
    ISupraOraclePull public supra_pull;

    /** @notice The storage contract instance for accessing derived values. */
    ISupraSValueFeed public supra_storage;

    /** @notice The price oracle contract to get backup prices */
    ISwapTWAPOracle private backupOracle;

    /** @notice Supra pull address */
    address public supraPullAddress;

    /** @notice Supra push address */
    address public supraPushAddress;

    /** @notice Mapping of supra ids to token addresses */
    mapping(uint256 => address) private tokenFeed;

    /** @notice acceptable delay of price returned by oracle */
    uint256 timeDelayTolerance = 5 minutes;

    /**
     * @notice Initializes the contract with the main oracle, storage, and backup oracle addresses.
     * @dev Sets up the contract by assigning the provided addresses to the respective oracle and storage interfaces.
     * @param _oracle The address of the main oracle used for pulling price data.
     * @param _storage The address of the storage contract for value feed data.
     * @param _backupOracle The address of the backup oracle to be used if the main oracle is unavailable.
     */
    constructor(
        address _oracle,
        address _storage,
        address _backupOracle
    ) Ownable(msg.sender) {
        supra_pull = ISupraOraclePull(_oracle);
        supra_storage = ISupraSValueFeed(_storage);
        backupOracle = ISwapTWAPOracle(_backupOracle);
        supraPullAddress = _oracle;
        supraPushAddress = _storage;
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function getPrice(
        SupraPair memory _supra
    ) external view override returns (uint256) {
        uint256 tokenPrice = _getUsdPrice(_supra);

        if (tokenPrice == 0) {
            return getBackupPrice(_supra.supraId);
        }

        return tokenPrice;
    }

    /**
     * @notice Retrieves the backup price for a specific token pair.
     * @dev This function fetches the address of the token associated with the given pair index from the `tokenFeed` mapping
     */
    function getBackupPrice(uint256 _pair) public view returns (uint256) {
        address token = tokenFeed[_pair];
        return backupOracle.getTokenPrice(token);
    }

    /**
     * @notice Retrieves the USD price for a given SupraPair.
     * @dev This function fetches price data from the SupraOracle, adjusting for decimals to maintain 18-decimal precision.
     * If the price is already in USD, the function returns it directly. Otherwise, it converts the price using
     * a secondary pair (whbar to USD).
     * @param _supra The SupraPair object containing the IDs to fetch the price. If the pair is already USD-based,
     * the price is returned directly; otherwise, it is converted.
     * @return tokenPrice The calculated price of the token in USD with 18 decimal precision.
     */
    function _getUsdPrice(
        SupraPair memory _supra
    ) internal view returns (uint256 tokenPrice) {
        ISupraSValueFeed.priceFeed memory supraData = supra_storage.getSvalue(
            _supra.supraId
        );

        uint256 currentTime = block.timestamp;
        uint256 timestamp = supraData.time / 1000;

        if ((currentTime - timestamp) > timeDelayTolerance) return 0;

        if (supraData.decimals < 18) {
            uint256 scaleFactor = 10 ** (18 - supraData.decimals);
            supraData.price *= scaleFactor;
        }

        if (_supra.isUsd) {
            tokenPrice = supraData.price;
        } else {
            ISupraSValueFeed.priceFeed memory supraConvertData = supra_storage
                .getSvalue(_supra.pairUsdId);

            timestamp = supraConvertData.time / 1000;
            if ((currentTime - timestamp) > timeDelayTolerance) return 0;

            if (supraConvertData.decimals < 18) {
                uint256 scaleFactor = 10 ** (18 - supraConvertData.decimals);
                supraConvertData.price *= scaleFactor;
            }

            tokenPrice = (supraData.price * supraConvertData.price) / 1e18;
        }
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updatePullAddress(address _oracle) external override onlyOwner {
        supra_pull = ISupraOraclePull(_oracle);
        supraPullAddress = _oracle;
        emit UpdatePullAddress(_oracle);
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updateStorageAddress(
        address _storage
    ) external override onlyOwner {
        supra_storage = ISupraSValueFeed(_storage);
        supraPushAddress = _storage;
        emit UpdatePushAddress(_storage);
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function addBackupFeed(uint256 _feed, address _token) external onlyOwner {
        tokenFeed[_feed] = _token;
        emit AddBackupFeed(_feed, _token);
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updateBackupOracle(address _oracle) external onlyOwner {
        backupOracle = ISwapTWAPOracle(_oracle);
        emit UpdateBackupOracle(_oracle);
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updateTimeInterval(uint256 _timeInterval) external onlyOwner {
        timeDelayTolerance = _timeInterval;
        emit UpdateTimeInterval(_timeInterval);
    }
}
