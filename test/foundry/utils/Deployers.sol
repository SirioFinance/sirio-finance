// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {InterestRateModel} from "../../../contracts/InterestRateModel.sol";
import {IHederaTokenService} from "../../../contracts/interfaces/IHederaTokenService.sol";
import {ISwapTWAPOracle} from "../../../contracts/interfaces/ISwapTWAPOracle.sol";
import {SupraOracle} from "../../../contracts/SupraOracle.sol";
import {NftToken} from "../../../contracts/NftToken.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";
import {HBARProtocol} from "../../../contracts/HBARProtocol.sol";
import {Params} from "./Params.sol";
import {FeeRate} from "../../../contracts/libraries/Types.sol";
import {MarketPositionManager} from "../../../contracts/MarketPositionManager.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockSupraOracle} from "../../MockSupraOracle.sol";
import {MockPriceOracle} from "../../MockPriceOracle.sol";

abstract contract Deployers is Params {
    // Constants
    string public constant NAME = "Sirio USD Coin";
    string public constant SYMBOL = "sfUSD";

    uint256 public constant MAX_PROTOCOL_SUPPLYCAP = 100000 * USDCs;
    uint256 public constant MAX_PROTOCOL_BORROWCAP = 100000 * USDCs;

    // Global variables
    IERC20 wbtc;
    IERC20 weth;
    IERC20 wethArb;
    IERC20 usdc;

    InterestRateModel interestRateModelWBTC;
    InterestRateModel interestRateModelHBAR;
    InterestRateModel interestRateModelUSDC;
    SupraOracle supraOracle;
    MockSupraOracle mockSupraOracle;
    MockPriceOracle mockPriceOracle;

    NftToken nftToken;
    NftToken nftToken2;
    NftToken nftToken3;

    MarketPositionManager marketPositionManager;

    SFProtocolToken sfWBTC;
    SFProtocolToken sfUSDC;
    SFProtocolToken sfWEth;
    HBARProtocol sfHBAR;

    Params.Data params;

    function deployContracts(address deployer) public {
        Params.Data memory data = Params.deploymentParams.foundry;
        params = data;

        wbtc = IERC20(data.WBTCAddress);
        weth = IERC20(data.WETHAddress);
        usdc = IERC20(data.USDCAddress);

        interestRateModelWBTC = new InterestRateModel(
            interestRates[data.WBTCAddress].blocksPerYear,
            interestRates[data.WBTCAddress].baseRatePerYear,
            interestRates[data.WBTCAddress].multiplerPerYear,
            interestRates[data.WBTCAddress].jumpMultiplierPerYear,
            interestRates[data.WBTCAddress].kink,
            interestRates[data.WBTCAddress].name
            // interestRates[data.WBTCAddress].decimals
        );

        interestRateModelHBAR = new InterestRateModel(
            interestRates[data.HBARAddress].blocksPerYear,
            interestRates[data.HBARAddress].baseRatePerYear,
            interestRates[data.HBARAddress].multiplerPerYear,
            interestRates[data.HBARAddress].jumpMultiplierPerYear,
            interestRates[data.HBARAddress].kink,
            interestRates[data.HBARAddress].name
            // interestRates[data.HBARAddress].decimals
        );

        interestRateModelUSDC = new InterestRateModel(
            interestRates[data.USDCAddress].blocksPerYear,
            interestRates[data.USDCAddress].baseRatePerYear,
            interestRates[data.USDCAddress].multiplerPerYear,
            interestRates[data.USDCAddress].jumpMultiplierPerYear,
            interestRates[data.USDCAddress].kink,
            interestRates[data.USDCAddress].name
            // interestRates[data.USDCAddress].decimals
        );

        nftToken = new NftToken(deployer);
        nftToken2 = new NftToken(deployer);
        nftToken3 = new NftToken(deployer);

        mockPriceOracle = new MockPriceOracle(
            data.USDCAddress,
            data.dexRouterV2Address
        );

        mockSupraOracle = new MockSupraOracle(
            address(data.supraPullOracle),
            address(data.supraStorageOracle),
            address(mockSupraOracle)
        );

        address implementation = address(new MarketPositionManager());

        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(
                MarketPositionManager.initialize,
                (
                    address(mockSupraOracle),
                    data.healthcareThresold,
                    data.liquidationPercentageProtocol
                )
            )
        );

        marketPositionManager = MarketPositionManager(proxy);

        // set this address to btc
        marketPositionManager.setSupraId(data.WBTCAddress, 0, 0, true);

        // set this address to eth
        marketPositionManager.setSupraId(data.WETHAddress, 1, 1, true);

        // set this address to usdc
        marketPositionManager.setSupraId(data.USDCAddress, 427, 427, true);

        marketPositionManager.setSupraId(data.HBARAddress, 432, 432, true);

        FeeRate memory feeRate = FeeRate({
            borrowingFeeRate: BORROWING_FEE_RATE,
            redeemingFeeRate: REDEEMING_FEE_RATE
        });

        sfWBTC = new SFProtocolToken(
            feeRate,
            data.WBTCAddress, // underlying token address
            address(interestRateModelWBTC),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.WBTC,
            data.HBARAddress,
            NAME,
            SYMBOL,
            8,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfUSDC = new SFProtocolToken(
            feeRate,
            data.USDCAddress, // underlying token address
            address(interestRateModelUSDC),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.USDC,
            data.HBARAddress,
            NAME,
            SYMBOL,
            6,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfWEth = new SFProtocolToken(
            feeRate,
            data.WETHAddress, // underlying token address
            address(interestRateModelUSDC),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.WETH,
            data.HBARAddress,
            NAME,
            SYMBOL,
            6,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfHBAR = new HBARProtocol(
            feeRate,
            address(data.HBARAddress), // underlying token address
            address(interestRateModelHBAR),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.HBAR,
            8,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfHBAR.transferOwnership(deployer);
        sfWBTC.transferOwnership(deployer);
        sfUSDC.transferOwnership(deployer);
        marketPositionManager.transferOwnership(deployer);
    }

    function deployContractsArb(address deployer, bool useMockOracle) public {
        Params.Data memory data = Params.deploymentParams.foundry;
        params = data;

        wethArb = IERC20(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73);
        usdc = IERC20(0xf3C3351D6Bd0098EEb33ca8f830FAf2a141Ea2E1);
        wbtc = IERC20(0xEcC07BF95D53268d9204eC58788c4df067cE075c);

        mockPriceOracle = new MockPriceOracle(
            data.USDCAddress,
            data.dexRouterV2Address
        );

        supraOracle = new SupraOracle(
            address(data.supraPullOracle),
            address(data.supraStorageOracle),
            address(mockPriceOracle)
        );

        mockSupraOracle = new MockSupraOracle(
            address(data.supraPullOracle),
            address(data.supraStorageOracle),
            address(mockPriceOracle)
        );

        address priceOracleInUse = useMockOracle
            ? address(mockSupraOracle)
            : address(supraOracle);

        address implementation = address(new MarketPositionManager());

        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(
                MarketPositionManager.initialize,
                (
                    address(priceOracleInUse),
                    data.healthcareThresold,
                    data.liquidationPercentageProtocol
                )
            )
        );

        marketPositionManager = MarketPositionManager(proxy);

        // set this address to eth
        marketPositionManager.setSupraId(
            0x980B62Da83eFf3D4576C647993b0c1D7faf17c73,
            1,
            1,
            true
        );

        marketPositionManager.setSupraId(
            0xEcC07BF95D53268d9204eC58788c4df067cE075c,
            0,
            0,
            true
        );

        // set this address to usdc
        marketPositionManager.setSupraId(
            0xf3C3351D6Bd0098EEb33ca8f830FAf2a141Ea2E1,
            427,
            432,
            false
        );

        // set this address to hbar
        marketPositionManager.setSupraId(
            0xA63939cd4cB6e75851bB3b9022d1D782a0a57e5b,
            432,
            432,
            true
        );

        FeeRate memory feeRate = FeeRate({
            borrowingFeeRate: BORROWING_FEE_RATE,
            redeemingFeeRate: REDEEMING_FEE_RATE
        });

        interestRateModelWBTC = new InterestRateModel(
            interestRates[data.WBTCAddress].blocksPerYear,
            interestRates[data.WBTCAddress].baseRatePerYear,
            interestRates[data.WBTCAddress].multiplerPerYear,
            interestRates[data.WBTCAddress].jumpMultiplierPerYear,
            interestRates[data.WBTCAddress].kink,
            interestRates[data.WBTCAddress].name
            // interestRates[data.WBTCAddress].decimals
        );

        interestRateModelHBAR = new InterestRateModel(
            interestRates[data.HBARAddress].blocksPerYear,
            interestRates[data.HBARAddress].baseRatePerYear,
            interestRates[data.HBARAddress].multiplerPerYear,
            interestRates[data.HBARAddress].jumpMultiplierPerYear,
            interestRates[data.HBARAddress].kink,
            interestRates[data.HBARAddress].name
            // interestRates[data.HBARAddress].decimals
        );

        interestRateModelUSDC = new InterestRateModel(
            interestRates[data.USDCAddress].blocksPerYear,
            interestRates[data.USDCAddress].baseRatePerYear,
            interestRates[data.USDCAddress].multiplerPerYear,
            interestRates[data.USDCAddress].jumpMultiplierPerYear,
            interestRates[data.USDCAddress].kink,
            interestRates[data.USDCAddress].name
            // interestRates[data.USDCAddress].decimals
        );

        nftToken = new NftToken(deployer);
        nftToken2 = new NftToken(deployer);
        nftToken3 = new NftToken(deployer);

        sfWEth = new SFProtocolToken(
            feeRate,
            0x980B62Da83eFf3D4576C647993b0c1D7faf17c73, // underlying token address
            address(interestRateModelHBAR),
            address(marketPositionManager),
            address(nftToken), //nft token
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.WETH,
            0x0000000000000000000000000000000000003aD2, // hbar address
            "name",
            "symbol",
            8,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfUSDC = new SFProtocolToken(
            feeRate,
            0xf3C3351D6Bd0098EEb33ca8f830FAf2a141Ea2E1, // underlying token address
            address(interestRateModelHBAR),
            address(marketPositionManager),
            address(nftToken), //nft token
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.USDC,
            0x0000000000000000000000000000000000003aD2, // hbar address
            "name",
            "symbol",
            6,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfHBAR = new HBARProtocol(
            feeRate,
            0xA63939cd4cB6e75851bB3b9022d1D782a0a57e5b, // random address
            address(interestRateModelHBAR),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.HBAR,
            8,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        sfWBTC = new SFProtocolToken(
            feeRate,
            0xEcC07BF95D53268d9204eC58788c4df067cE075c,
            address(interestRateModelWBTC),
            address(marketPositionManager),
            address(nftToken),
            address(nftToken2),
            address(nftToken3),
            initialExchangeRates.WBTC,
            0x0000000000000000000000000000000000003aD2, // hbar address
            NAME,
            SYMBOL,
            8,
            data.maxProtocolBorrows,
            data.maxProtocolSupply,
            data.reserveFactorMantissa
        );

        //0xEcC07BF95D53268d9204eC58788c4df067cE075c use for btc

        sfWEth.transferOwnership(deployer);
        sfUSDC.transferOwnership(deployer);
        sfWBTC.transferOwnership(deployer);
        sfUSDC.transferOwnership(deployer);
        sfHBAR.transferOwnership(deployer);
        supraOracle.transferOwnership(deployer);
        marketPositionManager.transferOwnership(deployer);
    }
}
