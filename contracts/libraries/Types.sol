// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * @notice Defines the fee rates for borrowing, redeeming, and claiming operations.
 * @param borrowingFeeRate Fee rate for borrowing operations.
 * @param redeemingFeeRate Fee rate for redeeming operations.
 */
struct FeeRate {
    uint16 borrowingFeeRate;
    uint16 redeemingFeeRate;
}

/**
 * @notice Container for borrow balance information
 * @dev Stores the total balance including accrued interest and the index at which the interest was calculated.
 * @param principal Total balance (with accrued interest), after applying the most recent balance-changing action.
 * @param interestIndex Global borrowIndex as of the most recent balance-changing action.
 */
struct BorrowSnapshot {
    uint256 principal;
    uint256 interestIndex;
}

/**
 * @notice Container for supply balance information
 * @dev Stores the principal and index of a user.
 * @param principal Total amount of the underlying asset supplied by the user.
 * @param interestIndex Global borrowIndex as of the most recent balance-changing action.
 */
struct SupplySnapshot {
    uint256 principal;
    uint256 interestIndex;
}

/**
 * @notice Represents a pair in the Supra Oracle system.
 * @dev This struct is used to identify a specific pair in the Supra Oracle system, including whether it is based in USD.
 * @param supraId The unique identifier for the pair in the Supra Oracle system.
 * @param isUsd A boolean indicating whether the pair is denominated in USD (true) or not (false).
 */
struct SupraPair {
    uint256 supraId;
    uint256 pairUsdId;
    bool isUsd;
}
