// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {HederaTokenService, HederaResponseCodes} from "./libraries/HederaTokenService.sol";
import {IBaseProtocol} from "./interfaces/IBaseProtocol.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {IMarketPositionManager} from "./interfaces/IMarketPositionManager.sol";
import {FeeRate, BorrowSnapshot, SupplySnapshot} from "./libraries/Types.sol";

/**
 * @title Base Protocol Contract
 * @notice This contract manages the core functionalities of the lending protocol including
 * borrowing, supplying, interest accrual, and collateral management on the Hedera network.
 * @dev The contract inherits from Ownable2Step for ownership controls,
 * Pausable for pausing contract functions, ReentrancyGuard for preventing re-entrant calls, and
 * it implements the IBaseProtocol and interfaces with HederaTokenService for token operations.
 */
contract BaseProtocol is
    Ownable2Step,
    Pausable,
    ReentrancyGuard,
    IBaseProtocol,
    HederaTokenService
{
    /**
     * @notice Decimal precision of the underlying token.
     */
    uint16 public constant FEERATE_FIXED_POINT = 10000;

    /**
     * @notice Nebula Genesis NFT collection used for fee discounts.
     */
    IERC721 public immutable nebulaGenesis;

    /**
     * @notice Nebula Regen NFT collection used for fee discounts.
     */
    IERC721 public immutable nebulaRegen;

    /**
     * @notice Cosmic Cypthers NFT collection used for fee discounts.
     */
    IERC721 public immutable cosmicCyphters;

    /**
     * @notice Mapping of user addresses to their share of the protocol's assets.
     */
    mapping(address => uint256) public accountBalance;

    /**
     * @notice Mapping of user addresses to their current borrow state.
     */
    mapping(address => BorrowSnapshot) public accountBorrows;

    /**
     * @notice Mapping of user addresses to their current supply state.
     */
    mapping(address => SupplySnapshot) public accountSupplies;

    /**
     * @notice Current fee rate information for protocol transactions.
     */
    FeeRate public feeRate;

    /**
     * @notice Address of the token this protocol lends and borrows.
     */
    address public immutable override underlyingToken;

    /**
     * @notice Contract address for calculating interest rates on borrows.
     */
    address public immutable interestRateModel;

    /**
     * @notice Contract address for managing market positions.
     */
    address public immutable marketPositionManager;

    /**
     * @notice Initial exchange rate applied when the protocol is first initialized.
     */
    uint256 private initialExchangeRateMantissa;

    /**
     * @notice Last block number at which interest was accrued.
     */
    uint256 public accrualTransactionTimestamp;

    /**
     * @notice Total outstanding borrowed amount of the underlying token in this market.
     */
    uint256 public override totalBorrows;

    /**
     * @notice Total reserves of the underlying token held in this market.
     */
    uint256 public totalReserves;

    /**
     * @notice Portion of interest set aside as reserves each block.
     */
    uint256 public reserveFactorMantissa;

    /**
     * @notice Total amount of protocol shares issued.
     */
    uint256 public totalShares;

    /**
     * @notice Accumulated total of earned interest rates since market opened.
     */
    uint256 public borrowIndex;

    /**
     * @notice Accumulated total of earned interest rates since market opened.
     */
    uint256 public supplyIndex;

    /**
     * @notice Number of token decimals.
     */
    uint8 public immutable underlyingDecimals;

    /**
     * @notice Sum of all protocol fees which this contract holds.
     */
    uint256 public accruedProtocolFees;

    /**
     * @notice Max amount of tokens which can be borrowed.
     */
    uint256 public maxProtocolBorrowCap;

    /**
     * @notice Max amount of tokens which can be supplied to the protocol.
     */
    uint256 public maxProtocolSupplyCap;

    /**
     * @notice Constructs the BaseProtocol contract.
     * @param _feeRate Initial fee rate settings for the contract.
     * @param _underlyingToken The token that will be used as the underlying asset.
     * @param _interestRateModel The contract address for the interest rate model.
     * @param _marketPositionManager The contract managing market positions.
     * @param _nebulaGenesis The address of the NFT collection used for discount calculations.
     * @param _nebulaRegen The address of the NFT collection used for discount calculations.
     * @param _cosmicCyphters The address of the NFT collection used for discount calculations.
     * @param _initialExchangeRateMantissa The initial exchange rate, expressed as mantissa.
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
        uint8 _underlyingDecimals,
        uint256 _maxProtocolBorrowCap,
        uint256 _maxProtocolSupplyCap,
        uint256 _reserveFactorMantissa
    ) Ownable(msg.sender) {
        if (
            _underlyingToken == address(0) ||
            _marketPositionManager == address(0)
        ) revert InvalidAddress();
        if (_initialExchangeRateMantissa == 0)
            revert InvalidExchangeRateMantissa();

        nebulaGenesis = IERC721(_nebulaGenesis);
        nebulaRegen = IERC721(_nebulaRegen);
        cosmicCyphters = IERC721(_cosmicCyphters);
        feeRate = _feeRate;
        underlyingToken = _underlyingToken;
        interestRateModel = _interestRateModel;
        initialExchangeRateMantissa = _initialExchangeRateMantissa;
        accrualTransactionTimestamp = block.timestamp;
        underlyingDecimals = _underlyingDecimals;
        marketPositionManager = _marketPositionManager;
        borrowIndex = 10 ** 18;
        supplyIndex = 10 ** 18;
        maxProtocolBorrowCap = _maxProtocolBorrowCap;
        maxProtocolSupplyCap = _maxProtocolSupplyCap;
        reserveFactorMantissa = _reserveFactorMantissa;
    }

    /**
     * @notice Modifier that restricts access to only the manager of the market.
     * @dev Ensures that the function can only be called by the address that matches the `marketPositionManager`.
     * This address is set during contract initialization and can manage key operational aspects.
     */
    modifier onlyManager() {
        if (msg.sender != marketPositionManager) revert NotManager();
        _;
    }

    /**
     * @notice Set a new fee rate for protocol operations.
     * @dev Only callable by the contract owner. Emits a fee rate change event.
     * @param _feeRate The new fee structure to be set.
     */
    function setFeeRate(FeeRate memory _feeRate) external onlyOwner {
        feeRate = _feeRate;
    }

    /**
     * @notice Associates a new token with this contract using the Hedera Token Service.
     * @dev Requires the operation to succeed, otherwise reverts the transaction.
     * @param tokenId The token ID to associate with this contract.
     */
    function tokenAssociate(
        address tokenId
    ) external onlyOwner returns (int256) {
        int256 response = HederaTokenService.associateToken(
            address(this),
            tokenId
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert FailedAssociate();
        }

        return response;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function getUnderlyingBalance() public view virtual returns (uint256) {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function getAccountSnapshot(
        address _account
    ) public view override returns (uint256, uint256, uint256, uint256) {
        (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            uint256 borrowIndexNew,

        ) = getUpdatedRates();

        return (
            accountBalance[_account],
            _borrowBalanceStoredInternal(_account, borrowIndexNew),
            _calculateAmountInUnderlying(
                totalBorrowsNew,
                totalReservesNew,
                accountBalance[_account]
            ),
            getClaimableInterests(_account)
        );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function checkNftDiscount(
        address _user,
        uint16 _baseFee
    ) public view returns (uint16) {
        uint256 nebulaGen = nebulaGenesis.balanceOf(_user);
        uint256 nebulaReg = nebulaRegen.balanceOf(_user);
        uint256 cosmicCyph = cosmicCyphters.balanceOf(_user);

        if (nebulaGen > 0 || nebulaReg > 0 || cosmicCyph > 0) {
            return 0;
        }

        return _baseFee;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function supplyRatePerBlock() external view override returns (uint256) {
        (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            ,

        ) = getUpdatedRates();
        return
            IInterestRateModel(interestRateModel).getSupplyRate(
                getUnderlyingBalance(),
                totalBorrowsNew,
                totalReservesNew,
                reserveFactorMantissa
            );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function borrowRatePerBlock() external view override returns (uint256) {
        (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            ,

        ) = getUpdatedRates();
        return
            IInterestRateModel(interestRateModel).getBorrowRate(
                getUnderlyingBalance(),
                totalBorrowsNew,
                totalReservesNew
            );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function getSuppliedAmount(
        address _account
    ) public view override returns (uint256) {
        uint256 shareAmount = accountBalance[_account];
        if (shareAmount == 0) return 0;

        return
            _calculateAmountInUnderlying(
                totalBorrows,
                totalReserves,
                shareAmount
            );
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function supplyUnderlying(uint256 _underlyingAmount) external virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function supplyUnderlyingNative() external payable virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function getExchangeRateStored() public view override returns (uint256) {
        (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            ,

        ) = getUpdatedRates();
        return _exchangeRateStoredInternal(totalBorrowsNew, totalReservesNew);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowNative() external payable virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrow(uint256 _repayAmount) external virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowBehalfNative(
        address _borrower
    ) external payable virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function repayBorrowBehalf(
        address _borrower,
        uint256 _repayAmount
    ) external virtual {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function borrow(uint256 _underlyingAmount) external virtual whenNotPaused {}

    /**
     * @dev Returns the borrow balance of an account based on stored data.
     * @param _account The address of the account whose balance should be calculated.
     * @param _borrowIndex The index used for calculating interest accrued since last interaction.
     * @return The updated borrow balance taking into account accrued interest.
     */
    function _borrowBalanceStoredInternal(
        address _account,
        uint256 _borrowIndex
    ) internal view returns (uint256) {
        BorrowSnapshot memory borrowSnapshot = accountBorrows[_account];

        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        uint256 principalTimesIndex = borrowSnapshot.principal * _borrowIndex;
        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    /**
     * @dev Returns the supply balance of an account based on stored data.
     * @param _account The address of the account whose balance should be calculated.
     * @param _supplyIndex The index used for calculating interest accrued since last interaction.
     * @return The updated borrow balance taking into account accrued interest.
     */
    function _supplyBalanceStoredInternal(
        address _account,
        uint256 _supplyIndex
    ) internal view returns (uint256) {
        SupplySnapshot memory supplySnapshot = accountSupplies[_account];

        if (supplySnapshot.principal == 0) {
            return 0;
        }

        uint256 principalTimesIndex = supplySnapshot.principal * _supplyIndex;
        return principalTimesIndex / supplySnapshot.interestIndex;
    }

    /**
     * @notice Retrieves the amount of claimable interests for a given user.
     * @dev This function calculates the difference between the current supplied amount and the principal,
     * indicating the accrued interests that are not yet claimed.
     * @param _claimer The address of the user for whom to calculate claimable interests.
     * @return claimableInterests The total claimable interests available for the user. This value is the
     * difference between the current supplied amount and the initial principal supplied.
     */
    function getClaimableInterests(
        address _claimer
    ) public view whenNotPaused returns (uint256) {
        SupplySnapshot memory supplySnapshot = accountSupplies[_claimer];
        uint256 suppliedAmount = supplySnapshot.principal;
        (, , , uint256 supplyIndexNew) = getUpdatedRates();

        uint256 currentAmount = _supplyBalanceStoredInternal(
            _claimer,
            supplyIndexNew
        );

        uint256 claimableInterests = currentAmount - suppliedAmount;

        return claimableInterests;
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function redeem(uint256 _shareAmount) external virtual whenNotPaused {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function redeemExactUnderlying(
        uint256 _underlyingAmount
    ) external virtual whenNotPaused {}

    /**
     * @inheritdoc IBaseProtocol
     */
    function liquidateBorrow(
        address _liquidator,
        address _borrower,
        uint256 _liquidateUnderlying
    ) external override whenNotPaused onlyManager {
        _accrueInterest();

        uint256 liquidatorBalance = getSuppliedAmount(_liquidator);

        uint256 accountBorrowsPrior = _borrowBalanceStoredInternal(
            _borrower,
            borrowIndex
        );
        uint256 liquidatorSupplyPrior = _supplyBalanceStoredInternal(
            _liquidator,
            supplyIndex
        );

        if (liquidatorBalance < _liquidateUnderlying) revert NotEnoughTokens();

        uint256 accountBorrowsNew = accountBorrowsPrior - _liquidateUnderlying;
        uint256 totalBorrowsNew = totalBorrows - _liquidateUnderlying;

        uint256 liquidateShareAmount = _calculateAmountInShares(
            totalBorrows,
            totalReserves,
            _liquidateUnderlying
        );

        accountBorrows[_borrower].principal = accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        _burnShares(_liquidator, liquidateShareAmount);
        accountSupplies[_liquidator].principal =
            liquidatorSupplyPrior -
            _liquidateUnderlying;
        accountSupplies[_liquidator].interestIndex = supplyIndex;

        emit LiquidateBorrow(
            _liquidator,
            _borrower,
            _liquidateUnderlying,
            address(this),
            underlyingToken
        );
    }

    function seizeCollateral(
        address _liquidator,
        address _borrower,
        uint256 _seizeUnderlying,
        uint256 _percentForProtocol
    ) external override whenNotPaused onlyManager {
        _accrueInterest();

        uint256 shareAmount = _calculateAmountInShares(
            totalBorrows,
            totalReserves,
            _seizeUnderlying
        );

        if (accountBalance[_borrower] < shareAmount) revert InvalidBalance();

        uint256 borrowerSupplyPrior = _supplyBalanceStoredInternal(
            _borrower,
            supplyIndex
        );

        uint256 liquidatorSupplyPrior;
        if (accountSupplies[_liquidator].principal > 0) {
            liquidatorSupplyPrior = _supplyBalanceStoredInternal(
                _liquidator,
                supplyIndex
            );
        }

        /**
         *  @dev Here we calculate the ratio of shares that should go to protocol
         *  and as 100 % is 1e18 and _percentForProtocol presented is these decimals we divide by 1e18.
         */
        uint256 shareAmountForProtocol = (shareAmount * _percentForProtocol) /
            (1e18);

        uint256 shareAmountForLiquidator = shareAmount - shareAmountForProtocol;

        uint256 amountForProtocol = (_seizeUnderlying * _percentForProtocol) /
            (1e18);

        uint256 amountForLiquidator = _seizeUnderlying - amountForProtocol;

        totalReserves += amountForProtocol;
        totalShares -= shareAmountForProtocol;

        accountBalance[_borrower] -= shareAmount;
        accountBalance[_liquidator] += shareAmountForLiquidator;

        accountSupplies[_borrower].principal =
            borrowerSupplyPrior -
            _seizeUnderlying;

        accountSupplies[_liquidator].principal =
            liquidatorSupplyPrior +
            amountForLiquidator;

        accountSupplies[_borrower].interestIndex = supplyIndex;
        accountSupplies[_liquidator].interestIndex = supplyIndex;

        emit SeizeCollateral(
            _borrower,
            _liquidator,
            _seizeUnderlying,
            amountForLiquidator,
            amountForProtocol
        );
        emit ReservesAdded(amountForProtocol, totalReserves);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function seizeBadCollateral(
        address _borrower,
        uint256 _seizeUnderlying
    ) external override whenNotPaused onlyManager {
        uint256 shareAmount = _calculateAmountInShares(
            totalBorrows,
            totalReserves,
            _seizeUnderlying
        );

        if (accountBalance[_borrower] < shareAmount) revert InvalidBalance();

        _burnShares(_borrower, shareAmount);

        accountSupplies[_borrower].principal -= _seizeUnderlying;
        totalReserves += _seizeUnderlying;

        emit SeizeBadDebtCollateral(_borrower, address(this), _seizeUnderlying);
        emit ReservesDeducted(_seizeUnderlying, totalReserves);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function liquidateBadDebt(
        address _borrower,
        uint256 _liquidateUnderlying
    ) external override whenNotPaused onlyManager {
        if (totalReserves < _liquidateUnderlying) revert NotEnoughTokens();
        _accrueInterest();

        uint256 accountBorrowsPrior = _borrowBalanceStoredInternal(
            _borrower,
            borrowIndex
        );

        uint256 accountBorrowsNew = accountBorrowsPrior - _liquidateUnderlying;
        uint256 totalBorrowsNew = totalBorrows - _liquidateUnderlying;

        // storage update for borrower
        accountBorrows[_borrower].principal = accountBorrowsNew;
        accountBorrows[_borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        // storage update for Contract
        totalReserves -= _liquidateUnderlying;

        emit LiquidateBorrow(
            address(this),
            _borrower,
            _liquidateUnderlying,
            address(this),
            underlyingToken
        );
    }

    /**
     * @notice Accrues interest to total borrows and reserves up to the current block, updating state variables.
     * @dev This function should be invoked before any operations that alter total borrows or reserves to ensure all calculations are made with the most recent data.
     */
    function _accrueInterest() internal {
        uint256 currentTimestamp = block.timestamp;
        if (accrualTransactionTimestamp == currentTimestamp) return;

        (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            uint256 borrowIndexNew,
            uint256 supplyIndexNew
        ) = getUpdatedRates();

        accrualTransactionTimestamp = currentTimestamp;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;
        borrowIndex = borrowIndexNew;
        supplyIndex = supplyIndexNew;

        emit InterestAccrued();
    }

    /**
     * @dev Updates the interest rates based on the current block number and the state of the reserves and borrows.
     *  This function is called to update the rates at which interest accrues for borrowers and how it is accumulated in reserves.
     * @return totalBorrowsNew The new total amount of borrowed funds after interest accrual.
     * @return totalReservesNew The new total amount of reserves after interest accrual.
     * @return borrowIndexNew The new borrow index updated to the current block.
     * @return supplyIndexNew The new supply index updated to the current block.
     */
    function getUpdatedRates()
        public
        view
        returns (
            uint256 totalBorrowsNew,
            uint256 totalReservesNew,
            uint256 borrowIndexNew,
            uint256 supplyIndexNew
        )
    {
        uint256 currentTimeStamp = block.timestamp;

        if (currentTimeStamp == accrualTransactionTimestamp) {
            return (totalBorrows, totalReserves, borrowIndex, supplyIndex);
        }

        uint256 cashPrior = getUnderlyingBalance();
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserves;
        uint256 borrowIndexPrior = borrowIndex;
        uint256 supplyIndexPrior = supplyIndex;
        uint256 borrowRate = IInterestRateModel(interestRateModel)
            .getBorrowRate((cashPrior), borrowsPrior, reservesPrior);

        uint256 supplyRate = IInterestRateModel(interestRateModel)
            .getSupplyRate(
                (cashPrior),
                borrowsPrior,
                reservesPrior,
                reserveFactorMantissa
            );

        uint256 timeDelta = currentTimeStamp - accrualTransactionTimestamp;
        uint256 simpleInterestFactorBorrow = borrowRate * timeDelta;
        uint256 simpleInterestFactorSupply = supplyRate * timeDelta;

        uint256 accumulatedInterests = (simpleInterestFactorBorrow *
            totalBorrows) / 1e18;

        totalReservesNew =
            (accumulatedInterests * reserveFactorMantissa) /
            1e18 +
            reservesPrior;

        borrowIndexNew =
            (simpleInterestFactorBorrow * borrowIndexPrior) /
            1e18 +
            borrowIndexPrior;

        supplyIndexNew =
            (simpleInterestFactorSupply * supplyIndexPrior) /
            1e18 +
            supplyIndexPrior;

        totalBorrowsNew = (totalBorrows * borrowIndexNew) / borrowIndexPrior;
    }

    /**
     * @notice Calculates the current exchange rate from shares to the underlying asset, based on the current state of the total borrows and reserves.
     * @param _totalBorrows The total amount of borrowed assets currently recorded in the system.
     * @param _totalReserves The total amount of funds held in reserve.
     * @return The calculated exchange rate, scaled by underlyingDecimals.
     */
    function _exchangeRateStoredInternal(
        uint256 _totalBorrows,
        uint256 _totalReserves
    ) internal view virtual returns (uint256) {
        if (totalShares == 0) {
            return initialExchangeRateMantissa;
        } else {
            uint256 totalCash = getUnderlyingBalance();
            uint256 cashPlusBorrowsMinusReserves = totalCash +
                _totalBorrows -
                _totalReserves;

            uint256 exchangeRate = (cashPlusBorrowsMinusReserves *
                (10 ** underlyingDecimals)) / totalShares;

            return exchangeRate;
        }
    }

    /**
     * @notice Calculates the amount of shares based on current exchange rate,
     * based on the current state of the total borrows and reserves.
     * @param _totalBorrows The total amount of borrowed assets currently recorded in the system.
     * @param _totalReserves The total amount of funds held in reserve.
     * @return The calculated amount of shares, scaled by underlyingDecimals.
     */
    function _calculateAmountInShares(
        uint256 _totalBorrows,
        uint256 _totalReserves,
        uint256 _amount
    ) internal view virtual returns (uint256) {
        if (totalShares == 0) {
            return
                (_amount * (10 ** underlyingDecimals)) /
                initialExchangeRateMantissa;
        } else {
            uint256 totalCash = getUnderlyingBalance();
            uint256 cashPlusBorrowsMinusReserves = totalCash +
                _totalBorrows -
                _totalReserves;
            uint256 shareAmount = (_amount * totalShares) /
                (cashPlusBorrowsMinusReserves);

            return shareAmount;
        }
    }

    /**
     * @notice Calculates the amount of shares based on current exchange rate,
     * based on the current state of the total borrows and reserves.
     * @param _totalBorrows The total amount of borrowed assets currently recorded in the system.
     * @param _totalReserves The total amount of funds held in reserve.
     * @return The calculated amount of shares, scaled by underlyingDecimals.
     */
    function _calculateAmountInUnderlying(
        uint256 _totalBorrows,
        uint256 _totalReserves,
        uint256 _shareAmount
    ) internal view virtual returns (uint256) {
        if (totalShares == 0) {
            return
                (_shareAmount * initialExchangeRateMantissa) /
                (10 ** underlyingDecimals);
        } else {
            uint256 totalCash = getUnderlyingBalance();
            uint256 cashPlusBorrowsMinusReserves = totalCash +
                _totalBorrows -
                _totalReserves;

            uint256 underlyingAmount = (_shareAmount *
                cashPlusBorrowsMinusReserves) / (totalShares);

            return underlyingAmount;
        }
    }

    /**
     * @notice Mints new shares to the specified account.
     * @param _account The account to mint shares to.
     * @param _amount The amount of shares to mint.
     */
    function _mintShares(address _account, uint256 _amount) internal {
        accountBalance[_account] += _amount;
        totalShares += _amount;
        emit MintShares(_account, _amount);
    }

    /**
     * @notice Burns shares from the specified account.
     * @param _account The account from which shares are burned.
     * @param _amount The amount of shares to burn.
     */
    function _burnShares(address _account, uint256 _amount) internal {
        accountBalance[_account] -= _amount;
        totalShares -= _amount;
        emit BurnShares(_account, _amount);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function updateMaxBorrows(uint256 _newMaxBorrows) external onlyOwner {
        maxProtocolBorrowCap = _newMaxBorrows;
        emit NewMaxBorrows(_newMaxBorrows);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function updateMaxSupply(uint256 _newMaxSupply) external onlyOwner {
        maxProtocolSupplyCap = _newMaxSupply;
        emit NewMaxSupply(_newMaxSupply);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function convertFeesToReserves(uint256 _amount) external onlyOwner {
        if (_amount > accruedProtocolFees) revert InvalidFeeAmount();

        accruedProtocolFees -= _amount;
        totalReserves += _amount;
        emit SwapFeesToReserves(_amount);
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @inheritdoc IBaseProtocol
     */
    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }
}
