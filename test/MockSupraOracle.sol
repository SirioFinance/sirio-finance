// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "../contracts/interfaces/ISupraOracle.sol";
import "../contracts/interfaces/ISwapTWAPOracle.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

/**
 * @title MockSupraOracle Contract
 * @notice Integrates with oracle to fetch and derive asset prices.
 * @dev Inherits from Ownable2Step for ownership management.
 */
contract MockSupraOracle is Ownable2Step, ISupraOracle {
    /// @notice The oracle contract instance for pulling data.
    ISupraOraclePull public supra_pull;

    /// @notice The storage contract instance for accessing derived values.
    ISupraSValueFeed public supra_storage;

    /** @notice The price oracle contract to get backup prices */
    ISwapTWAPOracle public backupOracle;

    address public supraPullAddress;

    address public supraPushAddress;

    mapping(uint256 => uint256) public tokenPrices;

    /** @notice Mapping of supra ids to token addresses */
    mapping(uint256 => address) private tokenFeed;

    /** @notice acceptable delay of price returned by oracle */
    uint256 timeDelayTolerance = 7 days; // for testing purposes

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
        return tokenPrices[_supra.supraId];
    }

    function getMockPrice(
        uint256 _pair
    ) external view returns (ISupraSValueFeed.priceFeed memory) {
        ISupraSValueFeed.priceFeed memory data = ISupraSValueFeed.priceFeed({
            round: 0,
            decimals: 18,
            time: 0,
            price: tokenPrices[_pair]
        });

        return data;
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
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updateBackupOracle(address _oracle) external onlyOwner {
        backupOracle = ISwapTWAPOracle(_oracle);
        emit UpdateBackupOracle(_oracle);
    }

    function changeTokenPrice(uint256 _token, uint256 _newPrice) external {
        tokenPrices[_token] = _newPrice;
    }

    /**
     * @inheritdoc ISupraOracle
     */
    function updateTimeInterval(uint256 _timeInterval) external onlyOwner {
        timeDelayTolerance = _timeInterval;
        emit UpdateTimeInterval(_timeInterval);
    }

    function _getUsdPrice(
        SupraPair memory _supra
    ) internal view returns (uint256 tokenPrice) {
        ISupraSValueFeed.priceFeed memory supraData = supra_storage.getSvalue(
            _supra.supraId
        );

        uint256 currentTime = block.timestamp;
        uint256 timestamp = supraData.time / 1000;
        console.log("currentTime", currentTime);
        console.log("timestamp", timestamp);

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

            timestamp = supraConvertData.time;
            if ((currentTime - timestamp) > timeDelayTolerance) return 0;

            if (supraConvertData.decimals < 18) {
                uint256 scaleFactor = 10 ** (18 - supraConvertData.decimals);
                supraConvertData.price *= scaleFactor;
            }

            tokenPrice = (supraData.price * supraConvertData.price) / 1e18;
        }
    }
}
