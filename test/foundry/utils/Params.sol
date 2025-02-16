// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import {FeeRate} from "../../..//contracts/libraries/Types.sol";

abstract contract Params {
    // Constants
    uint16 public constant BORROWING_FEE_RATE = 100;
    uint16 public constant REDEEMING_FEE_RATE = 200;
    uint16 public constant CLAIMING_FEE_RATE = 150;
    uint256 public constant LTV_USDC = 77;
    uint256 public constant LTV_BTC = 78;
    uint256 public constant LTV_ETH = 80;
    uint256 public constant LTV_HBAR = 60;
    uint256 public constant LTV_HBARX = 58;

    uint256 public constant USDCs = 1e6;
    uint256 public constant WBTCs = 1e8;
    uint256 public constant WETHs = 1e8;
    uint256 public constant HSTs = 1e8;
    uint256 public constant SAUCEs = 1e6;
    uint256 public constant xSAUCEs = 1e6;
    uint256 public constant HBARs = 1e8;
    uint256 public constant HBARXs = 1e8;
    uint256 public constant HSUITEs = 1e4;

    struct DeploymentParams {
        Data hedera_mainnet;
        Data hedera_testnet;
        TokenData hedera_testnet_tokens;
        Data foundry;
    }

    struct Data {
        address dexRouterV2Address;
        address WBTCAddress;
        address WETHAddress;
        address HBARAddress;
        address HBARXAddress;
        address USDCAddress;
        address HSUITEAddress;
        uint256 initialExchangeRateMantissa;
        uint256 healthcareThresold;
        address supraPullOracle;
        address supraStorageOracle;
        address pythOracleContract;
        uint256 protocolSeizeShareMantissa;
        uint256 maxProtocolBorrows;
        uint256 maxProtocolSupply;
        uint256 liquidationPercentageProtocol;
        uint256 reserveFactorMantissa;
    }

    struct TokenData {
        address dexRouterV2Address;
        address HSTAddress;
        address HBARAddress;
        address HBARXAddress;
        address USDCAddress;
        address HSUITEAddress;
        address SAUCEAddress;
        address XSAUCEAddress;
        InitialExchangeRateManitsa initialExchangeRateMantissa;
        uint256 healthcareThresold;
        InterestRate interestRate;
        Decimals decimals;
        address supraPullOracle;
        address supraStorageOracle;
        address pythOracleContract;
        FeeRate feeRate;
        uint256 protocolSeizeShareMantissa;
    }

    struct Decimals {
        uint8 HBARDecimals;
        uint8 HBARXDecimals;
        uint8 USDCDecimals;
        uint8 HSUITEDecimals;
        uint8 SAUCEDecimals;
        uint8 XSAUCEDecimals;
        uint8 HSTDecimals;
    }

    struct InitialExchangeRateManitsa {
        uint256 HBAR;
        uint256 USDC;
        uint256 SAUCE;
        uint256 HST;
        uint256 HSUITE;
        uint256 WBTC;
        uint256 WETH;
        uint256 xSAUCE;
        uint256 HBARX;
    }

    struct InterestRate {
        uint256 blocksPerYear;
        uint256 baseRatePerYear;
        uint256 multiplerPerYear;
        uint256 jumpMultiplierPerYear;
        uint256 kink;
        string name;
        uint8 decimals;
    }

    DeploymentParams public deploymentParams;
    mapping(address => InterestRate) public interestRates;
    InitialExchangeRateManitsa public initialExchangeRates;
    InitialExchangeRateManitsa public seizeShareRates;

    constructor() {
        deploymentParams.hedera_testnet_tokens = TokenData({
            dexRouterV2Address: 0x0000000000000000000000000000000000004b40,
            HSTAddress: 0x000000000000000000000000000000000042E956,
            SAUCEAddress: 0x000000000000000000000000000000000042EB57,
            XSAUCEAddress: 0x000000000000000000000000000000000042EB6E,
            HBARAddress: 0x0000000000000000000000000000000000003aD2,
            HBARXAddress: 0x000000000000000000000000000000000042E941,
            USDCAddress: 0x000000000000000000000000000000000042E926,
            HSUITEAddress: 0x0000000000000000000000000000000000219D8e,
            initialExchangeRateMantissa: InitialExchangeRateManitsa({
                HBAR: 2e6,
                USDC: 2e4,
                SAUCE: 2e4,
                HST: 2e6,
                HSUITE: 2e2,
                WBTC: 2e6,
                WETH: 2e6,
                xSAUCE: 2e6,
                HBARX: 2e6
            }),
            healthcareThresold: 90e16,
            interestRate: InterestRate({
                blocksPerYear: 365 * 24 * 60 * 60,
                baseRatePerYear: 15e16,
                multiplerPerYear: 1e17,
                jumpMultiplierPerYear: 3e18,
                kink: 85e17,
                name: "MediumRateModel",
                decimals: 18
            }),
            decimals: Decimals({
                HBARDecimals: 8,
                HBARXDecimals: 8,
                USDCDecimals: 6,
                HSUITEDecimals: 4,
                SAUCEDecimals: 6,
                XSAUCEDecimals: 6,
                HSTDecimals: 8
            }),
            feeRate: FeeRate({borrowingFeeRate: 100, redeemingFeeRate: 200}),
            protocolSeizeShareMantissa: 2e6,
            supraPullOracle: 0x6bf7b21145Cbd7BB0b9916E6eB24EDA8A675D7C0,
            supraStorageOracle: 0x6Cd59830AAD978446e6cc7f6cc173aF7656Fb917,
            pythOracleContract: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
        });

        deploymentParams.foundry = Data({
            dexRouterV2Address: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            WBTCAddress: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            WETHAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            HBARAddress: 0x435FC409F14b2500A1E24C20516250Ad89341627,
            HBARXAddress: address(0),
            USDCAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            HSUITEAddress: address(0),
            initialExchangeRateMantissa: 2e6,
            healthcareThresold: 90e16,
            supraPullOracle: 0x6bf7b21145Cbd7BB0b9916E6eB24EDA8A675D7C0,
            supraStorageOracle: 0x6Cd59830AAD978446e6cc7f6cc173aF7656Fb917,
            pythOracleContract: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729,
            protocolSeizeShareMantissa: 2e6,
            reserveFactorMantissa: 5e15,
            liquidationPercentageProtocol: 3e17,
            maxProtocolBorrows: 100000000000e18,
            maxProtocolSupply: 100000000000e18
        });

        initialExchangeRates = InitialExchangeRateManitsa({
            HBAR: 2e6,
            USDC: 2e4,
            SAUCE: 2e6,
            HST: 2e6,
            HSUITE: 2e2,
            WBTC: 2e6,
            WETH: 2e6,
            xSAUCE: 2e6,
            HBARX: 2e8
        });

        seizeShareRates = InitialExchangeRateManitsa({
            HBAR: 2e6,
            USDC: 2e4,
            SAUCE: 2e4,
            HST: 2e6,
            HSUITE: 2e2,
            WBTC: 2e6,
            WETH: 2e6,
            xSAUCE: 2e6,
            HBARX: 2e6
        });

        interestRates[deploymentParams.foundry.WBTCAddress] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 8
        });
        interestRates[deploymentParams.foundry.WETHAddress] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 18
        });
        interestRates[deploymentParams.foundry.HBARAddress] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 18
        });
        interestRates[deploymentParams.foundry.USDCAddress] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 6
        });

        interestRates[
            deploymentParams.hedera_mainnet.WBTCAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 8
        });
        interestRates[
            deploymentParams.hedera_mainnet.WETHAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 18
        });
        interestRates[
            deploymentParams.hedera_mainnet.HBARAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 8
        });
        interestRates[
            deploymentParams.hedera_mainnet.USDCAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 6
        });

        // testnet
        interestRates[
            deploymentParams.hedera_testnet.WBTCAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 8
        });
        interestRates[
            deploymentParams.hedera_testnet.WETHAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 18
        });
        interestRates[
            deploymentParams.hedera_testnet.HBARAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 8
        });
        interestRates[
            deploymentParams.hedera_testnet.USDCAddress
        ] = InterestRate({
            blocksPerYear: 365 * 24 * 60 * 60,
            baseRatePerYear: 15e16,
            multiplerPerYear: 1e17,
            jumpMultiplierPerYear: 3e18,
            kink: 85e17,
            name: "MediumRateModel",
            decimals: 6
        });
    }
}
