import { getDeploymentParam } from "../script/params";
import { ethers, upgrades } from "hardhat";
import fs from "fs";
import path from "path";

// Deploys all contracts, adds to market, and token association
export async function deployTokens() {
  const [deployer] = await ethers.getSigners();

  console.log("deployer", deployer);
  const network = "hedera_mainnet";
  const param = getDeploymentParam(network);
  console.log("Deploying contracts with account: ", deployer.address);
  console.log("param", param);

  const feeRate = {
    borrowingFeeRate: param.fees?.borrowFee, // 1%
    redeemingFeeRate: param.fees?.withdrawFee, // 2%
  };

  const InterestRateModel = await ethers.getContractFactory(
    "InterestRateModel"
  );
  const HbarInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.HbarInterstRate.blocksPerYear),
    BigInt(param.interestRate.HbarInterstRate.baseRatePerYear),
    BigInt(param.interestRate.HbarInterstRate.multiplerPerYear),
    BigInt(param.interestRate.HbarInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.HbarInterstRate.kink),
    param.interestRate.HbarInterstRate.name
  );

  const HbarInterstRateAddress = await HbarInterstRate.getAddress();
  console.log(
    `Deploying Hbar InterestRateModel Contract Address: ${HbarInterstRateAddress}`
  );

  const HbarXInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.HbarXInterstRate.blocksPerYear),
    BigInt(param.interestRate.HbarXInterstRate.baseRatePerYear),
    BigInt(param.interestRate.HbarXInterstRate.multiplerPerYear),
    BigInt(param.interestRate.HbarXInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.HbarXInterstRate.kink),
    param.interestRate.HbarXInterstRate.name
  );

  const HbarXInterstRateAddress = await HbarXInterstRate.getAddress();
  console.log(
    `Deploying HbarX InterestRateModel Contract Address: ${HbarInterstRateAddress}`
  );

  const SauceInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.SauceInterstRate.blocksPerYear),
    BigInt(param.interestRate.SauceInterstRate.baseRatePerYear),
    BigInt(param.interestRate.SauceInterstRate.multiplerPerYear),
    BigInt(param.interestRate.SauceInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.SauceInterstRate.kink),
    param.interestRate.SauceInterstRate.name
  );

  const SauceInterstRateAddress = await SauceInterstRate.getAddress();
  console.log(
    `Deploying Sauce InterestRateModel Contract Address: ${SauceInterstRateAddress}`
  );

  const XSauceInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.XSauceInterstRate.blocksPerYear),
    BigInt(param.interestRate.XSauceInterstRate.baseRatePerYear),
    BigInt(param.interestRate.XSauceInterstRate.multiplerPerYear),
    BigInt(param.interestRate.XSauceInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.XSauceInterstRate.kink),
    param.interestRate.XSauceInterstRate.name
  );

  const XSauceInterstRateAddress = await XSauceInterstRate.getAddress();
  console.log(
    `Deploying XSauce InterestRateModel Contract Address: ${XSauceInterstRateAddress}`
  );

  const UsdcInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.UsdcInterstRate.blocksPerYear),
    BigInt(param.interestRate.UsdcInterstRate.baseRatePerYear),
    BigInt(param.interestRate.UsdcInterstRate.multiplerPerYear),
    BigInt(param.interestRate.UsdcInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.UsdcInterstRate.kink),
    param.interestRate.UsdcInterstRate.name
  );

  const UsdcInterstRateAddress = await UsdcInterstRate.getAddress();
  console.log(
    `Deploying USDC InterestRateModel Contract Address: ${UsdcInterstRateAddress}`
  );

  const HsuiteInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.HsuiteInterstRate.blocksPerYear),
    BigInt(param.interestRate.HsuiteInterstRate.baseRatePerYear),
    BigInt(param.interestRate.HsuiteInterstRate.multiplerPerYear),
    BigInt(param.interestRate.HsuiteInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.HsuiteInterstRate.kink),
    param.interestRate.HsuiteInterstRate.name
  );

  const HsuiteInterstRateAddress = await HsuiteInterstRate.getAddress();
  console.log(
    `Deploying HSUITE InterestRateModel Contract Address: ${HsuiteInterstRateAddress}`
  );

  const PackInterstRate = await InterestRateModel.deploy(
    BigInt(param.interestRate.PackInterstRate.blocksPerYear),
    BigInt(param.interestRate.PackInterstRate.baseRatePerYear),
    BigInt(param.interestRate.PackInterstRate.multiplerPerYear),
    BigInt(param.interestRate.PackInterstRate.jumpMultiplierPerYear),
    BigInt(param.interestRate.PackInterstRate.kink),
    param.interestRate.PackInterstRate.name
  );

  const PackInterstRateAddress = await PackInterstRate.getAddress();
  console.log(
    `Deploying Pack InterestRateModel Contract Address: ${PackInterstRateAddress}`
  );

  const PriceOracle = await ethers.getContractFactory("SaucerSwapTWAPOracle");
  const priceOracle = await PriceOracle.deploy(
    param.saucerSwapFactoryV1Address as string,
    param.TwapPoolHBARAddress as string,
    param.TwapPoolUSDCAddress as string
  );

  await priceOracle.transferOwnership(deployer);
  await priceOracle.connect(deployer).acceptOwnership();

  const priceOracleAddress = await priceOracle.getAddress();
  console.log(
    `Deploying TWAP backup Oracle Contract Address: ${priceOracleAddress}`
  );

  const SupraOracle = await ethers.getContractFactory("SupraOracle");
  const supraOracle = await SupraOracle.deploy(
    param.supraPullOracle as string,
    param.supraStorageOracle as string,
    priceOracleAddress
  );

  await supraOracle.transferOwnership(deployer);
  await supraOracle.connect(deployer).acceptOwnership();

  const supraOracleAddress = await supraOracle.getAddress();
  console.log(`Deploying SupraOracle Contract Address: ${supraOracleAddress}`);

  const nebulaGenesisNft = param.nebulaGenesisNft!;
  const nebulaRegenNft = param.nebulaRegenNft!;
  const cosmicCyphtersNft = param.cosmicCyphtersNft!;

  console.log(`nebulaGenesisNft Contract Address: ${nebulaGenesisNft}`);
  console.log(`nebulaRegenNft Contract  Address: ${nebulaRegenNft}`);
  console.log(`cosmicCyphtersNft Contract Address: ${cosmicCyphtersNft}`);

  // with Supra Oracle as price feed
  const MarketPositionManager = await ethers.getContractFactory(
    "MarketPositionManager"
  );
  const marketPositionManager = await upgrades.deployProxy(
    MarketPositionManager,
    [
      supraOracleAddress,
      BigInt(param.healthcareThresold),
      BigInt(param.protocolSeizeShareMantissa!),
    ],
    { initializer: "initialize" }
  );
  await marketPositionManager.waitForDeployment();
  const marketPositionManagerAddress = await marketPositionManager.getAddress();
  console.log(
    `Deploying Proxy marketPositionManager Contract Address: ${marketPositionManagerAddress}`
  );

  // Retrieve the implementation address using ERC-1967 standard functions.
  // ERC-1967 standardizes proxy storage slots to safely manage upgrades of contract implementations.
  // This ensures compatibility and safe upgrade paths for proxy contracts.
  // More info on ERC-1967: https://eips.ethereum.org/EIPS/eip-1967
  const marketPositionManagerImplAddress =
    await upgrades.erc1967.getImplementationAddress(
      marketPositionManagerAddress
    );
  console.log(
    `Deploying Implementation Contract Address: ${marketPositionManagerImplAddress}`
  );

  const SFProtocolToken = await ethers.getContractFactory("SFProtocolToken");
  const HBARProtocolToken = await ethers.getContractFactory("HBARProtocol");

  const USDClending = await SFProtocolToken.deploy(
    feeRate,
    param.USDCAddress as string,
    UsdcInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.USDC,
    param.HBARAddress as string,
    "usdc",
    "usdcl",
    param.decimals?.USDCDecimals!,
    param.maxBorrowCap?.USDCBorrows!,
    param.maxSupplyCap?.USDCSupplies!,
    param.reserveFactorMantissa?.USDC!
  );
  const USDClendingAddress = await USDClending.getAddress();
  await USDClending.transferOwnership(deployer);
  await USDClending.connect(deployer).acceptOwnership();
  console.log(`Deploying USDClending Contract Address: ${USDClendingAddress}`);

  const SAUCElending = await SFProtocolToken.deploy(
    feeRate,
    param.SAUCEAddress as string,
    SauceInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.SAUCE,
    param.HBARAddress as string,
    "weth",
    "wethl",
    param.decimals?.SAUCEDecimals!,
    param.maxBorrowCap?.SAUCEBorrows!,
    param.maxSupplyCap?.SAUCESupplies!,
    param.reserveFactorMantissa?.SAUCE!
  );
  const WSAUCElendingAddress = await SAUCElending.getAddress();
  await SAUCElending.transferOwnership(deployer);
  await SAUCElending.connect(deployer).acceptOwnership();

  console.log(
    `Deploying SAUCElending Contract Address: ${WSAUCElendingAddress}`
  );

  const HBARXlending = await SFProtocolToken.deploy(
    feeRate,
    param.HBARXAddress as string,
    HbarXInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.HBARX,
    param.HBARAddress as string,
    "hbarx",
    "hbarxl",
    param.decimals?.HBARXDecimals!,
    param.maxBorrowCap?.HBARXBorrows!,
    param.maxSupplyCap?.HBARXSupplies!,
    param.reserveFactorMantissa?.HBARX!
  );
  const HBARXlendingAddress = await HBARXlending.getAddress();
  await HBARXlending.transferOwnership(deployer);
  await HBARXlending.connect(deployer).acceptOwnership();

  console.log(
    `Deploying HBARXlending Contract Address: ${HBARXlendingAddress}`
  );

  const XSAUCElending = await SFProtocolToken.deploy(
    feeRate,
    param.XSAUCEAddress as string,
    XSauceInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.XSAUCE,
    param.HBARAddress as string,
    "xsauce",
    "xsauce",
    param.decimals?.XSAUCEDecimals!,
    param.maxBorrowCap?.XSAUCEBorrows!,
    param.maxSupplyCap?.XSAUCESupplies!,
    param.reserveFactorMantissa?.XSAUCE!
  );
  const XSAUCElendingAddress = await XSAUCElending.getAddress();
  await XSAUCElending.transferOwnership(deployer);
  await XSAUCElending.connect(deployer).acceptOwnership();

  console.log(
    `Deploying XSAUCElending Contract Address: ${XSAUCElendingAddress}`
  );

  const HBARlending = await HBARProtocolToken.deploy(
    feeRate,
    param.HBARAddress as string,
    HbarInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.HBAR,
    param.decimals?.HBARDecimals!,
    param.maxBorrowCap?.HBARBorrows!,
    param.maxSupplyCap?.HBARSupplies!,
    param.reserveFactorMantissa?.HBAR!
  );
  const HBARlendingAddress = await HBARlending.getAddress();
  await HBARlending.transferOwnership(deployer);
  await HBARlending.connect(deployer).acceptOwnership();

  console.log(`Deploying HBARlending contract address: ${HBARlendingAddress}`);

  const HSUITELending = await SFProtocolToken.deploy(
    feeRate,
    param.HSUITEAddress as string,
    HsuiteInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.HSUITE,
    param.HBARAddress as string,
    "hsuite",
    "hsuitel",
    param.decimals?.HSUITEDecimals!,
    param.maxBorrowCap?.HSUITEBorrows!,
    param.maxSupplyCap?.HSUITESupplies!,
    param.reserveFactorMantissa?.HSUITE!
  );
  const HSUITElendingAddress = await HSUITELending.getAddress();
  await HSUITELending.transferOwnership(deployer);
  await HSUITELending.connect(deployer).acceptOwnership();

  console.log(
    `Deploying HSUITELending Contract Address: ${HSUITElendingAddress}`
  );

  const PACKLending = await SFProtocolToken.deploy(
    feeRate,
    param.PACKAddress as string,
    PackInterstRateAddress,
    marketPositionManagerAddress,
    nebulaGenesisNft,
    nebulaRegenNft,
    cosmicCyphtersNft,
    param.initialExchangeRateMantissa.PACK,
    param.HBARAddress as string,
    "pack",
    "packl",
    param.decimals?.PACKDecimals!,
    param.maxBorrowCap?.PACKBorrows!,
    param.maxSupplyCap?.PACKSupplies!,
    param.reserveFactorMantissa?.PACK!
  );
  const PACKLendingAddress = await PACKLending.getAddress();
  await PACKLending.transferOwnership(deployer);
  await PACKLending.connect(deployer).acceptOwnership();
  console.log(`Deploying PACKLending Contract Address: ${PACKLendingAddress}`);

  console.log("Deployed successfully!");

  const marketManager = await ethers.getContractAt(
    "MarketPositionManager",
    marketPositionManagerAddress,
    deployer
  );

  await marketManager.addToMarket(USDClendingAddress);
  await marketManager.addToMarket(WSAUCElendingAddress);
  await marketManager.addToMarket(HBARlendingAddress);
  await marketManager.addToMarket(HBARXlendingAddress);
  await marketManager.addToMarket(XSAUCElendingAddress);
  await marketManager.addToMarket(HSUITElendingAddress);
  await marketManager.addToMarket(PACKLendingAddress);

  await marketManager.setLoanToValue(
    [
      USDClendingAddress,
      WSAUCElendingAddress,
      HBARlendingAddress,
      HBARXlendingAddress,
      XSAUCElendingAddress,
      HSUITElendingAddress,
      PACKLendingAddress,
    ],
    [
      param.loanToValue!.USDC,
      param.loanToValue!.SAUCE,
      param.loanToValue!.HBAR,
      param.loanToValue!.HBARX,
      param.loanToValue!.XSAUCE,
      param.loanToValue!.HSUITE,
      param.loanToValue!.PACK,
    ]
  );

  await marketManager.setSupraId(
    param.USDCAddress!,
    param.supraIds?.USDC_USD!,
    89,
    true
  );
  await supraOracle.addBackupFeed(param.USDCAddress!, param.USDCAddress!);

  await marketManager.setSupraId(
    param.SAUCEAddress!,
    param.supraIds?.SAUCE_WHBAR!,
    432,
    false
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.SAUCE_WHBAR!,
    param.SAUCEAddress!
  );

  await marketManager.setSupraId(
    param.XSAUCEAddress!,
    param.supraIds?.XSAUCE_WHBAR!,
    432,
    false
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.XSAUCE_WHBAR!,
    param.XSAUCEAddress!
  );

  await marketManager.setSupraId(
    param.HBARXAddress!,
    param.supraIds?.HBARX_WHBAR!,
    432,
    false
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.HBARX_WHBAR!,
    param.HBARXAddress!
  );

  await marketManager.setSupraId(
    param.HBARAddress!,
    param.supraIds?.HBAR_USD!,
    432,
    true
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.HBAR_USD!,
    param.HBARAddress!
  );

  await marketManager.setSupraId(
    param.HSUITEAddress!,
    param.supraIds?.HSUITE_WHBAR!,
    432,
    false
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.HSUITE_WHBAR!,
    param.HSUITEAddress!
  );

  await marketManager.setSupraId(
    param.PACKAddress!,
    param.supraIds?.PACK_WHBAR!,
    432,
    false
  );
  await supraOracle.addBackupFeed(
    param.supraIds?.PACK_WHBAR!,
    param.PACKAddress!
  );

  const usdclendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    USDClendingAddress,
    deployer
  );
  await usdclendingContract.tokenAssociate(param.USDCAddress as string);

  const wsaucelendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    WSAUCElendingAddress,
    deployer
  );
  await wsaucelendingContract.tokenAssociate(param.SAUCEAddress as string);

  const hbarxlendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    HBARXlendingAddress,
    deployer
  );
  await hbarxlendingContract.tokenAssociate(param.HBARXAddress as string);

  const xsauceLendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    XSAUCElendingAddress,
    deployer
  );
  await xsauceLendingContract.tokenAssociate(param.XSAUCEAddress as string);

  const hsuitelendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    HSUITElendingAddress,
    deployer
  );
  await hsuitelendingContract.tokenAssociate(param.HSUITEAddress as string);

  const packlendingContract = await ethers.getContractAt(
    "SFProtocolToken",
    PACKLendingAddress,
    deployer
  );
  await packlendingContract.tokenAssociate(param.PACKAddress as string);

  console.log("setting environment successfully!");

  const folderPath = `./deployed_addresses/${network}/`;
  const filePath = path.join(folderPath, "ContractAddresses.json");

  if (!fs.existsSync(folderPath)) {
    fs.mkdirSync(folderPath, { recursive: true });
  }

  const addresses = {
    HbarInterstRate: HbarInterstRateAddress,
    HbarXInterstRate: HbarXInterstRateAddress,
    SauceInterstRate: SauceInterstRateAddress,
    XSauceInterstRate: XSauceInterstRateAddress,
    UsdcInterstRate: UsdcInterstRateAddress,
    HsuiteInterstRate: HsuiteInterstRateAddress,
    PackInterstRate: PackInterstRateAddress,
    PriceOracle: priceOracleAddress,
    SupraOracle: supraOracleAddress,
    NebulaGenesisNft: nebulaGenesisNft,
    NebulaRegenNft: nebulaRegenNft,
    CosmicCyphtersNft: cosmicCyphtersNft,
    ProxyMarketPositionManager: marketPositionManagerAddress,
    ImplementationPositionManger: marketPositionManagerImplAddress,
    USDClending: USDClendingAddress,
    WSAUCE: WSAUCElendingAddress,
    XSAUCElending: XSAUCElendingAddress,
    HBARXlending: HBARXlendingAddress,
    HSUITELending: HSUITElendingAddress,
    PACKLending: PACKLendingAddress,
    HBARlending: HBARlendingAddress,
  };

  const dataString = JSON.stringify(addresses, null, 4);
  fs.writeFile(filePath, dataString, (err) => {
    if (err) {
      console.error("Failed to write JSON to file:", err);
    } else {
      console.log("JSON data has been written successfully to", filePath);
    }
  });
}

deployTokens().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
