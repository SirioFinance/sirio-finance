// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * @title IBaseProtocol Interface
 * @dev Interface for the HBAR Protocol defining the lending operations and their configurations.
 */
interface IBaseProtocol {
    /**
     * @notice Returns the address of the market position manager.
     * @return Address of the market position manager.
     */
    function marketPositionManager() external view returns (address);

    /**
     * @notice Returns the address of the underlying token used in the market.
     * @return Address of the underlying token.
     */
    function underlyingToken() external view returns (address);

    /**
     * @notice Returns the total amount of outstanding borrows of the underlying in this market.
     * @return Total outstanding borrows.
     */
    function totalBorrows() external view returns (uint256);

    /**
     * @notice Returns the total Reserves of the Contract Protocol
     * @return Total Reserve balance.
     */
    function totalReserves() external view returns (uint256);

    /**
     * @notice Returns the decimals of the underlying token used in the market.
     * @return Decimals of the underlying token.
     */
    function underlyingDecimals() external view returns (uint8);

    /**
     * @notice Calculates the fee discount for borrowing based on the number of NFTs held by the user.
     * @dev The discount is applied to the base fee rate and varies depending on the number of NFTs owned by the user. More NFTs result in a higher discount.
     * @param _user The address of the user whose fee discount is being calculated.
     * @param _baseFee The original fee rate, before any discounts are applied. This rate is scaled by 1e4 (e.g., 100 = 1%).
     * @return reducedFee The adjusted fee rate after applying the discount for NFT ownership. This rate is also scaled by 1e4.
     */
    function checkNftDiscount(
        address _user,
        uint16 _baseFee
    ) external view returns (uint16 reducedFee);

    /**
     * @notice Returns the total underlying balance of the protocol.
     * @return Total underlying balance.
     */
    function getUnderlyingBalance() external view returns (uint256);

    /**
     * @notice Retrieves the user's account snapshot, including share balance, borrowed amount, and exchange rate.
     * @param _account Address of the user.
     * @return Tuple of user's share balance, borrowed amount, supplied amount and claimable interest.
     */
    function getAccountSnapshot(
        address _account
    ) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns the stored exchange rate.
     * @return The current exchange rate, scaled by 1e18.
     */
    function getExchangeRateStored() external view returns (uint256);

    /**
     * @notice Supplies underlying assets to the lending pool.
     * @dev This function reverts if the contract is paused.
     * @param _underlyingAmount The amount of the underlying asset to supply.
     */
    function supplyUnderlying(uint256 _underlyingAmount) external;

    /**
     * @notice Supplies underlying assets to the lending pool.
     * @dev This function reverts if the contract is paused.
     */
    function supplyUnderlyingNative() external payable;

    /**
     * @notice Redeems underlying assets by burning the protocol's tokens (shares).
     * @dev This function reverts if the contract is paused.
     * @param _shareAmount The amount of protocol tokens (shares) to redeem.
     */
    function redeem(uint256 _shareAmount) external;

    /**
     * @notice Redeems a specific amount of underlying assets.
     * @dev This function reverts if the contract is paused.
     * @param _underlyingAmount The exact amount of the underlying asset to redeem.
     */
    function redeemExactUnderlying(uint256 _underlyingAmount) external;

    /**
     * @notice Borrows underlying assets from the lending pool.
     * @dev This function reverts if the contract is paused.
     * @param _underlyingAmount The amount of underlying to borrow.
     */
    function borrow(uint256 _underlyingAmount) external;

    /**
     * @notice Repays borrowed underlying assets and possibly gets back protocol tokens(shares).
     */
    function repayBorrowNative() external payable;

    /**
     * @notice Repays borrowed underlying assets and possibly gets back protocol tokens (shares).
     * @param _repayAmount The amount of underlying assets to repay.
     */
    function repayBorrow(uint256 _repayAmount) external;

    /**
     * @notice Allows a sender to repay a borrow on behalf of another user.
     * @param _borrower The user whose debt is being repaid.
     * @param _repayAmount The amount to repay, or the special value -1 to repay the full amount.
     */
    function repayBorrowBehalf(
        address _borrower,
        uint256 _repayAmount
    ) external;

    /**
     * @notice Allows a sender to repay a borrow on behalf of another user.
     * @param _borrower The user whose debt is being repaid.
     */
    function repayBorrowBehalfNative(address _borrower) external payable;

    /**
     * @notice Initiates the liquidation of a borrower's position.
     * @param _liquidator The account initiating the liquidation.
     * @param _borrower The account whose position is being liquidated.
     * @param _liquidateUnderlying The amount being repaid during the liquidation.
     */
    function liquidateBorrow(
        address _liquidator,
        address _borrower,
        uint256 _liquidateUnderlying
    ) external;

    /**
     * @notice Liquidates a portion of the borrower's debt by transferring the specified liquidated amount from the contract's reserves.
     * @dev Accrues interest before performing the liquidation and updates both the borrower's debt and the contract's reserves.
     * @param _borrower The address of the borrower whose debt will be partially liquidated.
     * @param _liquidateAmount The amount of the borrower's debt to liquidate.
     */
    function liquidateBadDebt(
        address _borrower,
        uint256 _liquidateAmount
    ) external;

    /**
     * @notice Seizes the specified amount of collateral from the borrower in the case of a bad debt situation.
     * @dev Calculates the equivalent share amount based on the exchange rate and reduces the borrower's balance and total reserves.
     * @param _borrower The address of the borrower whose collateral is being seized.
     * @param _seizeUnderlying The amount of underlying collateral to seize.
     */
    function seizeBadCollateral(
        address _borrower,
        uint256 _seizeUnderlying
    ) external;

    /**
     * @notice Transfers collateral tokens to the liquidator.
     * @param _liquidator The account receiving the seized collateral.
     * @param _borrower The account from which collateral is seized.
     * @param _seizeTokens The amount of tokens to seize.
     * @param _percentForProtocol Percentage amount for Protocol.
     */
    function seizeCollateral(
        address _liquidator,
        address _borrower,
        uint256 _seizeTokens,
        uint256 _percentForProtocol
    ) external;

    /**
     * @notice Returns the amount of the underlying token supplied by a user.
     * @param _account The address of the user.
     * @return The total amount of the underlying token supplied by the user.
     */
    function getSuppliedAmount(
        address _account
    ) external view returns (uint256);

    /**
     * @notice Returns the current per-block borrow interest rate.
     * @return The borrow interest rate per block, scaled by 1e18.
     */
    function borrowRatePerBlock() external view returns (uint256);

    /**
     * @notice Returns the current per-block supply interest rate.
     * @return The supply interest rate per block, scaled by 1e18.
     */
    function supplyRatePerBlock() external view returns (uint256);

    /**
     * @notice Updates the maximum amount that can be borrowed.
     * @dev This function can only be called by the contract owner.
     * @param _newMaxBorrows The new maximum borrow limit to be set.
     */
    function updateMaxBorrows(uint256 _newMaxBorrows) external;

    /**
     * @notice Updates the maximum supply cap for the token.
     * @dev This function can only be called by the contract owner.
     * @param _newMaxSupply The new maximum supply limit to be set.
     */
    function updateMaxSupply(uint256 _newMaxSupply) external;

    /**
     * @notice Converts a specified amount of accrued protocol fees into reserves.
     * @dev This function allows the owner to transfer a specified amount of accrued
     * protocol fees to the total reserves. It reverts if the specified amount exceeds
     * the accrued protocol fees.
     */
    function convertFeesToReserves(uint256 _amount) external;

    /**
     * @notice Pauses the contract to prevent all pausable actions.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract to allow all previously pausable actions.
     */
    function unpause() external;

    /**
     * Events
     */
    event InterestAccrued();
    event UnderlyingSupplied(
        address indexed supplier,
        uint256 underlyingAmount,
        uint256 shareAmount,
        uint256 supplyIndex
    );
    event Borrow(
        address indexed borrower,
        uint256 borrowAmount,
        uint256 accountBorrows,
        uint256 totalBorrows,
        uint256 borrowIndex
    );
    event RepayBorrow(
        address indexed payer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event ReservesAdded(uint256 addAmount, uint256 newTotalReserves);
    event ReservesDeducted(uint256 minusAmount, uint256 newTotalReserves);

    event LiquidateBorrow(
        address indexed liquidator,
        address indexed borrower,
        uint256 repayAmount,
        address tokenCollateral,
        address borrowedToken
    );
    event SeizeCollateral(
        address indexed borrower,
        address indexed liquidator,
        uint256 totalAmount,
        uint256 liquidatorAmount,
        uint256 protocolAmount
    );

    event SeizeBadDebtCollateral(
        address indexed borrower,
        address indexed liquidator,
        uint256 totalAmount
    );
    event WithdrawFees(address indexed from, uint256 amount);
    event RemoveBorrow(address indexed borrower, uint256 amount);
    event NewMaxBorrows(uint256 newMaxBorrows);
    event NewMaxSupply(uint256 newMaxSupply);
    event SwapFeesToReserves(uint256 amount);
    event WithdrawFunds(
        address indexed withdrawer,
        uint256 underlyingAmount,
        uint256 shareAmount
    );
    event BurnShares(address from, uint256 amount);
    event MintShares(address from, uint256 amount);

    /**
     * Errors
     */
    error InvaildSupplyAmount();
    error LowShareAmount();
    error InsuficientPoolAmountToBorrow();
    error InvalidRepayAmount();
    error FailedWithdrawFunds();
    error FailedSendExcessBack();
    error InvalidRedeemShareAmount();
    error InsufficientShares();
    error InsufficientPool();
    error InvalidAddress();
    error InvalidExchangeRateMantissa();
    error NotManager();
    error FailedAssociate();
    error NoBorrowsToRepay();
    error InvalidBalance();
    error InvalidFeeAmount();
    error CannotLiquidateSelf();
    error MaxProtocolBorrowCap();
    error MaxProtocolSupplyCap();
    error NotEnoughTokens();
    error NotValidBorrower();
    error NotValidMarket();
}
