require("dotenv").config();
const { ethers: hardhatEthers } = require("hardhat");
import parameterConfig from "../parameterConfig.json";
import { Contract, JsonRpcProvider, Wallet } from "ethers";
import SFPProtocolTokenABI from "../internal_abi/SFProtocolToken.json";
import interestRatesABI from "../internal_abi/InterestRateModel.json";

function checkFeeConfig(
  currentFeeRates: any[],
  configFees: {
    borrowingFeeRate: string | number;
    redeemingFeeRate: string | number;
    claimingFeeRate: string | number;
  }
) {
  const updatedFeeRates = [
    configFees.borrowingFeeRate === "noChange"
      ? currentFeeRates[0]
      : configFees.borrowingFeeRate,
    configFees.redeemingFeeRate === "noChange"
      ? currentFeeRates[1]
      : configFees.redeemingFeeRate,
    configFees.claimingFeeRate === "noChange"
      ? currentFeeRates[2]
      : configFees.claimingFeeRate,
  ];

  return updatedFeeRates;
}

function numberToPercentage(bigIntValue: string | number | bigint | boolean) {
  try {
    // Ensure the input is a BigInt
    const value = BigInt(bigIntValue);
    // Scale the value to preserve one decimal place
    const scaledValue = value * BigInt(1);
    // Perform rounding by adding 5 (half of 10)
    const roundedValue = (scaledValue + BigInt(5)) / BigInt(10);
    // Convert to string and format the result
    const percentageString = roundedValue.toString();

    // Ensure there is at least one digit before the decimal point
    const integerPart = percentageString.slice(0, -1) || "0";
    const decimalPart = percentageString.slice(-1);
    return `${integerPart}.${decimalPart}%`;
  } catch (error) {
    console.log("Invalid input", error);
  }
}

async function feeAdjustment() {
  const configFees = parameterConfig.fees;
  const network = parameterConfig.hederaRpcUrl;
  const privateKey = parameterConfig.privateKey;
  const sfProtocolContract = parameterConfig.sFProtocolContract;
  const positionManagerContract = parameterConfig.marketPositionManager;
  const positionManagerConfig = parameterConfig.positionManager;
  const configBorrowCaps = parameterConfig.positionManager.borrowCap;
  const interestRateConfig = parameterConfig.interestRates;

  const client = new JsonRpcProvider(network);

  const wallet = new Wallet(privateKey, client);

  // connection to the SFProtocolToken smart contract
  const sFProtocolContract = new Contract(
    sfProtocolContract,
    SFPProtocolTokenABI,
    wallet
  );
  const interestContract = new Contract(
    parameterConfig.interestRateContract,
    interestRatesABI,
    wallet
  );

  // connection to the MarketPositionManager smart contract
  const marketManager = await hardhatEthers.getContractAt(
    "MarketPositionManager",
    positionManagerContract,
    wallet
  );

  const feeRate = await sFProtocolContract.feeRate();
  console.log(
    "this is the Fee Rate which is currently beeing used\n",
    `Borrowing feeRate: ${numberToPercentage(
      feeRate.borrowingFeeRate
    )}  Redeem feeRate: ${numberToPercentage(
      feeRate.redeemingFeeRate
    )} claiming feeRate: ${numberToPercentage(feeRate.claimingFeeRate)}`
  );

  const updatedFees = checkFeeConfig(feeRate, configFees);

  await sFProtocolContract.setFeeRate(updatedFees);

  const feeRateAfter = await sFProtocolContract.feeRate();

  console.log(
    `updated FeeRates\n borrowing FeeRate: ${numberToPercentage(
      feeRateAfter.borrowingFeeRate
    )} redeem FeeRate: ${numberToPercentage(
      feeRateAfter.redeemingFeeRate
    )}claiming FeeRate: ${numberToPercentage(feeRateAfter.claimingFeeRate)}`
  );

  if (parameterConfig.positionManager.runBorrowCap) {
    await marketManager.setBorrowCaps(
      positionManagerConfig.addresses,
      configBorrowCaps
    );

    for (let i = 0; i < positionManagerConfig.addresses.length; i++) {
      const getBorrowCap = await marketManager.borrowCaps(
        positionManagerConfig.addresses[i]
      );
      console.log(
        `token address: ${positionManagerConfig.addresses[i]} new borrowCap is set to ${getBorrowCap}`
      );
    }
  }

  if (positionManagerConfig.runLiquidationRate) {
    const getLiquidationRate = await marketManager.maxLiquidateRate();
    console.log("current Liquidation Rate", getLiquidationRate);
    await marketManager.setMaxLiquidateRate(
      positionManagerConfig.liquidateRate
    );
    const updateLiquidationRate = await marketManager.maxLiquidateRate();
    console.log("updated liquidation Rate", updateLiquidationRate);
  }

  if (interestRateConfig.runInterest) {
    await interestContract.updateJumpRateModel(
      interestRateConfig.baseRatePerYear,
      interestRateConfig.multiplierPerYear,
      interestRateConfig.jumpMultiplierPerYear,
      interestRateConfig.kink
    );
    console.log("updated successfully");
  }
}

feeAdjustment().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
