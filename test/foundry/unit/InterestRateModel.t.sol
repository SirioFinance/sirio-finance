// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {InterestRateModel} from "../../../contracts/InterestRateModel.sol";
import {Params} from "../utils/Params.sol";

interface IInterestRateModelTestEvents {
    event NewBlocksPerYear(uint256 blocksPerYear);
    event NewJumpRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    );
}

/**
 * @title Interest Rate Model Test Suite
 * @notice This contract tests the functionality of the Interest Rate Model.
 * @dev It checks the correct calculation of interest rates, utilization rates, and validates the model's behavior under different conditions.
 */
contract InterestRateModelTest is Test, Params, IInterestRateModelTestEvents {
    address owner;
    address user1;
    InterestRateModel interestRateModel;
    uint8 decimals;

    /**
     * @notice Sets up the initial state for testing the interest rate model.
     * @dev Deploys the `InterestRateModel` contract using parameters defined in `Params`.
     */
    function setUp() public {
        address token = deploymentParams.foundry.WETHAddress;

        user1 = makeAddr("user_one");
        owner = makeAddr("owner");

        interestRateModel = new InterestRateModel(
            interestRates[token].blocksPerYear,
            interestRates[token].baseRatePerYear,
            interestRates[token].multiplerPerYear,
            interestRates[token].jumpMultiplierPerYear,
            interestRates[token].kink,
            interestRates[token].name
        );

        interestRateModel.transferOwnership(owner);

        decimals = interestRates[token].decimals;

        vm.startPrank(owner);
        interestRateModel.acceptOwnership();
        vm.stopPrank();
    }

    /**
     * @notice Tests the values of interest rate model parameters after deployment.
     * @dev Validates the values of `multiplierPerBlock`, `baseRatePerBlock`, and `jumpMultiplierPerBlock`.
     */
    function test_values_after_deployment() public view {
        assertEq(interestRateModel.multiplierPerBlock(), 373056376);
        assertEq(interestRateModel.baseRatePerBlock(), 4756468797);
        assertEq(interestRateModel.jumpMultiplierPerBlock(), 95129375951);
    }

    /**
     * @notice Tests the calculation of the utilization rate.
     * @dev Utilization rate is calculated as `TotalBorrowed / (TotalSupplied - Reserves)`.
     */
    function test_utilizationRate() public view {
        /**
         * @dev utilization rate is calculated by following formula:
         * UtilizationRate = TotalBorrowed / (TotalSupplied - Reserve)
         */

        uint256 cash = 200 * 10 ** decimals;
        uint256 borrows = 100 * 10 ** decimals;
        uint256 reserves = 0;
        uint256 utilizationRate = interestRateModel.utilizationRate(
            cash,
            borrows,
            reserves
        );

        // 100 / 200 + 100 ~33,(3) % (in token decimals)
        assertEq(utilizationRate, 333333333333333333);
    }

    /**
     * @notice Tests if the utilization rate is zero when there are no borrows.
     * @dev Ensures that utilization rate is zero when no amount is borrowed.
     */
    function test_utilizationRate_isZero_when_noBorrow() public view {
        uint256 cash = 200 * 10 ** decimals;
        uint256 borrows = 0;
        uint256 reserves = 0;
        uint256 utilizationRate = interestRateModel.utilizationRate(
            cash,
            borrows,
            reserves
        );

        // 100 / 200 + 100 ~33,(3) % (in token decimals)
        assertEq(utilizationRate, 0);
    }

    /**
     * @notice Tests if the utilization rate is zero when reserves are higher than cash.
     * @dev Ensures that utilization rate is zero when reserves exceed the supplied cash.
     */
    function test_utilization_rate_isZero_when_reserves_areHigh() public view {
        uint256 cash = 200 * 10 ** decimals;
        uint256 borrows = 0;
        uint256 reserves = 400 * 10 ** decimals;

        uint256 utilizationRate = interestRateModel.utilizationRate(
            cash,
            borrows,
            reserves
        );

        assertEq(utilizationRate, 0);
    }

    /**
     * @notice Tests the calculation of the borrow rate before the utilization rate reaches the kink.
     * @dev Borrow rate is calculated as `BorrowRate = UtilizationRate * Multiplier + BaseRateFee`.
     */
    function test_get_borrowRate_before_kink() public view {
        /**
         * @dev Borrow rate is calculated by following formula:
         * BorrowRate = UtilizationRate * Multiplier + BaseRateFee
         */

        uint256 cash = 200 * 10 ** decimals;
        uint256 borrows = 100 * 10 ** decimals;
        uint256 reserves = 0;
        uint256 borrowRate = interestRateModel.getBorrowRate(
            cash,
            borrows,
            reserves
        );

        assertEq(borrowRate, 4880820922);
    }

    /**
     * @notice Tests the calculation of the borrow rate after the utilization rate exceeds the kink.
     * @dev Borrow rate changes once the utilization rate exceeds the kink threshold (80%).
     */
    function test_get_borrowRate_after_kink() public view {
        // kink is 80 %
        uint256 cash = 50 * 10 ** decimals;
        uint256 borrows = 250 * 10 ** decimals;
        uint256 reserves = 0;
        uint256 borrowRate = interestRateModel.getBorrowRate(
            cash,
            borrows,
            reserves
        );

        assertEq(borrowRate, 5067349110);
    }

    /**
     * @notice Tests the calculation of the supply rate.
     * @dev Supply rate is calculated based on the utilization rate and other model parameters.
     */
    function test_get_supplyRate() public view {
        /**
         * @dev Supply rate is calculated by following formula:
         * SupplyRate = UtilizationRate * Multiplier
         */

        uint256 cash = 200 * 10 ** decimals;
        uint256 borrows = 100 * 10 ** decimals;
        uint256 reserves = 0;
        uint256 reservesFactorMantissa = 0;
        uint256 supplyRate = interestRateModel.getSupplyRate(
            cash,
            borrows,
            reserves,
            reservesFactorMantissa
        );
        assertEq(supplyRate, 1626940307);
    }

    /**
     * @notice Tests the `updateJumpRateModel` function.
     * @dev Ensures that only the owner can update the rate parameters, and the new parameters are correctly set.
     */
    function test_updateJumpRateModel() public {
        vm.startPrank(owner);

        // Define new interest rate parameters
        uint256 newBaseRatePerYear = 10 * 1e18; // 10%
        uint256 newMultiplierPerYear = 20 * 1e18; // 20%
        uint256 newJumpMultiplierPerYear = 50 * 1e18; // 50%
        uint256 newKink = 80 * 1e16; // 80%

        // Call the update function
        interestRateModel.updateJumpRateModel(
            newBaseRatePerYear,
            newMultiplierPerYear,
            newJumpMultiplierPerYear,
            newKink
        );

        // Verify that the new parameters are correctly set
        assertEq(
            interestRateModel.baseRatePerBlock(),
            newBaseRatePerYear / interestRateModel.blocksPerYear(),
            "Base rate should be updated correctly"
        );

        uint256 newJumpMultiplier = (newMultiplierPerYear *
            interestRateModel.decimalsMultiplier()) /
            (interestRateModel.blocksPerYear() * interestRateModel.kink());
        assertEq(
            interestRateModel.multiplierPerBlock(),
            newJumpMultiplier,
            "Multiplier should be updated correctly"
        );

        assertEq(
            interestRateModel.jumpMultiplierPerBlock(),
            newJumpMultiplierPerYear / interestRateModel.blocksPerYear(),
            "Jump multiplier should be updated correctly"
        );
        assertEq(
            interestRateModel.kink(),
            newKink,
            "Kink value should be updated correctly"
        );

        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        interestRateModel.updateJumpRateModel(
            newBaseRatePerYear,
            newMultiplierPerYear,
            newJumpMultiplierPerYear,
            newKink
        );
        vm.stopPrank();
    }

    /**
     * @notice Tests the `updateBlocksPerYear` function.
     * @dev Ensures that only the owner can update `blocksPerYear` and the new value is correctly set.
     */
    function test_updateBlocksPerYear() public {
        vm.startPrank(owner);

        // Define a new blocksPerYear value
        uint256 newBlocksPerYear = 2102400; // e.g., for a different blockchain or new block time

        // Expect the `NewBlocksPerYear` event to be emitted
        vm.expectEmit(true, true, true, true);
        emit NewBlocksPerYear(newBlocksPerYear);

        // Call the update function
        interestRateModel.updateBlocksPerYear(newBlocksPerYear);

        // Verify that the `blocksPerYear` is correctly updated
        assertEq(
            interestRateModel.blocksPerYear(),
            newBlocksPerYear,
            "Blocks per year should be updated correctly"
        );

        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );

        interestRateModel.updateBlocksPerYear(newBlocksPerYear);
        vm.stopPrank();
    }
}
