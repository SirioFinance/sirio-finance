require("dotenv").config();

import Web3 from "web3";
import { contractAbi } from "./data";
import axios from "axios";
import Config from "./config.json";

const interval = Config.pullUpdateFrequencySeconds * 1000; // Convert to milliseconds
const pairIndexes = Config.pairIndexes;
const pairSymbols = Config.pairSymbols;
const chainType = Config.chainType;

let executionPromise: Promise<number> | null = null; // Track ongoing execution

console.log(
  `Starting Supra Pull Service at current Interval: ${Config.pullUpdateFrequencySeconds} seconds`
);

async function runSupraOracle(
  retries: number = 3,
  delay: number = 5000
): Promise<number> {
  const startTime = performance.now(); // Start time

  try {
    const supraOracle = axios.create({
      baseURL: "https://rpc-testnet-dora-2.supra.com",
    });

    const requestData: ProofRequest = {
      pair_indexes: pairIndexes,
      chain_type: chainType,
    };

    const RPC_URL = "https://testnet.hashio.io/api";
    const WALLET_ADDRESS = process.env.WALLET_ADDRESS!;
    const PRIVATE_KEY = process.env.PRIVATE_KEY!;
    const contractAddress = process.env.CONTRACT_ADDRESS!;

    const provider = new Web3(new Web3.providers.HttpProvider(RPC_URL));
    const supraContract = new provider.eth.Contract(
      contractAbi,
      contractAddress
    );
    const proof = await supraOracle.post("/get_proof", requestData);

    console.log("Proof received:", proof.data);
    console.log("Requesting proof for price index:", pairIndexes);
    console.log("Requesting proof for pairSymbols:", pairSymbols);

    const proofBytes = proof.data.proof_bytes;
    const bytes = Array.from(provider.utils.hexToBytes(proofBytes));
    const txData = supraContract.methods.verifyOracleProof(bytes).encodeABI();
    const nonce = await provider.eth.getTransactionCount(
      WALLET_ADDRESS,
      "pending"
    );

    const transactionObject = {
      from: WALLET_ADDRESS,
      to: contractAddress,
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
    // const receipt = await provider.eth.sendSignedTransaction(
    //   signedTransaction.rawTransaction!
    // );

    const receipt = await provider.eth.sendSignedTransaction(
      signedTransaction.rawTransaction,
      undefined,
      { checkRevertBeforeSending: false }
    );

    console.log("Transaction successful, receipt:", receipt.transactionHash);
    return 1; // Return 1 if successful
  } catch (error) {
    console.error("An error occurred during transaction:", error);

    if (retries > 0) {
      console.log(
        `Retrying in ${delay / 1000} seconds... (${retries} retries left)`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
      return await runSupraOracle(retries - 1, delay);
    } else {
      console.error("Max retries reached. Transaction failed.");
      return 0; // Return 0 if failed after max retries
    }
  } finally {
    const endTime = performance.now(); // End time
    const executionTime = endTime - startTime;
    console.log(`Execution time: ${executionTime.toFixed(2)} ms`);
  }
}

async function executeWithQueue(): Promise<number> {
  if (executionPromise) {
    console.log(
      "Waiting for the ongoing execution to complete before starting a new one."
    );
    return executionPromise;
  }

  executionPromise = runSupraOracle()
    .then((result) => {
      executionPromise = null; // Clear the promise after execution
      return result;
    })
    .catch((error) => {
      executionPromise = null; // Ensure promise is cleared on error
      throw error;
    });

  return executionPromise;
}

(async () => {
  try {
    const result = await executeWithQueue();
    console.log(`Initial run result: ${result}`);

    setInterval(async () => {
      const intervalResult = await executeWithQueue();
      console.log(`Interval run result: ${intervalResult}`);
    }, interval);
  } catch (error) {
    console.error("An error occurred in the main process:", error);
  }
})();

export interface ProofRequest {
  pair_indexes: number[];
  chain_type: string;
}
