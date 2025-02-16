import { ethers } from "ethers";

async function approveTokens() {
  // Hardcoded values
  const RPC_URL = "https://testnet.hashio.io/api";
  const PRIVATE_KEY = "";
  const TOKEN_ADDRESS = "0x000000000000000000000000000000000042e926"; // Your token address
  const SPENDER_ADDRESS = "0xFB08405D49335D18A0f8E73Ec850F220F38C48EB"; // Your spender address
  const AMOUNT_TO_APPROVE = ethers.parseUnits("1000", 6);

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(PRIVATE_KEY, provider);

  const ERC20_ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
  ];
  try {
    const tokenContract = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, signer);

    console.log("Approving tokens...");
    const tx = await tokenContract.approve(SPENDER_ADDRESS, AMOUNT_TO_APPROVE);
    console.log("Transaction hash:", tx.hash);

    await tx.wait();
    console.log("Transaction confirmed");

    const allowance = await tokenContract.allowance(
      signer.address,
      SPENDER_ADDRESS
    );
    console.log(`New allowance: ${ethers.formatUnits(allowance, 6)}`);
  } catch (error) {
    console.error("Error:", error);
  }
}

approveTokens()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
