// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMarketPositionManager} from "./interfaces/IMarketPositionManager.sol";
import {IBaseProtocol} from "./interfaces/IBaseProtocol.sol";
import {ISupraOracle, ISupraSValueFeed} from "./interfaces/ISupraOracle.sol";
import {SupraPair} from "./libraries/Types.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title MarketPositionManager
 * @notice Manages market positions, including borrowing, supplying, and liquidation processes.
 * @dev This contract handles the validation and management of borrow and supply operations for various tokens.
 *  It interacts with external protocols and oracles to fetch prices and ensures the protocol's integrity
 *  through risk assessments and liquidation mechanisms.
 */
contract MarketPositionManager is
    OwnableUpgradeable,
    IMarketPositionManager,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Reflect if borrow is allowed for a particular token.
     * @dev Mapping from token address to boolean indicating if borrow is paused.
     */
    mapping(address => bool) public borrowGuardianPaused;

    /**
     * @notice Reflect if supply is allowed for a particular token.
     * @dev Mapping from token address to boolean indicating if supply is paused.
     */
    mapping(address => bool) public supplyGuardianPaused;

    /**
     * @notice Reflect market information for each token.
     * @dev Mapping from token address to MarketInfo struct.
     */
    mapping(address => MarketInfo) public markets;

    /**
     * @notice Limit amounts that can be borrowed for each token.
     * @dev Mapping from token address to the borrow cap.
     */
    mapping(address => uint256) public loanToValue;

    /**
     * @notice Set of assets that a user has borrowed.
     * @dev Mapping from user address to a set of token addresses.
     */
    mapping(address => EnumerableSet.AddressSet) private accountAssets;

    /**
     * @notice List of borrower addresses.
     */
    EnumerableSet.AddressSet private borrowerList;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives.
     */
    uint256 public liquidationPercentageProtocol;

    /**
     * @notice Liquidation Risk threshold for triggering liquidation.
     */
    uint256 public liquidateRiskThreshold;

    /**
     * @notice The price oracle contract.
     */
    ISupraOracle public supraOracle;

    /**
     * @notice Mapping from token address to supra oracle ids.
     */
    mapping(address => SupraPair) public supraPair;

    /**
     * @notice Scaling factor for mathematical operations.
     */
    uint256 constant MATH_SCALING_FACTOR = 1e18;

    /**
     * @notice Constructor used for initial setup, specifically to disable initializers.
     * @dev This constructor disables initializers to ensure that the contract cannot be
     * @custom:oz-upgrades-unsafe-allow constructor
     */ constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the specified parameters.
     * @param _supraOracle The address of the price oracle.
     * @param _liquidationRiskThreshold The liquidation risk threshold for liquidation.
     * @param _liquidationPercentageProtocol Percentage of liquidation that protocol receives.
     */
    function initialize(
        address _supraOracle,
        uint256 _liquidationRiskThreshold,
        uint256 _liquidationPercentageProtocol
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        setPriceOracle(_supraOracle);
        liquidateRiskThreshold = _liquidationRiskThreshold;
        liquidationPercentageProtocol = _liquidationPercentageProtocol;
        emit UpdateLiquidationRiskThreshold(_liquidationRiskThreshold);
        emit NewLiquidationIncentiveSet(_liquidationPercentageProtocol);
    }

    /**
     * @dev Modifier to check if the caller is valid and the token is listed.
     * @param _token The address of the token.
     */
    modifier onlyValidCaller(address _token) {
        if (msg.sender != _token) revert InvalidCaller();
        if (!markets[_token].isActive) revert NotListedToken();
        _;
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function setPriceOracle(address _supraOracle) public override onlyOwner {
        if (_supraOracle == address(0)) revert InvalidOracleAddress();
        supraOracle = ISupraOracle(_supraOracle);
    }

    /**
     * @dev Setting Supra Oracle price feed id and usd availability.
     * @param _token The address of the token.
     * @param _priceFeed Id of Supra Oracle price feed index.
     * @param _usdPairId Id of Supra Oracle price feed convertable usd index.
     * @param _isUsd If pair is usd convertable
     */
    function setSupraId(
        address _token,
        uint256 _priceFeed,
        uint256 _usdPairId,
        bool _isUsd
    ) external onlyOwner {
        supraPair[_token] = SupraPair(_priceFeed, _usdPairId, _isUsd);
        emit SetSupraPair(_token, _priceFeed, _usdPairId);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function pauseBorrowGuardian(
        address[] memory _tokens,
        bool _pause
    ) external override onlyOwner {
        uint256 length = _tokens.length;
        if (length == 0) revert InvalidArrayLength();
        for (uint256 i = 0; i < length; i++) {
            borrowGuardianPaused[_tokens[i]] = _pause;
        }
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function pauseSupplyGuardian(
        address[] memory _tokens,
        bool _pause
    ) external override onlyOwner {
        uint256 length = _tokens.length;
        if (length == 0) revert InvalidArrayLength();
        for (uint256 i = 0; i < length; i++) {
            supplyGuardianPaused[_tokens[i]] = _pause;
        }
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function setLoanToValue(
        address[] memory _tokens,
        uint256[] memory _loanToValue
    ) external override onlyOwner {
        uint256 length = _tokens.length;

        if (length == 0 || length != _loanToValue.length)
            revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            loanToValue[_tokens[i]] = _loanToValue[i];
        }
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function setLiquidationIncentive(
        uint256 _liquidiateIncentive
    ) external override onlyOwner {
        if (_liquidiateIncentive > MATH_SCALING_FACTOR)
            revert InvalidLiquidationIncentive();

        liquidationPercentageProtocol = _liquidiateIncentive;
        emit NewLiquidationIncentiveSet(_liquidiateIncentive);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function checkMembership(
        address _account,
        address _token
    ) external view override returns (bool) {
        return markets[_token].accountMembership[_account];
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function addToMarket(address _token) external override onlyOwner {
        MarketInfo storage info = markets[_token];
        if (info.isActive) revert AlreadyAddedToMarket();
        markets[_token].isActive = true;
        emit AddToMarket(_token);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function removeFromMarket(address _token) external override onlyOwner {
        if (!markets[_token].isActive) revert AlreadyRemovedFromMarket();
        delete markets[_token];
        emit RemoveFromMarket(_token);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function freezeTokenMarket(address _token) external override onlyOwner {
        if (!markets[_token].isActive) revert MarketAlreadyFroozen();
        markets[_token].isActive = false;
        emit FreezeTokenMarket(_token);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function isMarketActive(
        address _token
    ) external view override returns (bool) {
        return markets[_token].isActive;
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function getAccountAssets(
        address _account
    ) external view override returns (address[] memory) {
        return accountAssets[_account].values();
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function validateSupply(
        address _supplier,
        address _token
    ) external override onlyValidCaller(_token) {
        if (supplyGuardianPaused[_token]) revert SupplyPaused();

        if (!accountAssets[_supplier].contains(_token)) {
            accountAssets[_supplier].add(_token);
        }
    }

    /**
     * @notice Checks the liquidation risk status of a borrower.
     * @param _borrower The address of the borrower.
     * @return (uint256, uint256, uint256) The liquidationRisk, total debt, and total supplied.
     */
    function checkLiquidationRisk(
        address _borrower
    ) public view returns (uint256, uint256, uint256) {
        address[] memory assets = accountAssets[_borrower].values();
        if (assets.length == 0) {
            revert UserDoesNotHaveAssets();
        }

        (
            ,
            uint256 totalDebtUSD,
            uint256 totalSuppliedUSD,

        ) = _getCollateralAndDebt(_borrower, assets[0]);

        if (totalDebtUSD == 0 || totalSuppliedUSD == 0)
            return (0, totalDebtUSD, totalSuppliedUSD);

        uint256 liquidationRisk = (totalDebtUSD * MATH_SCALING_FACTOR) /
            totalSuppliedUSD;
        return (liquidationRisk, totalDebtUSD, totalSuppliedUSD);
    }

    /**
     * @notice Calculates the liquidation details for a borrower.
     * @param _borrower The address of the borrower.
     * @param _liquidateAmountUSD The amount to be liquidated.
     * @return liquidateAssets The amounts to be liquidated for each asset.
     * @return liquidateUnderlying The amounts borrowed for each asset.
     */
    function calcLiquidationDetail(
        address _borrower,
        uint256 _liquidateAmountUSD
    )
        public
        view
        returns (
            address[] memory liquidateAssets,
            uint256[] memory liquidateUnderlying
        )
    {
        address[] memory assets = accountAssets[_borrower].values();
        liquidateAssets = new address[](assets.length);
        liquidateUnderlying = new uint256[](assets.length);
        uint256 arrIndex = 0;
        uint256 liquidateAmountUSD = _liquidateAmountUSD;

        for (uint i = 0; i < assets.length; i++) {
            IBaseProtocol assetToLiquidate = IBaseProtocol(assets[i]);
            (
                uint256 shareBalanceToLiquidate,
                ,
                uint256 suppliedAmount,

            ) = assetToLiquidate.getAccountSnapshot(_borrower);

            if (shareBalanceToLiquidate > 0 && liquidateAmountUSD > 0) {
                uint256 underlyingDecimals = uint256(
                    assetToLiquidate.underlyingDecimals()
                );

                SupraPair memory supra = supraPair[
                    assetToLiquidate.underlyingToken()
                ];

                uint256 tokenPrice;

                tokenPrice = supraOracle.getPrice(supra);
                if (tokenPrice == 0) revert PriceError();

                uint256 suppliedAmountUSD = (suppliedAmount * tokenPrice) /
                    (10 ** underlyingDecimals);

                uint256 amountForLiquidationUSD;
                if (suppliedAmountUSD >= liquidateAmountUSD) {
                    amountForLiquidationUSD = liquidateAmountUSD;
                    liquidateAmountUSD = 0;
                } else {
                    liquidateAmountUSD -= suppliedAmountUSD;
                    amountForLiquidationUSD = suppliedAmountUSD;
                }

                uint256 underlyingForLiquidation = (amountForLiquidationUSD *
                    (10 ** underlyingDecimals)) / tokenPrice;

                liquidateAssets[arrIndex] = assets[i];
                liquidateUnderlying[arrIndex] = underlyingForLiquidation;
                arrIndex++;
            }
            if (liquidateAmountUSD == 0) break;
        }
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function liquidateBorrow(
        address _borrower,
        address _token
    ) external nonReentrant {
        address liquidator = msg.sender;
        (, uint256 borrowedBalance, , ) = IBaseProtocol(_token)
            .getAccountSnapshot(_borrower);
        (
            bool isLiquidatable,
            uint256 borrowerLiquidationRisk,
            uint256 fundAvailableForLiquidation
        ) = validateLiquidate(liquidator, _borrower, borrowedBalance);
        if (!isLiquidatable) {
            revert InvalidLiquidation();
        }

        if (borrowerLiquidationRisk > MATH_SCALING_FACTOR)
            revert BadDebtLiquidation();

        IBaseProtocol asset = IBaseProtocol(_token);
        SupraPair memory supra = supraPair[asset.underlyingToken()];

        uint256 tokenPrice;

        tokenPrice = supraOracle.getPrice(supra);

        if (tokenPrice == 0) revert PriceError();

        uint256 underlyingDecimals = uint256(asset.underlyingDecimals());

        uint256 liquidateAmountUSD = (borrowedBalance *
            MATH_SCALING_FACTOR *
            tokenPrice) / (borrowerLiquidationRisk * 10 ** underlyingDecimals);

        uint256 liquidateAmountWithoutPayoutLR = (borrowedBalance *
            tokenPrice) / (10 ** underlyingDecimals);

        if (fundAvailableForLiquidation < liquidateAmountWithoutPayoutLR) {
            revert LiquidatorDoesNotHaveEnoughFundsToLiquidate();
        }

        (
            address[] memory liquidateAssets,
            uint256[] memory liquidateUnderlying
        ) = calcLiquidationDetail(_borrower, liquidateAmountUSD);

        asset.liquidateBorrow(liquidator, _borrower, borrowedBalance);

        uint256 percentForProtocol = ((MATH_SCALING_FACTOR -
            borrowerLiquidationRisk) * liquidationPercentageProtocol) /
            MATH_SCALING_FACTOR;

        // we iterate over the borrower supplied positions to remove collaterals and get compensation for user and protocol
        for (uint256 i = 0; i < liquidateAssets.length; i++) {
            if (
                liquidateAssets[i] != address(0) && liquidateUnderlying[i] > 0
            ) {
                IBaseProtocol(liquidateAssets[i]).seizeCollateral(
                    liquidator,
                    _borrower,
                    liquidateUnderlying[i],
                    percentForProtocol
                );
            }
        }
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function liquidateBadDebts(address[] memory _borrowers) external onlyOwner {
        uint256 length = _borrowers.length;
        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            _liquidateBadDebt(_borrowers[i]);
        }
    }

    /**
     * @notice Internally liquidates a borrower's bad debt by repaying the borrow and seizing collateral.
     * @dev This function can only be called by the contract owner. It triggers a liquidation of a borrower's position
     * if they have bad debt. The underlying amount of the debt is liquidated and the borrower’s collateral is seized.
     * @param _borrower The address of the borrower whose debt is being liquidated.
     */
    function _liquidateBadDebt(address _borrower) internal onlyOwner {
        (uint256 borrowLiquidationRisk, , ) = checkLiquidationRisk(_borrower);

        // @dev bad debt is only achievable if liquidation risk threshold is bigger than 1e18
        if (borrowLiquidationRisk < MATH_SCALING_FACTOR) {
            revert PositionIsNotHaveBadDebt();
        }

        (
            address[] memory borrowedAssets,
            uint256[] memory borrowedAmounts,
            address[] memory suppliedAssets,
            uint256[] memory suppliedAmounts
        ) = calcBadBorrowerDetails(_borrower);

        // we liquidate all the borrowers bad debts
        uint256 i;
        while (borrowedAssets[i] != address(0) && i < borrowedAssets.length) {
            IBaseProtocol(borrowedAssets[i]).liquidateBadDebt(
                _borrower,
                borrowedAmounts[i]
            );
            i++;
        }

        i = 0;
        // 2. we iterate over the borrower supplied positions to remove collaterals and get compensation for user and protocol
        while (suppliedAssets[i] != address(0) && i < suppliedAssets.length) {
            if (suppliedAmounts[i] > 0) {
                IBaseProtocol(suppliedAssets[i]).seizeBadCollateral(
                    _borrower,
                    suppliedAmounts[i]
                );
            }
            i++;
        }

        emit LiquidateBadDebt(_borrower);
    }

    /**
     * @notice Calculates the details of a borrower's bad debt position.
     * @dev This function returns the borrowed and supplied assets along with their amounts for a given borrower.
     * It checks each asset in the borrower's account and identifies the borrowed amounts that can be liquidated.
     * If the total reserves of an asset are insufficient for liquidation, the function reverts with an error.
     * @param _borrower The address of the borrower whose bad debt details are being calculated.
     * @return borrowedAssets An array of addresses representing the assets the borrower has borrowed.
     * @return borrowedUnderlyings An array of amounts representing the borrowed underlyings for each asset.
     * @return suppliedAssets An array of addresses representing the assets the borrower has supplied.
     * @return suppliedAmounts An array of amounts representing the supplied amounts for each asset.
     */
    function calcBadBorrowerDetails(
        address _borrower
    )
        public
        view
        returns (
            address[] memory borrowedAssets,
            uint256[] memory borrowedUnderlyings,
            address[] memory suppliedAssets,
            uint256[] memory suppliedAmounts
        )
    {
        address[] memory assets = accountAssets[_borrower].values();
        borrowedAssets = new address[](assets.length);
        borrowedUnderlyings = new uint256[](assets.length);
        suppliedAssets = new address[](assets.length);
        suppliedAmounts = new uint256[](assets.length);
        uint256 arrIndexBorrow = 0;
        uint256 arrIndexSupply = 0;

        for (uint i = 0; i < assets.length; i++) {
            IBaseProtocol asset = IBaseProtocol(assets[i]);
            (
                uint256 shareBalance,
                uint256 borrowedUnderlying,
                uint256 suppliedAmount,

            ) = asset.getAccountSnapshot(_borrower);

            if (borrowedUnderlying > 0) {
                if (asset.totalReserves() < borrowedUnderlying) {
                    revert NotEnoughTotalReservesToLiquidate(assets[i]);
                }

                borrowedAssets[arrIndexBorrow] = assets[i];
                borrowedUnderlyings[arrIndexBorrow] = borrowedUnderlying;
                arrIndexBorrow++;
            }
            if (shareBalance > 0) {
                suppliedAssets[arrIndexSupply] = assets[i];
                suppliedAmounts[arrIndexSupply] = suppliedAmount;
                arrIndexSupply++;
            }
        }
    }

    /**
     * @notice Validates a liquidation process.
     * @param _liquidator Address of the liquidator initiating the process.
     * @param _borrower Address of the borrower being liquidated.
     * @param _liquidateUnderlying Amount of collateral to be liquidated.
     * @return True if the liquidation is allowed, false otherwise.
     * @return Percentage Amount of Liquidation Profit.
     */
    function validateLiquidate(
        address _liquidator,
        address _borrower,
        uint256 _liquidateUnderlying
    ) public view returns (bool, uint256, uint256) {
        if (_liquidateUnderlying == 0) {
            revert LiquidationAmountShouldBeMoreThanZero();
        }
        if (_borrower == _liquidator) {
            revert CannotLiquidateSelf();
        }

        if (!validateBorrower(_borrower)) {
            revert UserDoesNotHaveBorrow();
        }

        (
            uint256 borrowerLiquidationRisk,
            uint256 borrowerDebtUsd,

        ) = checkLiquidationRisk(_borrower);

        if (borrowerLiquidationRisk < liquidateRiskThreshold) {
            revert PositionIsNotLiquidatable();
        }

        (
            uint256 liquidatorLiquidationRisk,
            uint256 liquidatorDebtUsd,
            uint256 liquidatorSuppliedUsd
        ) = checkLiquidationRisk(_liquidator);

        if (liquidatorLiquidationRisk >= liquidateRiskThreshold) {
            revert LiquidatorHealthFactorIsLessThanThreshold();
        }

        uint256 fundAvailableForLiquidation = liquidatorSuppliedUsd -
            liquidatorDebtUsd;

        if (fundAvailableForLiquidation < borrowerDebtUsd) {
            revert LiquidatorDoesNotHaveEnoughFundsToLiquidate();
        }

        return (true, borrowerLiquidationRisk, fundAvailableForLiquidation);
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function validateBorrow(
        address _token,
        address _borrower,
        uint256 _borrowUnderlying
    ) external override onlyValidCaller(_token) returns (bool) {
        MarketInfo storage info = markets[_token];

        if (borrowGuardianPaused[_token]) revert BorrowPaused();

        if (!info.accountMembership[_borrower]) {
            // if borrower didn't ever borrow, nothing else
            markets[_token].accountMembership[_borrower] = true;
            if (!accountAssets[_borrower].contains(_token)) {
                accountAssets[_borrower].add(_token);
            }
        }

        if (!validateBorrower(_borrower)) {
            borrowerList.add(_borrower);
        }

        if (!_checkValidation(_borrower, _token, 0, _borrowUnderlying))
            revert UnderCollaterlized();

        return true;
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function validateRedeem(
        address _token,
        address _redeemer,
        uint256 _redeemUnderlying
    ) external view override onlyValidCaller(_token) {
        if (!_checkValidation(_redeemer, _token, _redeemUnderlying, 0))
            revert UnderCollaterlized();
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function getBorrowableAmount(
        address _account,
        address _token
    ) external view override returns (uint256) {
        if (borrowGuardianPaused[_token]) {
            return 0;
        }

        IBaseProtocol asset = IBaseProtocol(_token);

        (
            uint256 ltvCollateralUSD,
            uint256 totalDebtUSD,
            ,
            uint256 borrowTokenPrice
        ) = _getCollateralAndDebt(_account, _token);

        uint256 underlyingDecimals = uint256(asset.underlyingDecimals());

        uint256 availableCollateral = totalDebtUSD >= ltvCollateralUSD
            ? 0
            : ltvCollateralUSD - totalDebtUSD;

        uint256 borrowableUnderlying = (availableCollateral *
            (10 ** underlyingDecimals)) / borrowTokenPrice;

        uint256 poolAmount = asset.getUnderlyingBalance();

        borrowableUnderlying = borrowableUnderlying > poolAmount
            ? poolAmount
            : borrowableUnderlying;

        return borrowableUnderlying;
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function getRedeemableAmount(
        address _account,
        address _token
    ) external view override returns (uint256) {
        IBaseProtocol asset = IBaseProtocol(_token);

        (
            uint256 ltvCollateralUSD,
            uint256 totalDebtUSD,
            uint256 totalSuppliedUSD,
            uint256 borrowTokenPrice
        ) = _getCollateralAndDebt(_account, _token);

        //@dev avoid division by 0 error and just return zero
        if (ltvCollateralUSD == 0) return 0;

        (, , uint256 totalSupplied, ) = asset.getAccountSnapshot(_account);
        uint256 totalUnderlying = asset.getUnderlyingBalance() -
            asset.totalReserves();

        uint256 underlyingDecimals = uint256(asset.underlyingDecimals());

        uint256 ratio = (totalSuppliedUSD * MATH_SCALING_FACTOR) /
            ltvCollateralUSD;

        uint256 availableCollateralUSD = totalDebtUSD >= ltvCollateralUSD
            ? 0
            : ltvCollateralUSD - totalDebtUSD;

        if (totalDebtUSD == 0) {
            availableCollateralUSD = totalSuppliedUSD;
        }

        /**
         * @dev Collateral balance must 15% higher than borrow amount
         * totalDebtUSD is already subtracted from the ltvCollateralUSD
         */
        uint256 collateralBalanceUSD = (totalDebtUSD * 15) / (1e2);

        uint256 redeemableAmountUSD = availableCollateralUSD >
            collateralBalanceUSD
            ? ((availableCollateralUSD - collateralBalanceUSD) * ratio) /
                MATH_SCALING_FACTOR
            : 0;

        uint256 redeemableUnderlying = (redeemableAmountUSD *
            (10 ** underlyingDecimals)) / borrowTokenPrice;

        /**
         * @dev there maybe a rare case where user cannot withdraw his underlying
         * due to high volume of borrowed funds
         */
        uint256 limitForRedeem = totalSupplied > totalUnderlying
            ? totalUnderlying
            : totalSupplied;

        redeemableUnderlying = redeemableUnderlying > limitForRedeem
            ? limitForRedeem
            : redeemableUnderlying;

        return redeemableUnderlying;
    }

    /**
     * @notice Calculates the total collateral, total debt, total supplied, and borrow token price for a given account and token.
     * @dev This function aggregates the collateral and debt information across all assets associated with the account.
     * @param _account The address of the account to calculate the collateral and debt for.
     * @param _token The address of the specific token for which the borrow token price is calculated.
     * @return ltvCollateralUSD The total collateral value of the account in USD.
     * @return totalDebtUSD The total debt value of the account in USD.
     * @return totalSuppliedUSD The total supplied value of the account, adjusted for borrow caps in USD.
     * @return borrowTokenPrice The price of the specified borrow token.
     */
    function _getCollateralAndDebt(
        address _account,
        address _token
    )
        internal
        view
        returns (
            uint256 ltvCollateralUSD,
            uint256 totalDebtUSD,
            uint256 totalSuppliedUSD,
            uint256 borrowTokenPrice
        )
    {
        address[] memory assets = _getAssetsWithToken(_account, _token);

        /**
         * @dev this function is itterates over the array with assets, cause
         * user can supply in one token and borrow in other
         */
        uint256 length = assets.length;
        uint256 accountLtvCollateralUSD;
        uint256 accountDebtUSD;
        uint256 price;

        for (uint256 i = 0; i < length; i++) {
            (
                accountLtvCollateralUSD,
                accountDebtUSD,
                price
            ) = _calCollateralAndDebt(_account, assets[i], 0, 0);

            if (assets[i] == _token) {
                borrowTokenPrice = price;
            }

            /// @dev totalCollateral here accounts borrow caps
            ltvCollateralUSD += accountLtvCollateralUSD;
            totalDebtUSD += accountDebtUSD;
            totalSuppliedUSD +=
                (accountLtvCollateralUSD * 100) /
                loanToValue[assets[i]];
        }
    }

    /**
     * @notice Validates if the specified borrower is in the borrower list.
     * @param _borrower The address of the borrower.
     * @return A boolean indicating if the borrower is in the list.
     */
    function validateBorrower(address _borrower) internal view returns (bool) {
        return borrowerList.contains(_borrower);
    }

    /**
     * @notice Checks how many users are in the borrower list.
     * @return number of borrowers.
     */
    function borrowListLength() public view returns (uint256) {
        return borrowerList.length();
    }

    /**
     * @notice Checks the validation of account's collateral and debt.
     * @param _account The address of the account.
     * @param _token The address of the token.
     * @param _redeemUnderlying The amount to be redeemed.
     * @param _borrowUnderlying The amount to be borrowed.
     * @return A boolean indicating if the account is under-collateralized.
     */
    function _checkValidation(
        address _account,
        address _token,
        uint256 _redeemUnderlying,
        uint256 _borrowUnderlying
    ) internal view returns (bool) {
        address[] memory assets = _getAssetsWithToken(_account, _token);
        uint256 length = assets.length;

        uint256 ltvCollateralUSD;
        uint256 totalDebtUSD;
        for (uint256 i = 0; i < length; i++) {
            (
                uint256 accountLtvCollateralUSD,
                uint256 accountDebtUSD,

            ) = _calCollateralAndDebt(
                    _account,
                    assets[i],
                    assets[i] == _token ? _borrowUnderlying : 0,
                    assets[i] == _token ? _redeemUnderlying : 0
                );

            ltvCollateralUSD += accountLtvCollateralUSD;
            totalDebtUSD += accountDebtUSD;
        }

        return ltvCollateralUSD >= totalDebtUSD;
    }

    /**
     * @notice Calculates the collateral and debt for a given account and token.
     * @param _account The address of the account.
     * @param _token The address of the token.
     * @param _borrowUnderlying The amount to be borrowed.
     * @param _redeemUnderlying The amount to be redeemed.
     * @return accountLtvCollateralUSD The USD amount of collateral supplied by the account.
     * @return accountDebtUSD The USD amount of debt the account should pay.
     * @return tokenPrice The price of the token.
     */
    function _calCollateralAndDebt(
        address _account,
        address _token,
        uint256 _borrowUnderlying,
        uint256 _redeemUnderlying
    )
        internal
        view
        returns (
            uint256 accountLtvCollateralUSD,
            uint256 accountDebtUSD,
            uint256 tokenPrice
        )
    {
        IBaseProtocol asset = IBaseProtocol(_token);
        (, uint256 borrowedAmount, uint256 accountCollateralTokens, ) = asset
            .getAccountSnapshot(_account);

        SupraPair memory supra = supraPair[asset.underlyingToken()];
        tokenPrice = supraOracle.getPrice(supra);

        if (tokenPrice == 0) revert PriceError();

        uint256 underlyingDecimals = uint256(asset.underlyingDecimals());

        uint256 redeemUnderlying = ((_redeemUnderlying * loanToValue[_token]) /
            1e2) + _borrowUnderlying;

        /**
         * @dev it divided by (1e2 * underlyingDecimals) to get the usd price
         * in 1e18 decimals and not to get errors for smaller values.
         */
        accountLtvCollateralUSD =
            (tokenPrice * accountCollateralTokens * loanToValue[_token]) /
            (1e2 * 10 ** underlyingDecimals);

        accountDebtUSD =
            (tokenPrice * (redeemUnderlying + borrowedAmount)) /
            (10 ** underlyingDecimals);
    }

    /**
     * @notice Returns array of user assets with _token
     * @param _account - user address
     * @param _token - token that MUST be in the array
     */
    function _getAssetsWithToken(
        address _account,
        address _token
    ) internal view returns (address[] memory) {
        uint256 assetsLength = accountAssets[_account].length();
        uint256 length = accountAssets[_account].contains(_token)
            ? assetsLength
            : assetsLength + 1;
        address[] memory assets = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            assets[i] = assetsLength > i
                ? accountAssets[_account].at(i)
                : _token;
        }
        return assets;
    }

    /**
     * @inheritdoc IMarketPositionManager
     */
    function updateLiquidationRiskThreshold(
        uint256 _threshold
    ) external onlyOwner {
        if (_threshold > MATH_SCALING_FACTOR) revert InvalidLiquidationRisk();
        liquidateRiskThreshold = _threshold;
        emit UpdateLiquidationRiskThreshold(_threshold);
    }
}
