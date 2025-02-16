// make this script faster, use promise bundling, other methods to make this script execute faster, we want below 5 seconds
require("dotenv").config();
import Web3 from "web3";
import { contractAbi, oracleProof, OracleProofV2Inputs } from "./data";
import axios from "axios";
import Config from "./config.json";

const interval = Config.pullUpdateFrequencySeconds * 1000; // Convert to milliseconds
const pairIndexes = Config.pairIndexes;
const pairSymbols = Config.pairSymbols;
const chainType = Config.chainType;
const rpcUrl = Config.rpcUrl;
const supraRpcUrl = Config.supraUrl;
const supraPullAddress = Config.supraPullContractAddress;
const callerAddress = Config.callerWalletAddress;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;

let isRunning = false; // Global lock variable

console.log(
  `Starting Supra Pull Service at current Interval: ${Config.pullUpdateFrequencySeconds} seconds`
);

async function runSupraOracle(
  retries: number = 3,
  delay: number = 5000
): Promise<void> {
  if (isRunning) {
    console.log("Operation already in progress, skipping this attempt.");
    return;
  }

  isRunning = true; // Acquire the lock

  const startTime = performance.now(); // Start time

  const supraOracle = axios.create({
    baseURL: supraRpcUrl,
  });

  const requestData: ProofRequest = {
    pair_indexes: pairIndexes,
    chain_type: chainType,
  };

  try {
    const proof = await supraOracle.post("/get_proof", requestData);

    console.log("Proof received:", proof.data);
    console.log("Requesting proof for price index:", pairIndexes);
    console.log("Requesting proof for pairSymbols:", pairSymbols);

    const provider = new Web3(new Web3.providers.HttpProvider(rpcUrl));
    const supraContract = new provider.eth.Contract(
      contractAbi,
      supraPullAddress
    );

    const proofBytes = proof.data.proof_bytes;
    const bytes = Array.from(provider.utils.hexToBytes(proofBytes));
    const txData = supraContract.methods.verifyOracleProof(bytes).encodeABI();
    const nonce = await provider.eth.getTransactionCount(
      callerAddress,
      "pending"
    );

    const transactionObject = {
      from: callerAddress,
      to: supraPullAddress,
      data: txData,
      gas: 15000000,
      gasPrice: await provider.eth.getGasPrice(),
      nonce: nonce,
    };

    // Sign the transaction with the private key
    const signedTransaction = await provider.eth.accounts.signTransaction(
      transactionObject,
      PRIVATE_KEY
    );

    // Send the signed transaction
    const receipt = await provider.eth.sendSignedTransaction(
      signedTransaction.rawTransaction,
      undefined,
      { checkRevertBeforeSending: false }
    );

    console.log("Transaction successful, receipt:", receipt.transactionHash);
  } catch (error) {
    console.error("An error occurred during transaction:", error);

    if (retries > 0) {
      console.log(
        `Retrying in ${delay / 1000} seconds... (${retries} retries left)`
      );
      setTimeout(async () => {
        await runSupraOracle(retries - 1, delay);
      }, delay);
    } else {
      console.error("Max retries reached. Transaction failed.");
    }
  } finally {
    const endTime = performance.now(); // End time
    const executionTime = endTime - startTime;
    console.log(`Execution time: ${executionTime.toFixed(2)} ms`);
    isRunning = false; // Release the lock
  }
}

(async () => {
  try {
    // Initial run
    await runSupraOracle();

    // Run every interval (e.g., 60 seconds)
    setInterval(async () => {
      await runSupraOracle();
    }, interval);
  } catch (error) {
    console.error("An error occurred in the main process:", error);
  }
})();

export interface ProofRequest {
  pair_indexes: number[];
  chain_type: string;
}
