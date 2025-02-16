// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

/**
 * @title InterestRateModel
 * @notice This contract models the interest rate for a lending platform
 * @dev Implements the IInterestRateModel interface
 */
contract InterestRateModel is Ownable2Step, IInterestRateModel {
    /**
     * @notice The approximate number of blocks per year that is assumed by the interest rate model
     */
    uint256 public blocksPerYear;

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint256 public multiplierPerBlock;

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint256 public baseRatePerBlock;

    /**
     * @notice The multiplierPerBlock after hitting a specified utilization point
     */
    uint256 public jumpMultiplierPerBlock;

    /**
     * @notice The utilization point at which the jump multiplier is applied
     */
    uint256 public kink;

    /**
     * @notice
     */
    uint256 public constant decimalsMultiplier = 1e18;

    /**
     * @notice A name for user-friendliness, e.g. WBTC
     */
    string public name;

    /**
     * @notice Constructs an interest rate model
     * @param _blocksPerYear The number of blocks per year
     * @param _baseRatePerYear The approximate target base APR, as a mantissa (scaled by decimalsMultiplier)
     * @param _multiplierPerYear The rate of increase in interest rate with respect to utilization (scaled by decimalsMultiplier)
     * @param _jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
     * @param _kink The utilization point at which the jump multiplier is applied
     * @param _name User-friendly name for the new contract
     */
    constructor(
        uint256 _blocksPerYear,
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink,
        string memory _name
    ) Ownable(msg.sender) {
        blocksPerYear = _blocksPerYear;
        name = _name;
        updateJumpRateModelInternal(
            _baseRatePerYear,
            _multiplierPerYear,
            _jumpMultiplierPerYear,
            _kink
        );
    }

    /**
     * @inheritdoc IInterestRateModel
     */
    function utilizationRate(
        uint256 totalCash,
        uint256 totalBorrows,
        uint256 totalReserves
    ) public pure returns (uint256) {
        if (totalReserves > (totalCash + totalBorrows)) {
            return 0;
        }
        uint256 utilization;
        unchecked {
            utilization = totalCash + totalBorrows - totalReserves;
        }

        return
            utilization != 0
                ? (totalBorrows * decimalsMultiplier) / utilization
                : 0;
    }

    /**
     * @inheritdoc IInterestRateModel
     */
    function getBorrowRate(
        uint256 _cash,
        uint256 _borrows,
        uint256 _reserves
    ) public view override returns (uint256) {
        uint256 utilisationRate = utilizationRate(_cash, _borrows, _reserves);

        if (utilisationRate <= kink) {
            return
                (utilisationRate * multiplierPerBlock) /
                decimalsMultiplier +
                baseRatePerBlock;
        } else {
            uint256 normalRate = (kink * multiplierPerBlock) /
                decimalsMultiplier +
                baseRatePerBlock;
            uint256 excessUtil = utilisationRate - kink;

            return
                (excessUtil * jumpMultiplierPerBlock) /
                decimalsMultiplier +
                normalRate;
        }
    }

    /**
     * @inheritdoc IInterestRateModel
     */
    function getSupplyRate(
        uint256 _cash,
        uint256 _borrows,
        uint256 _reserves,
        uint256 _reserveFactorMantissa
    ) public view override returns (uint256) {
        uint256 oneMinusReserveFactor = decimalsMultiplier -
            _reserveFactorMantissa;
        uint256 borrowRate = getBorrowRate(_cash, _borrows, _reserves);
        uint256 rateToPool = (borrowRate * oneMinusReserveFactor) /
            decimalsMultiplier;
        return
            (utilizationRate(_cash, _borrows, _reserves) * rateToPool) /
            decimalsMultiplier;
    }
    /**
     * @inheritdoc IInterestRateModel
     */
    function updateBlocksPerYear(
        uint256 _blocksPerYear
    ) external override onlyOwner {
        blocksPerYear = _blocksPerYear;
        emit NewBlocksPerYear(_blocksPerYear);
    }

    /**
     * @notice Internal function to update the parameters of the interest rate model
     * @param _baseRatePerYear The approximate target base APR, as a mantissa (scaled by decimalsMultiplier)
     * @param _multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by decimalsMultiplier)
     * @param _jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
     * @param _kink The utilization point at which the jump multiplier is applied
     */
    function updateJumpRateModelInternal(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) internal {
        baseRatePerBlock = _baseRatePerYear / blocksPerYear;

        multiplierPerBlock =
            (_multiplierPerYear * decimalsMultiplier) /
            (blocksPerYear * _kink);

        jumpMultiplierPerBlock = _jumpMultiplierPerYear / blocksPerYear;
        kink = _kink;

        emit NewInterestParams(
            baseRatePerBlock,
            multiplierPerBlock,
            jumpMultiplierPerBlock,
            kink
        );
    }

    /**
     * @inheritdoc IInterestRateModel
     */
    function updateJumpRateModel(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) external override onlyOwner {
        updateJumpRateModelInternal(
            _baseRatePerYear,
            _multiplierPerYear,
            _jumpMultiplierPerYear,
            _kink
        );
    }
}
