import { BigNumberish, ethers } from "ethers";

const deploymentParams: DeploymentParams = {
  hedera_testnet_tokens: {
    dexRouterV2Address: "0x0000000000000000000000000000000000004b40", // SaucerSwap
    saucerSwapFactoryV1Address: "0x00000000000000000000000000000000000026e7",
    USDCAddress: "0x000000000000000000000000000000000042e926",
    SAUCEAddress: "0x000000000000000000000000000000000042eb57",
    HBARAddress: "0x0000000000000000000000000000000000003aD2",
    HBARXAddress: "0x000000000000000000000000000000000042e941",
    HSTAddress: "0x000000000000000000000000000000000042e956",
    XSAUCEAddress: "0x000000000000000000000000000000000042eb6e",
    HSUITEAddress: "0x0000000000000000000000000000000000219d8e",
    initialExchangeRateMantissa: {
      HBAR: 2000000,
      HBARX: 2000000,
      SAUCE: 20000,
      XSAUCE: 20000,
      USDC: 20000,
      PACK: 20000,
      HSUITE: 200,
      HST: 2000000,
    },
    healthcareThresold: ethers.parseUnits("0.90"),
    protocolSeizeShareMantissa: ethers.parseUnits("0.2"),
    reserveFactorMantissa: {
      HBAR: ethers.parseEther("0.2"),
      HBARX: ethers.parseEther("0.25"),
      USDC: ethers.parseEther("0.1"),
      HSUITE: ethers.parseEther("0.3"),
      SAUCE: ethers.parseEther("0.25"),
      XSAUCE: ethers.parseEther("0.25"),
      HST: ethers.parseEther("0.3"),
      PACK: ethers.parseEther("0.015"),
    },
    interestRate: {
      HbarInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.1"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.85"),
        name: "HbarInterstRate",
      },
      HbarXInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.1"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.8"),
        name: "HbarXInterstRate",
      },
      SauceInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.65"),
        name: "SauceInterstRate",
      },
      XSauceInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.6"),
        name: "XSauceInterstRate",
      },
      UsdcInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.02"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.8"),
        name: "UsdcInterstRate",
      },
      HstInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.8"),
        multiplerPerYear: ethers.parseEther("0.225"),
        jumpMultiplierPerYear: ethers.parseEther("1.25"),
        kink: ethers.parseEther("0.8"),
        name: "HstInterstRate",
      },
      HsuiteInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.02"),
        multiplerPerYear: ethers.parseEther("0.2"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.75"),
        name: "HsuiteInterstRate",
      },
      PackInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.6"),
        name: "PackInterstRate",
      },
    },
    decimals: {
      HBARDecimals: 8,
      HBARXDecimals: 8,
      USDCDecimals: 6,
      HSUITEDecimals: 4,
      SAUCEDecimals: 6,
      XSAUCEDecimals: 6,
      HSTDecimals: 8,
      PACKDecimals: 6,
    },
    loanToValue: {
      HBAR: 75,
      HBARX: 70,
      USDC: 80,
      HSUITE: 45,
      SAUCE: 65,
      XSAUCE: 60,
      HST: 50,
      PACK: 60,
    },
    fees: {
      borrowFee: 0,
      withdrawFee: 50,
    },
    maxBorrowCap: {
      HBARBorrows: ethers.parseUnits("500000000", 8),
      HBARXBorrows: ethers.parseUnits("300000000", 8),
      USDCBorrows: ethers.parseUnits("1000000000", 6),
      HSUITEBorrows: ethers.parseUnits("2000000000", 4),
      SAUCEBorrows: ethers.parseUnits("100000000", 6),
      XSAUCEBorrows: ethers.parseUnits("100000000", 6),
      HSTBorrows: ethers.parseUnits("200000000", 8),
      PACKBorrows: ethers.parseUnits("100000000", 6),
    },
    maxSupplyCap: {
      HBARSupplies: ethers.parseUnits("500000000", 8),
      HBARXSupplies: ethers.parseUnits("300000000", 8),
      USDCSupplies: ethers.parseUnits("1000000000", 6),
      HSUITESupplies: ethers.parseUnits("2000000000", 4),
      SAUCESupplies: ethers.parseUnits("100000000", 6),
      XSAUCESupplies: ethers.parseUnits("100000000", 6),
      HSTSupplies: ethers.parseUnits("200000000", 8),
      PACKSupplies: ethers.parseUnits("100000000", 6),
    },
    supraIds: {
      HBAR_USD: 432,
      HBARX_WHBAR: 427,
      SAUCE_WHBAR: 425,
      XSAUCE_WHBAR: 426,
      USDC_USD: 89,
      HST_WHBAR: 428,
      HSUITE_WHBAR: 488,
      PACK_WHBAR: 478,
    },
    supraPullOracle: "0x6bf7b21145Cbd7BB0b9916E6eB24EDA8A675D7C0",
    supraStorageOracle: "0x6Cd59830AAD978446e6cc7f6cc173aF7656Fb917",
  },
  hedera_mainnet: {
    dexRouterV2Address: "0x00000000000000000000000000000000002e7a5d", // SaucerSwap
    saucerSwapFactoryV1Address: "0x0000000000000000000000000000000000103780",
    TwapPoolHBARAddress: "0x0000000000000000000000000000000000163b5a",
    TwapPoolUSDCAddress: "0x000000000000000000000000000000000006f89a",
    USDCAddress: "0x000000000000000000000000000000000006f89a",
    SAUCEAddress: "0x00000000000000000000000000000000000b2ad5",
    HBARAddress: "0x0000000000000000000000000000000000163b5a",
    HBARXAddress: "0x00000000000000000000000000000000000cba44",
    HSTAddress: "0x00000000000000000000000000000000000ec585",
    XSAUCEAddress: "0x00000000000000000000000000000000001647e8",
    HSUITEAddress: "0x00000000000000000000000000000000000c01f3",
    PACKAddress: "0x0000000000000000000000000000000000492a28",
    initialExchangeRateMantissa: {
      HBAR: 2000000,
      HBARX: 2000000,
      SAUCE: 20000,
      XSAUCE: 20000,
      USDC: 20000,
      PACK: 20000,
      HSUITE: 200,
      HST: 2000000,
    },
    healthcareThresold: ethers.parseUnits("0.85"),
    protocolSeizeShareMantissa: ethers.parseUnits("0.2"),
    reserveFactorMantissa: {
      HBAR: ethers.parseEther("0.2"),
      HBARX: ethers.parseEther("0.25"),
      USDC: ethers.parseEther("0.1"),
      HSUITE: ethers.parseEther("0.3"),
      SAUCE: ethers.parseEther("0.25"),
      XSAUCE: ethers.parseEther("0.25"),
      HST: ethers.parseEther("0.3"),
      PACK: ethers.parseEther("0.015"),
    },
    interestRate: {
      HbarInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.1"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.85"),
        name: "HbarInterstRate",
      },
      HbarXInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.1"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.8"),
        name: "HbarXInterstRate",
      },
      SauceInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.65"),
        name: "SauceInterstRate",
      },
      XSauceInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.6"),
        name: "XSauceInterstRate",
      },
      UsdcInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.02"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.8"),
        name: "UsdcInterstRate",
      },
      HstInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.8"),
        multiplerPerYear: ethers.parseEther("0.225"),
        jumpMultiplierPerYear: ethers.parseEther("1.25"),
        kink: ethers.parseEther("0.8"),
        name: "HstInterstRate",
      },
      HsuiteInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.02"),
        multiplerPerYear: ethers.parseEther("0.2"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.75"),
        name: "HsuiteInterstRate",
      },
      PackInterstRate: {
        blocksPerYear: 365 * 24 * 60 * 60,
        baseRatePerYear: ethers.parseEther("0.015"),
        multiplerPerYear: ethers.parseEther("0.15"),
        jumpMultiplierPerYear: ethers.parseEther("3"),
        kink: ethers.parseEther("0.6"),
        name: "PackInterstRate",
      },
    },
    decimals: {
      HBARDecimals: 8,
      HBARXDecimals: 8,
      USDCDecimals: 6,
      HSUITEDecimals: 4,
      SAUCEDecimals: 6,
      XSAUCEDecimals: 6,
      HSTDecimals: 8,
      PACKDecimals: 6,
    },
    loanToValue: {
      HBAR: 75,
      HBARX: 70,
      USDC: 80,
      HSUITE: 45,
      SAUCE: 65,
      XSAUCE: 60,
      HST: 50,
      PACK: 60,
    },
    fees: {
      borrowFee: 0,
      withdrawFee: 50,
    },
    maxBorrowCap: {
      HBARBorrows: ethers.parseUnits("500000000", 8),
      HBARXBorrows: ethers.parseUnits("300000000", 8),
      USDCBorrows: ethers.parseUnits("1000000000", 6),
      HSUITEBorrows: ethers.parseUnits("2000000000", 4),
      SAUCEBorrows: ethers.parseUnits("100000000", 6),
      XSAUCEBorrows: ethers.parseUnits("100000000", 6),
      HSTBorrows: ethers.parseUnits("200000000", 8),
      PACKBorrows: ethers.parseUnits("100000000", 6),
    },
    maxSupplyCap: {
      HBARSupplies: ethers.parseUnits("500000000", 8),
      HBARXSupplies: ethers.parseUnits("300000000", 8),
      USDCSupplies: ethers.parseUnits("1000000000", 6),
      HSUITESupplies: ethers.parseUnits("2000000000", 4),
      SAUCESupplies: ethers.parseUnits("100000000", 6),
      XSAUCESupplies: ethers.parseUnits("100000000", 6),
      HSTSupplies: ethers.parseUnits("200000000", 8),
      PACKSupplies: ethers.parseUnits("100000000", 6),
    },
    supraIds: {
      HBAR_USD: 432,
      HBARX_WHBAR: 427,
      SAUCE_WHBAR: 425,
      XSAUCE_WHBAR: 426,
      USDC_USD: 89,
      HST_WHBAR: 428,
      HSUITE_WHBAR: 488,
      PACK_WHBAR: 478,
    },
    supraPullOracle: "0x41AB2059bAA4b73E9A3f55D30Dff27179e0eA181",
    supraStorageOracle: "0xD02cc7a670047b6b012556A88e275c685d25e0c9",
    nebulaGenesisNft: "0x00000000000000000000000000000000006c2ce7",
    nebulaRegenNft: "0x00000000000000000000000000000000007b5cbc",
    cosmicCyphtersNft: "0x0000000000000000000000000000000000777763",
  },
};

export const getDeploymentParam = (
  networkName: keyof DeploymentParams
): DeploymentParam => {
  return deploymentParams[networkName] as DeploymentParam;
};

export interface InterestRateModel {
  HbarInterstRate: InterestRate;
  HbarXInterstRate: InterestRate;
  SauceInterstRate: InterestRate;
  XSauceInterstRate: InterestRate;
  UsdcInterstRate: InterestRate;
  HstInterstRate: InterestRate;
  HsuiteInterstRate: InterestRate;
  PackInterstRate: InterestRate;
}

export interface InterestRate {
  blocksPerYear: number;
  baseRatePerYear: BigNumberish;
  multiplerPerYear: BigNumberish;
  jumpMultiplierPerYear: BigNumberish;
  kink: BigNumberish;
  name: string;
}

export interface DeploymentParam {
  dexRouterV2Address: string;
  TwapPoolHBARAddress?: string;
  TwapPoolUSDCAddress?: string;
  WBTCAddress?: string;
  WETHAddress?: string;
  HBARAddress?: string;
  HBARXAddress?: string;
  USDCAddress?: string;
  HSUITEAddress?: string;
  SAUCEAddress?: string;
  XSAUCEAddress?: string;
  HSTAddress?: string;
  PACKAddress?: string;
  initialExchangeRateMantissa: InitialExchangeRateMantissa;
  interestRate: InterestRateModel;
  healthcareThresold: BigNumberish;
  supraPullOracle?: string;
  supraStorageOracle?: string;
  decimals?: Decimals;
  maxBorrowCap?: MaxBorrowCaps;
  maxSupplyCap?: MaxSupplyCaps;
  supraIds?: SupraIds;
  protocolSeizeShareMantissa?: BigNumberish;
  reserveFactorMantissa?: ReserveFactorMantissa;
  saucerSwapFactoryV1Address?: string;
  loanToValue?: LoanToValue;
  fees?: Fees;
  nebulaGenesisNft?: string;
  nebulaRegenNft?: string;
  cosmicCyphtersNft?: string;
}

export interface Fees {
  borrowFee: any;
  withdrawFee: any;
}

export interface SupraIds {
  HBAR_USD: number;
  HBARX_WHBAR: number;
  SAUCE_WHBAR: number;
  XSAUCE_WHBAR: number;
  USDC_USD: number;
  HST_WHBAR: number;
  HSUITE_WHBAR: number;
  PACK_WHBAR: number;
}

export interface ReserveFactorMantissa {
  HBAR: BigNumberish;
  HBARX: BigNumberish;
  USDC: BigNumberish;
  HSUITE: BigNumberish;
  SAUCE: BigNumberish;
  XSAUCE: BigNumberish;
  HST: BigNumberish;
  PACK: BigNumberish;
}

export interface InitialExchangeRateMantissa {
  HBAR: BigNumberish;
  HBARX: BigNumberish;
  USDC: BigNumberish;
  HSUITE: BigNumberish;
  SAUCE: BigNumberish;
  XSAUCE: BigNumberish;
  HST: BigNumberish;
  PACK: BigNumberish;
}

export interface MaxBorrowCaps {
  HBARBorrows: BigNumberish;
  HBARXBorrows: BigNumberish;
  USDCBorrows: BigNumberish;
  HSUITEBorrows: BigNumberish;
  SAUCEBorrows: BigNumberish;
  XSAUCEBorrows: BigNumberish;
  HSTBorrows: BigNumberish;
  PACKBorrows: BigNumberish;
}

export interface MaxSupplyCaps {
  HBARSupplies: BigNumberish;
  HBARXSupplies: BigNumberish;
  USDCSupplies: BigNumberish;
  HSUITESupplies: BigNumberish;
  SAUCESupplies: BigNumberish;
  XSAUCESupplies: BigNumberish;
  HSTSupplies: BigNumberish;
  PACKSupplies: BigNumberish;
}

export interface LoanToValue {
  HBAR: BigNumberish;
  HBARX: BigNumberish;
  USDC: BigNumberish;
  HSUITE: BigNumberish;
  SAUCE: BigNumberish;
  XSAUCE: BigNumberish;
  HST: BigNumberish;
  PACK: BigNumberish;
}

export interface DeploymentParams {
  hedera_mainnet?: DeploymentParam;
  hedera_testnet?: DeploymentParam;
  hedera_testnet_tokens?: DeploymentParam;
  hardhat?: DeploymentParam;
}

export interface Decimals {
  WBTCDecimals?: number;
  WETHDecimals?: number;
  HBARDecimals?: number;
  HBARXDecimals?: number;
  USDCDecimals?: number;
  HSUITEDecimals?: number;
  SAUCEDecimals?: number;
  XSAUCEDecimals?: number;
  HSTDecimals?: number;
  PACKDecimals?: number;
}

export default deploymentParams;
