// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {HederaTokenService} from "./libraries/HederaTokenService.sol";
import {IMarketPositionManager} from "./interfaces/IMarketPositionManager.sol";
import {IBaseProtocol} from "./interfaces/IBaseProtocol.sol";
import {BaseProtocol} from "./BaseProtocol.sol";
import {FeeRate, BorrowSnapshot, SupplySnapshot} from "./libraries/Types.sol";

/**
 * @title SF Protocol Token Contract
 * @notice Implements a decentralized finance protocol featuring lending, borrowing, and liquidity providing functionalities. Integrates NFT-based discount mechanics and supports multiple tokens, including a wrapper for HBAR.
 * @dev This contract uses components from OpenZeppelin for standard functionality like ERC20 token behavior, ownership, pausing, and security features against reentrancy. It includes advanced DeFi functionalities like interest accrual, market management, and interactions with Uniswap for token swaps.
 */
contract SFProtocolToken is BaseProtocol, ERC20 {
    using SafeERC20 for IERC20;

    /**
     * @notice Address of the wrapped HBAR token used in this protocol.
     */
    address public immutable HBARaddress;

    /**
     * @notice Constructs the SFProtocolToken contract with initial setup.
     * @dev Sets initial values for the various state variables including fee rates, initial exchange rate, and addresses for required roles and tokens.
     * @param _feeRate Initial fee rate for transactions within the protocol.
     * @param _underlyingToken The ERC20 token address that this SFProtocol will handle.
     * @param _interestRateModel Address of the contract determining interest rates for borrowing.
     * @param _marketPositionManager Address of the contract managing market positions and related validations.
     * @param _nebulaGenesis The address of the NFT collection used for discount calculations.
     * @param _nebulaRegen The address of the NFT collection used for discount calculations.
     * @param _cosmicCyphters The address of the NFT collection used for discount calculations.
     * @param _initialExchangeRateMantissa The initial exchange rate from tokens to shares.
     * @param _basetoken Address of the base token, such as wrapped HBAR.
     * @param _name The name of the SFProtocol token.
     * @param _symbol The symbol of the SFProtocol token.
     * @param _maxProtocolBorrowCap Maximum amount that can be borrowed of a given asset from the protocol.
     * @param _maxProtocolSupplyCap Maximum amount that can be supplied of a given asset to the protocol.
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
        address _basetoken,
        string memory _name,
        string memory _symbol,
        uint8 _underlyingDecimals,
        uint256 _maxProtocolBorrowCap,
        uint256 _maxProtocolSupplyCap,
        uint256 _reserveFactorMantissa
    )
        ERC20(_name, _symbol)
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
            _maxProtocolBorrowCap,
            _maxProtocolSupplyCap,
            _reserveFactorMantissa
        )
    {
        HBARaddress = _basetoken;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function getUnderlyingBalance() public view override returns (uint256) {
        return
            (IERC20(underlyingToken).balanceOf(address(this))) -
            accruedProtocolFees;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function supplyUnderlying(
        uint256 _underlyingAmount
    ) external override whenNotPaused {
        _accrueInterest();
        if (_underlyingAmount == 0) revert InvaildSupplyAmount();

        if (
            (_underlyingAmount + getUnderlyingBalance()) >= maxProtocolSupplyCap
        ) revert MaxProtocolSupplyCap();

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

        uint256 shareAmount = _calculateAmountInShares(
            totalBorrows,
            totalReserves,
            _underlyingAmount
        );

        _doTransferIn(msg.sender, _underlyingAmount);

        accountSupplies[msg.sender].principal += _underlyingAmount;
        accountSupplies[msg.sender].interestIndex = supplyIndex;

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
        _redeem(msg.sender, _shareAmount);
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
        _redeem((msg.sender), shareAmount);
    }

    /**
     * @notice Redeems the underlying token either by the amount of underlying specified or by a specific amount of shares.
     * @param _redeemer The account performing the redemption.
     * @param _shareAmount The amount of shares to redeem if specified.
     * @dev This function will revert if there is not enough liquidity to perform the redemption or the inputs are invalid.
     */
    function _redeem(address _redeemer, uint256 _shareAmount) internal {
        if (_shareAmount <= 0) revert InvalidRedeemShareAmount();
        if (accountBalance[_redeemer] < _shareAmount)
            revert InsufficientShares();

        uint256 accountPrincipalUpdated = _supplyBalanceStoredInternal(
            _redeemer,
            supplyIndex
        );
        accountSupplies[_redeemer].principal = accountPrincipalUpdated;
        accountSupplies[_redeemer].interestIndex = supplyIndex;

        // redeem with shares
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
     * @inheritdoc IBaseProtocol
     */
    function borrow(
        uint256 _underlyingAmount
    ) external override nonReentrant whenNotPaused {
        _accrueInterest();
        if ((_underlyingAmount + totalBorrows) > maxProtocolBorrowCap)
            revert MaxProtocolBorrowCap();

        address borrower = msg.sender;
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
    function repayBorrow(
        uint256 _repayAmount
    ) external override nonReentrant whenNotPaused {
        _repayBorrowInternal(msg.sender, msg.sender, _repayAmount);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowBehalf(
        address _borrower,
        uint256 _repayAmount
    ) external override nonReentrant whenNotPaused {
        _repayBorrowInternal(msg.sender, _borrower, _repayAmount);
    }

    /**
     * @notice Internal function that handles the repayment of borrowed funds on behalf of a borrower.
     * @param _payer The address making the repayment.
     * @param _borrower The address for which the debt is being cleared.
     * @param _repayAmount The amount being repaid  or -1 for the full outstanding amount.
     * @return The actual repay amount after accounting for any conversions necessary.
     */
    function _repayBorrowInternal(
        address _payer,
        address _borrower,
        uint256 _repayAmount
    ) internal returns (uint256) {
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

        if (repayAmountFinal == 0) revert NoBorrowsToRepay();

        uint256 accountBorrowsNew = accountBorrowsPrior - repayAmountFinal;
        uint256 totalBorrowsNew = totalBorrows - repayAmountFinal;

        accountBorrows[_borrower].principal = accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        _doTransferIn(_payer, repayAmountFinal);

        emit RepayBorrow(
            _payer,
            _borrower,
            repayAmountFinal,
            accountBorrows[_borrower].principal,
            totalBorrows
        );

        return repayAmountFinal;
    }

    /**
     * @notice Handles the transfer of tokens into the contract and calculates the actual amount transferred.
     * @dev This function is used internally to safely transfer tokens from a user's address to this contract.
     * It measures the token balance before and after the transfer to account for any discrepancies due to transfer fees or errors.
     * @param _from The address from which tokens are transferred.
     * @param _amount The amount of tokens intended to be transferred.
     */
    function _doTransferIn(address _from, uint256 _amount) internal {
        IERC20 token = IERC20(underlyingToken);

        token.safeTransferFrom(_from, address(this), _amount);
    }

    /**
     * @notice Executes the transfer of the underlying token to the specified address, deducting an optional fee which is sent to the contract.
     * @param _to The recipient of the funds.
     * @param _amount The total amount to be transferred.
     * @param _feeRate The fee rate to be applied.
     * @dev This function uses a low-level call to transfer funds and will revert if the transfer fails.
     */
    function _doTransferOutWithFee(
        address _to,
        uint256 _amount,
        uint16 _feeRate
    ) internal {
        uint256 feeAmount = (_amount * _feeRate) / FEERATE_FIXED_POINT;
        accruedProtocolFees += feeAmount;
        uint256 transferAmount = _amount - feeAmount;
        IERC20(underlyingToken).safeTransfer(_to, transferAmount);
    }

    /**
     * @notice Withdraws accrued protocol fees to the owner.
     * @dev Only callable by the contract owner.
     * @param _amount The total amount to be transferred.
     */
    function withdrawFees(uint256 _amount) public onlyOwner {
        if (_amount > accruedProtocolFees) revert InvalidFeeAmount();

        accruedProtocolFees -= _amount;
        IERC20(underlyingToken).safeTransfer(owner(), accruedProtocolFees);
        emit WithdrawFees(address(owner()), _amount);
    }

    /**
     * @notice owner function to add reserves to the protocol
     * @param _amount amount of underlying tokens that should be added
     */
    function addReserves(uint256 _amount) external onlyOwner {
        _accrueInterest();
        totalReserves += _amount;
        IERC20(underlyingToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        emit ReservesAdded(_amount, totalReserves);
    }

    /**
     * @notice owner function to remove reserves to the protocol
     * @param _amount amount of underlying tokens that should be added
     */
    function removeReserves(uint256 _amount) external onlyOwner {
        _accrueInterest();
        totalReserves -= _amount;
        IERC20(underlyingToken).safeTransfer(msg.sender, _amount);
        emit ReservesDeducted(_amount, totalReserves);
    }

    /**
     * @notice force reserve to match balances in case of accidental sending of tokens to contract
     */
    function syncReserves() external onlyOwner {
        _accrueInterest();

        uint256 contractBalance = IERC20(underlyingToken).balanceOf(
            address(this)
        );

        uint256 underlyingBalanceActual = contractBalance -
            accruedProtocolFees +
            totalBorrows;

        if (underlyingBalanceActual > totalReserves) {
            uint256 surplusAmount = underlyingBalanceActual - totalReserves;

            totalReserves += surplusAmount;
        }
    }
}
