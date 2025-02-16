// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {IMarketPositionManager} from "./interfaces/IMarketPositionManager.sol";
import {IBaseProtocol} from "./interfaces/IBaseProtocol.sol";
import {BaseProtocol} from "./BaseProtocol.sol";
import {FeeRate, BorrowSnapshot, SupplySnapshot} from "./libraries/Types.sol";

/**
 * @title HBAR Protocol Contract
 * @notice This contract manages the core functionalities of the lending protocol including
 * borrowing, supplying, interest accrual, and collateral management on the Hedera network.
 * @dev The contract inherits from ERC20 for token management, Ownable2Step for ownership controls,
 * Pausable for pausing contract functions, ReentrancyGuard for preventing re-entrant calls, and
 * it implements the IBaseProtocol and interfaces with HederaTokenService for token operations.
 */
contract HBARProtocol is BaseProtocol {
    /// variables to store value of the msg.value during the calculations
    uint256 tempMsgValue;

    /**
     * @notice Constructs the HBARProtocol contract.
     * @param _feeRate Initial fee rate settings for the contract.
     * @param _underlyingToken The token that will be used as the underlying asset.
     * @param _interestRateModel The contract address for the interest rate model.
     * @param _marketPositionManager The contract managing market positions.
     * @param _nebulaGenesis The address of the NFT collection used for discount calculations.
     * @param _nebulaRegen The address of the NFT collection used for discount calculations.
     * @param _cosmicCyphters The address of the NFT collection used for discount calculations.
     * @param _initialExchangeRateMantissa The initial exchange rate, expressed as mantissa.
     * @param _maxBorrowCap Maximum amount that can be borrowed of a given asset.
     * @param _maxSupplyCap Maximum amount that can be supplied of a given asset.
     * @param _reserveFactorMantissa Percentage of interest added to reserves coming from total borrows.
     */
    constructor(
        FeeRate memory _feeRate,
        address _underlyingToken,
        address _interestRateModel,
        address _marketPositionManager,
        address _nebulaGenesis,
        address _nebulaRegen,
        address _cosmicCyphters,
        uint256 _initialExchangeRateMantissa,
        uint8 _underlyingDecimals,
        uint256 _maxBorrowCap,
        uint256 _maxSupplyCap,
        uint256 _reserveFactorMantissa
    )
        BaseProtocol(
            _feeRate,
            _underlyingToken,
            _interestRateModel,
            _marketPositionManager,
            _nebulaGenesis,
            _nebulaRegen,
            _cosmicCyphters,
            _initialExchangeRateMantissa,
            _underlyingDecimals,
            _maxBorrowCap,
            _maxSupplyCap,
            _reserveFactorMantissa
        )
    {}

    /**
     * modifier that sets the transaction amount before and after function execution
     */
    modifier setTmpMsgValue() {
        tempMsgValue = msg.value;
        _;
        tempMsgValue = 0;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function getUnderlyingBalance() public view override returns (uint256) {
        return address(this).balance - accruedProtocolFees - tempMsgValue;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function supplyUnderlyingNative() external payable override whenNotPaused {
        _accrueInterest();
        uint256 _underlyingAmount = msg.value;
        if (_underlyingAmount == 0) revert InvaildSupplyAmount();

        if ((getUnderlyingBalance()) >= maxProtocolSupplyCap)
            revert MaxProtocolSupplyCap();

        IMarketPositionManager(marketPositionManager).validateSupply(
            msg.sender,
            address(this)
        );
        if (accountSupplies[msg.sender].principal > 0) {
            uint256 accountPrincipalUpdated = _supplyBalanceStoredInternal(
                msg.sender,
                supplyIndex
            );
            accountSupplies[msg.sender].principal = accountPrincipalUpdated;
        }
        accountSupplies[msg.sender].principal += _underlyingAmount;
        accountSupplies[msg.sender].interestIndex = supplyIndex;

        /**
         * @dev Adds the `underlyingAmount` because `msg.value` (which equals `underlyingAmount`) accounts for the contract's balance.
         * The amount is added to `totalReserves` because it is subtracted from `totalBalance`, and we need to account for this incoming balance.
         */
        uint256 shareAmount = _calculateAmountInShares(
            totalBorrows,
            (totalReserves + _underlyingAmount),
            _underlyingAmount
        );

        if (shareAmount == 0) revert LowShareAmount();
        _mintShares(msg.sender, shareAmount);

        emit UnderlyingSupplied(
            msg.sender,
            _underlyingAmount,
            shareAmount,
            supplyIndex
        );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function redeem(
        uint256 _shareAmount
    ) external override nonReentrant whenNotPaused {
        _accrueInterest();
        _redeem(payable(msg.sender), _shareAmount);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function redeemExactUnderlying(
        uint256 _underlyingAmount
    ) external override nonReentrant whenNotPaused {
        _accrueInterest();
        uint256 shareAmount = _calculateAmountInShares(
            totalBorrows,
            totalReserves,
            _underlyingAmount
        );
        _redeem(payable(msg.sender), shareAmount);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function borrow(
        uint256 _underlyingAmount
    ) external override nonReentrant whenNotPaused {
        _accrueInterest();
        if ((_underlyingAmount + totalBorrows) > maxProtocolBorrowCap)
            revert MaxProtocolBorrowCap();

        address payable borrower = payable(msg.sender);
        bool canBorrow = IMarketPositionManager(marketPositionManager)
            .validateBorrow(address(this), borrower, _underlyingAmount);

        if (!canBorrow) revert NotValidBorrower();

        if (getUnderlyingBalance() < _underlyingAmount)
            revert InsuficientPoolAmountToBorrow();

        uint256 accountBorrowsPrev = _borrowBalanceStoredInternal(
            borrower,
            borrowIndex
        );
        uint256 accountBorrowsNew = accountBorrowsPrev + _underlyingAmount;
        uint256 totalBorrowsNew = totalBorrows + _underlyingAmount;

        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        uint16 fee = checkNftDiscount(borrower, feeRate.borrowingFeeRate);

        _doTransferOutWithFee(borrower, _underlyingAmount, fee);

        emit Borrow(
            borrower,
            _underlyingAmount,
            accountBorrowsNew,
            totalBorrows,
            borrowIndex
        );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowNative()
        external
        payable
        override
        nonReentrant
        whenNotPaused
    {
        if (msg.value == 0) revert InvalidRepayAmount();
        _repayBorrowInternal(msg.sender, msg.sender, msg.value);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowBehalfNative(
        address _borrower
    ) external payable override nonReentrant whenNotPaused {
        if (msg.value == 0) revert InvalidRepayAmount();
        _repayBorrowInternal(msg.sender, _borrower, msg.value);
    }

    /**
     * @notice Internal function that handles the repayment of borrowed funds on behalf of a borrower.
     * @param _payer The address making the repayment.
     * @param _borrower The address for which the debt is being cleared.
     * @param _repayAmount The amount being repaid.
     * @return The actual repay amount after accounting for any conversions necessary.
     */
    function _repayBorrowInternal(
        address _payer,
        address _borrower,
        uint256 _repayAmount
    ) internal setTmpMsgValue returns (uint256) {
        _accrueInterest();

        bool isActive = IMarketPositionManager(marketPositionManager)
            .isMarketActive(address(this));

        if (!isActive) revert NotValidMarket();

        uint256 accountBorrowsPrior = _borrowBalanceStoredInternal(
            _borrower,
            borrowIndex
        );
        uint256 repayAmountFinal = (_repayAmount) > accountBorrowsPrior
            ? accountBorrowsPrior
            : (_repayAmount);

        uint256 excess = _repayAmount - repayAmountFinal;

        if (repayAmountFinal == 0) revert NoBorrowsToRepay();

        uint256 accountBorrowsNew = accountBorrowsPrior - repayAmountFinal;
        uint256 totalBorrowsNew = totalBorrows - repayAmountFinal;

        accountBorrows[_borrower].principal = accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        // @dev if repay amount for borrow position is greater that borrow send excess back to the payer
        if (excess > 0) {
            (bool sent, ) = payable(_payer).call{value: excess}("");
            if (!sent) revert FailedSendExcessBack();
        }

        emit RepayBorrow(
            _payer,
            _borrower,
            repayAmountFinal,
            accountBorrowsNew,
            totalBorrowsNew
        );
        return repayAmountFinal;
    }

    /**
     * @notice Redeems the underlying token either by the amount of underlying specified or by a specific amount of shares.
     * @param _redeemer The account performing the redemption.
     * @param _shareAmount The amount of shares to redeem if specified.
     * @dev This function will revert if there is not enough liquidity to perform the redemption or the inputs are invalid.
     */
    function _redeem(address payable _redeemer, uint256 _shareAmount) internal {
        if (_shareAmount == 0) revert InvalidRedeemShareAmount();
        if (accountBalance[_redeemer] < _shareAmount)
            revert InsufficientShares();

        uint256 accountPrincipalUpdated = _supplyBalanceStoredInternal(
            _redeemer,
            supplyIndex
        );
        accountSupplies[_redeemer].principal = accountPrincipalUpdated;
        accountSupplies[_redeemer].interestIndex = supplyIndex;

        uint256 redeemUnderlyingAmount = _calculateAmountInUnderlying(
            totalBorrows,
            totalReserves,
            _shareAmount
        );

        if (getUnderlyingBalance() < redeemUnderlyingAmount)
            revert InsufficientPool();

        IMarketPositionManager(marketPositionManager).validateRedeem(
            address(this),
            _redeemer,
            redeemUnderlyingAmount
        );

        _burnShares(_redeemer, _shareAmount);

        if (accountPrincipalUpdated < redeemUnderlyingAmount) {
            accountSupplies[_redeemer].principal = 0;
        } else {
            accountSupplies[_redeemer].principal -= redeemUnderlyingAmount;
        }

        uint16 fee = checkNftDiscount(_redeemer, feeRate.redeemingFeeRate);

        _doTransferOutWithFee(_redeemer, redeemUnderlyingAmount, fee);
        emit WithdrawFunds(_redeemer, redeemUnderlyingAmount, _shareAmount);
    }

    /**
     * @notice Executes the transfer of the underlying token to the specified address, deducting an optional fee which is sent to the contract.
     * @param _to The recipient of the funds.
     * @param _amount The total amount to be transferred.
     * @param _feeRate The fee rate to be applied.
     * @dev This function uses a low-level call to transfer funds and will revert if the transfer fails.
     */
    function _doTransferOutWithFee(
        address payable _to,
        uint256 _amount,
        uint16 _feeRate
    ) internal {
        uint256 feeAmount = (_amount * _feeRate) / FEERATE_FIXED_POINT;
        accruedProtocolFees += feeAmount;
        uint256 transferAmount = _amount - feeAmount;

        (bool sent, ) = _to.call{value: transferAmount}("");
        if (!sent) revert FailedWithdrawFunds();
    }

    /**
     * @notice Withdraws accrued protocol fees to the owner.
     * @dev Only callable by the contract owner.
     * @param _amount The total amount to be transferred.
     */
    function withdrawFees(uint256 _amount) public onlyOwner {
        if (_amount > accruedProtocolFees) revert InvalidFeeAmount();

        accruedProtocolFees -= _amount;

        (bool sent, ) = owner().call{value: _amount}("");
        if (!sent) revert FailedWithdrawFunds();
        emit WithdrawFees(address(owner()), _amount);
    }

    /**
     * @notice owner function to add reserves to the protocol
     */
    function addReserves() external payable onlyOwner {
        _accrueInterest();
        totalReserves += msg.value;
        emit ReservesAdded(msg.value, totalReserves);
    }

    /**
     * @notice owner function to remove reserves from the protocol
     * @param _amountToRemove Amount of reserves to remove
     */
    function removeReserves(uint256 _amountToRemove) external onlyOwner {
        _accrueInterest();
        totalReserves -= _amountToRemove;
        (bool sent, ) = payable(msg.sender).call{value: _amountToRemove}("");
        if (!sent) revert FailedWithdrawFunds();
        emit ReservesDeducted(_amountToRemove, totalReserves);
    }
}
