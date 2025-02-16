// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * @title IToken Interface
 * @dev Interface to get token decimals.
 */
interface IToken {
    /**
     * @notice Returns the number of decimals the token uses for calculations.
     */
    function decimals() external view returns (uint8);
}
