// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.17;

/**
 * @title Market Position Manager Interface for SF Protocol
 * @dev Interface for managing market positions, including price oracles, liquidation settings,
 * and token market listings for the SF Protocol.
 */
interface IMarketPositionManager {
    /**
     * @notice Represents market information for a particular token.
     * @dev Tracks account memberships and listing statuses in the market.
     */
    struct MarketInfo {
        mapping(address => bool) accountMembership;
        bool isActive;
    }

    /**
     * @notice Represents a snapshot of an account's current financial state in the protocol.
     * @dev Stores the user's share balance, borrowed amount, and the exchange rate at the time of the snapshot.
     * @param shareBalance The current balance of shares held by the user in the protocol.
     * @param borrowedAmount The current amount borrowed by the user.
     * @param exchangeRate The exchange rate at the time of the snapshot, which is used to convert between underlying assets and shares.
     */
    struct Snapshot {
        uint256 shareBalance;
        uint256 borrowedAmount;
        uint256 exchangeRate;
    }

    /**
     * @notice Sets a new price oracle contract address.
     * @dev Accessible only by the contract owner.
     * @param _priceOracle The address of the new price oracle contract.
     */
    function setPriceOracle(address _priceOracle) external;

    /**
     * @notice Toggles the borrow guardian status for specified tokens.
     * @dev Accessible only by the contract owner.
     * @param _tokens Array of token addresses to toggle.
     * @param _pause Boolean flag to pause or unpause borrowing.
     */
    function pauseBorrowGuardian(
        address[] memory _tokens,
        bool _pause
    ) external;

    /**
     * @notice Toggles the supply guardian status for specified tokens.
     * @dev Accessible only by the contract owner.
     * @param _tokens Array of token addresses to toggle.
     * @param _pause Boolean flag to pause or unpause supplying.
     */
    function pauseSupplyGuardian(
        address[] memory _tokens,
        bool _pause
    ) external;

    /**
     * @notice Sets borrowing caps for specified tokens.
     * @dev Accessible only by the contract owner.
     * @param _tokens Array of token addresses.
     * @param _loanToValue Array of new borrowing caps for each token.
     */
    function setLoanToValue(
        address[] memory _tokens,
        uint256[] memory _loanToValue
    ) external;

    /**
     * @notice Updates the incentive for liquidating a position.
     * @dev Accessible only by the contract owner.
     * @param _liquidiateIncentive New liquidation incentive factor.
     */
    function setLiquidationIncentive(uint256 _liquidiateIncentive) external;

    /**
     * @notice Retrieves the list of asset addresses associated with a specific account.
     * @param _account The address of the account for which to retrieve the assets.
     * @return An array of asset addresses held by the specified account.
     */
    function getAccountAssets(
        address _account
    ) external view returns (address[] memory);
    /**
     * @notice Adds a token to the list of marketable assets.
     * @dev Accessible only by the contract owner.
     * @param _token Address of the token to be added to the market.
     */
    function addToMarket(address _token) external;

    /**
     * @notice Removes a token from the list of marketable assets.
     * @dev Accessible only by the contract owner.
     * @param _token Address of the token to be removed from the market.
     */
    function removeFromMarket(address _token) external;

    /**
     * @notice Freezes a token from the list of marketable assets.
     * @dev Accessible only by the contract owner.
     * @param _token Address of the token to be frozen.
     */
    function freezeTokenMarket(address _token) external;

    /**
     * @notice Checks if the market for a given token is active.
     * @dev This function returns the `isActive` status from the `markets` mapping for the specified token.
     * @param _token The address of the token to check.
     * @return True if the market is active, false otherwise.
     */
    function isMarketActive(address _token) external view returns (bool);

    /**
     * @notice Checks if an account is a member of a given asset's market.
     * @param _account Address of the account to check.
     * @param _token Address of the token to check.
     * @return True if the account is in the asset's market, otherwise false.
     */
    function checkMembership(
        address _account,
        address _token
    ) external view returns (bool);

    /**
     * @notice Retrieves the amount of underlying token a user can redeem.
     * @param _account Address of the user (supplier).
     * @param _token Address of the token.
     * @return The amount that can be redeemed by the user.
     */
    function getRedeemableAmount(
        address _account,
        address _token
    ) external view returns (uint256);

    /**
     * @notice Retrieves the amount of underlying token a user can borrow.
     * @param _account Address of the user (borrower).
     * @param _token Address of the token.
     * @return The amount that can be borrowed by the user.
     */
    function getBorrowableAmount(
        address _account,
        address _token
    ) external view returns (uint256);

    /**
     * @notice Validates a borrow request for a specified amount of underlying token.
     * @param _token Address of the SFProtocolToken.
     * @param _borrower Address of the borrower.
     * @param _borrowUnderlying Amount of the underlying token to borrow.
     * @return True if the borrow is valid, false otherwise.
     */
    function validateBorrow(
        address _token,
        address _borrower,
        uint256 _borrowUnderlying
    ) external returns (bool);

    /**
     * @notice Validates a redeem request for a specified amount of underlying token.
     * @param _token Address of the SFProtocolToken.
     * @param _redeemer Address of the redeemer.
     * @param _redeemUnderlying Amount of the underlying token to redeem.
     */
    function validateRedeem(
        address _token,
        address _redeemer,
        uint256 _redeemUnderlying
    ) external;

    /**
     * @notice Validates that supplying the specified amount of the token is allowed.
     * @param _supplier Address of the supplier.
     * @param _token Address of the token being supplied.
     */
    function validateSupply(address _supplier, address _token) external;

    /**
     * @notice Updates the liquidationRiskPercentage threshold for triggering liquidation.
     * @dev Only the owner can call this function to update the liquidationRiskPercentage threshold.
     * @param _threshold The new liquidationRiskPercentage threshold value.
     */
    function updateLiquidationRiskThreshold(uint256 _threshold) external;

    /**
     * @notice Liquidates a borrower's position if it becomes unhealthy.
     * @dev The function repays part or all of a borrower's undercollateralized loan,
     * calculates the liquidatable amount, validates the liquidation, and seizes collateral
     * proportional to the amount repaid.
     * @param _borrower The address of the borrower to liquidate.
     * @param _token The address of the token in which the borrower has debt.
     */
    function liquidateBorrow(address _borrower, address _token) external;

    /**
     * @notice Liquidates bad debts of a borrower across multiple tokens.
     * @dev This function is called to settle the bad debts of a borrower by liquidating their collateral.
     *  It should only be executed when the borrower's debt exceeds the liquidation threshold.
     * @param _borrowers The address of the borrower whose debts are to be liquidated.
     * */
    function liquidateBadDebts(address[] memory _borrowers) external;

    /** Events */
    event NewMaxLiquidateRateSet(uint16 maxLiquidateRate);
    event LiquidatedBorrower(
        address indexed borrower,
        address indexed liquidator,
        address liquidatedToken,
        uint256 amount
    );
    event LiquidateBadDebt(address indexed borrower);
    event BadDebt(address indexed borrower, uint256 amount);
    event AddToMarket(address token);
    event RemoveFromMarket(address token);
    event FreezeTokenMarket(address token);
    event SetSupraPair(address token, uint256 priceFeed, uint256 usdPairId);
    event NewLiquidationIncentiveSet(uint256 liquidationIncentive);
    event UpdateLiquidationRiskThreshold(uint threshold);

    /** Errors */
    error InvalidCaller();
    error NotListedToken();
    error InvalidOracleAddress();
    error InvalidArrayLength();
    error InvalidMaxLiquidityRate();
    error AlreadyAddedToMarket();
    error AlreadyRemovedFromMarket();
    error MarketAlreadyFroozen();
    error SupplyPaused();
    error BorrowPaused();
    error UnderCollaterlized();
    error PriceError();
    error UserDoesNotHaveAssets();
    error UserDoesNotHaveBorrow();
    error PositionIsNotLiquidatable();
    error PositionIsNotHaveBadDebt();
    error NotEnoughTotalReservesToLiquidate(address);
    error LiquidatorDoesNotHaveEnoughFundsToLiquidate();
    error LiquidationAmountShouldBeMoreThanZero();
    error InvalidLiquidation();
    error CannotLiquidateSelf();
    error InvalidLiquidationIncentive();
    error LiquidatorHealthFactorIsLessThanThreshold();
    error InvalidLiquidationRisk();
    error BadDebtLiquidation();
}
