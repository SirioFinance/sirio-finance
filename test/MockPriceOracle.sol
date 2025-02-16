// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "../contracts/interfaces/ISwapTWAPOracle.sol";
import "../contracts/interfaces/IBaseProtocol.sol";

interface IToken {
    /**
     * @notice Returns the number of decimals the token uses for calculations.
     */
    function decimals() external view returns (uint8);
}

/**
 * @title Price Oracle using Uniswap V2 for price feeds
 * @dev Provides price information by interfacing with Uniswap V2 Router
 */
contract MockPriceOracle is Ownable2Step, ISwapTWAPOracle {
    address public baseToken;
    address public swapRouter;
    address public factory;
    bool public constant isPriceOracle = true;
    uint256 public basePrice = 10 ** 18;
    mapping(address => uint256) public prices;

    /**
     * @notice Initializes the PriceOracle contract
     * @param _baseToken The base token to which all price comparisons will be made
     * @param _swapRouter The Uniswap V2 Router address used to fetch prices
     */
    constructor(address _baseToken, address _swapRouter) Ownable(msg.sender) {
        baseToken = _baseToken;
        swapRouter = _swapRouter;
        _transferOwnership(msg.sender);
    }

    /**
     * @notice Updates the base token address
     * @dev Callable only by the contract owner
     * @param _baseToken New base token address
     */
    function updateBaseToken(address _baseToken) external onlyOwner {
        require(_baseToken != address(0), "invalid baseToken address");
        baseToken = _baseToken;
    }

    /**
     * @notice Fetches and returns the price of a token in terms of the base token
     * @param _token Address of the token to get the price of
     * @return Price of the token in base token units
     */
    function getTokenPrice(address _token) external view returns (uint256) {
        return _getTokenPrice(_token);
    }

    /**
     * @notice Fetches and returns the price of the underlying token for a specified token address
     * @param _token Address of the token to get the underlying price of
     * @return Price of the underlying token in base token units
     */
    function getUnderlyingPrice(
        address _token
    ) external view returns (uint256) {
        address underlyingToken = IBaseProtocol(_token).underlyingToken();
        return _getTokenPrice(underlyingToken);
    }

    function _getTokenPrice(address _token) internal view returns (uint256) {
        uint256 tokenPrice = prices[_token];
        return tokenPrice;
    }

    function changeTokenPrice(address _token, uint256 _newPrice) external {
        prices[_token] = _newPrice;
    }

    function setTimeIntervals(
        uint _updateIntervalMin,
        uint _updateIntervalMax
    ) external {}
}
