// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * @title IInterestRateModel Interface
 * @dev Interface for interest rate models that calculate borrow and supply rates based on market conditions.
 */
interface IInterestRateModel {
    /**
     * @notice Updates the parameters of the interest rate model.
     * @dev Only callable by the contract owner. Typically, this would be a governance contract or a timelock.
     * @param _baseRatePerYear The approximate target base Annual Percentage Rate (APR), as a mantissa (scaled by 1e18).
     * @param _multiplierPerYear The rate at which the interest rate increases with utilization (scaled by 1e18).
     * @param _jumpMultiplierPerYear The rate multiplier applied once utilization surpasses the kink point (scaled by 1e18).
     * @param _kink The utilization point at which the jump multiplier becomes effective.
     */
    function updateJumpRateModel(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) external;

    /**
     * @notice Calculates the market's utilization rate.
     * @dev Utilization rate is defined as the ratio of total borrows to total liquidity (cash plus borrows minus reserves).
     * @param _cash The total cash available in the market.
     * @param _borrows The total amount of borrowed funds in the market.
     * @param _reserves The total reserves held in the market (currently unused in calculations).
     * @return The utilization rate as a mantissa between [0, 1e18].
     */
    function utilizationRate(
        uint256 _cash,
        uint256 _borrows,
        uint256 _reserves
    ) external pure returns (uint256);

    /**
     * @notice Updates the estimated number of blocks per year, used to calculate rates per block.
     * @param _blocksPerYear The new estimate for the number of Ethereum blocks produced per year.
     */
    function updateBlocksPerYear(uint256 _blocksPerYear) external;

    /**
     * @notice Calculates the current borrow rate per block.
     * @dev This is the rate at which borrowers are charged interest on their loans.
     * @param _cash The amount of cash in the market.
     * @param _borrows The amount of total borrows in the market.
     * @param _reserves The amount of total reserves in the market.
     * @return The borrow rate per block as a mantissa (scaled by 1e18).
     */
    function getBorrowRate(
        uint256 _cash,
        uint256 _borrows,
        uint256 _reserves
    ) external view returns (uint256);

    /**
     * @notice Calculates the current supply rate per block.
     * @dev This is the rate at which suppliers earn interest on their deposits.
     * @param _cash The amount of cash available in the market.
     * @param _borrows The total borrows in the market.
     * @param _reserves The total reserves in the market.
     * @param _reserveFactorMantissa The current reserve factor mantissa in the market.
     * @return The supply rate per block as a mantissa (scaled by 1e18).
     */
    function getSupplyRate(
        uint256 _cash,
        uint256 _borrows,
        uint256 _reserves,
        uint256 _reserveFactorMantissa
    ) external view returns (uint256);

    /**
     * @dev Emitted when new interest rate model parameters are set.
     * @param baseRatePerBlock The base rate per block, scaled by 1e18.
     * @param multiplierPerBlock The rate at which the interest rate increases with utilization, per block, scaled by 1e18.
     * @param jumpMultiplierPerBlock The rate multiplier applied once utilization surpasses the kink point, per block, scaled by 1e18.
     * @param kink The utilization point at which the jump multiplier becomes effective.
     */
    event NewInterestParams(
        uint256 baseRatePerBlock,
        uint256 multiplierPerBlock,
        uint256 jumpMultiplierPerBlock,
        uint256 kink
    );
    event NewBlocksPerYear(uint256 blocksPerYear);
}
