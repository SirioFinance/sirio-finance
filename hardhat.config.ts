import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "solidity-coverage";
import "dotenv/config";

const config: HardhatUserConfig = {
  defaultNetwork: "testnet",
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${process.env.ETH_INFURA_ID}`,
        blockNumber: 18761944,
      },
    },
    testnet: {
      url: process.env.TESTNET_ENDPOINT,
      accounts: [
        process.env.TESTNET_OPERATOR_PRIVATE_KEY!,
        process.env.TESTNET_TESTER_PRIVATE_KEY!,
      ],
      timeout: 600000,
    },
    mainnet: {
      url: "https://mainnet.hashio.io/api",
      chainId: 295,
      accounts: [process.env.MAINNET_OPERATOR_PRIVATE_KEY!],
      timeout: 600000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
          },
          viaIR: true,
        },
      },
    ],
  },
  mocha: {
    timeout: 600000,
  },
};

export default config;
