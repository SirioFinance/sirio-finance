const ethers = require("ethers");
require("dotenv").config();
const { Wallet, JsonRpcProvider } = ethers;
import Config from "./configMainnet.json";
import contractABI from "./OracleAbi.json";
import UniswapAbi from "./UniswapPair.json";

const rpcUrl = Config.rpcUrl;
const provider = new JsonRpcProvider(rpcUrl);
const saucerPairs = Config.saucerPairs;
const tokenAddresses = Config.tokenAddress;
const twapOracleAddress = Config.twapOracleAddress;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;
const wallet = new Wallet(PRIVATE_KEY as string, provider);

const oracleContract = new ethers.Contract(
    twapOracleAddress,
    contractABI,
    wallet
);

async function updateOracle() {
    console.log(
        `Calling update function on TWAP Oracle contract:  ${twapOracleAddress}`
    );
    console.log("number of pairs is: ", saucerPairs.length);
    for (let i = 0; i < saucerPairs.length; i++) {
        const pairName = Object.keys(saucerPairs[i])[0];
        const pairAddress = Object.values(saucerPairs[i])[0];
        const splitPair = pairName.split("/");

        const uniswapPair = new ethers.Contract(
            pairAddress,
            UniswapAbi,
            wallet
        );
        const token0 = await uniswapPair.token0();
        const token1 = await uniswapPair.token1();

        const [reserve0, reserve1, blockTimestampLast] =
            await uniswapPair.getReserves();

        const [oracleBlockTimestampLast, oraclePairActive, price0Average] =
            await getOracleData(pairAddress);

        // TODO Update and sync pair only if needed:
        // 1. the price on pair have changed
        //

        const currentDate = new Date();
        const currentTimestamp = Math.floor(currentDate.getTime() / 1000); // Convert to seconds

        if (currentTimestamp - Number(blockTimestampLast) > 1800) {
            console.log("calling sync on the uniswap pair");
            const tx = uniswapPair.sync();
        }

        if (
            oraclePairActive === false ||
            oracleBlockTimestampLast !== blockTimestampLast ||
            price0Average === 0
        ) {
            console.log(
                `Updated pair: ${splitPair[0]}: ${token0} and ${splitPair[1]}: ${token1} at saucerswap address: ${pairAddress}`
            );

            try {
                const tx = await oracleContract.update(pairAddress);
                await tx.wait();
                console.log("Update transaction confirmed:", tx.hash);
            } catch (error) {
                console.error("Error updating Oracle contract:", error);
            }
        }

        // await uniswapPair.sync();
    }
}

async function retrivePrices() {
    for (let i = 0; i < tokenAddresses.length; i++) {
        const tokenName = Object.keys(tokenAddresses[i])[0];
        const tokenAddress = Object.values(tokenAddresses[i])[0];
        try {
            const price = await oracleContract.getTokenPrice(tokenAddress);
            const priceInUSD = Number(price) / 1e18;

            console.log(
                `Price ${tokenName} is: ${price} and USD price: ${priceInUSD} USD`
            );
        } catch (error) {
            console.error(
                `Error retriving price for ${tokenName}, token address is ${tokenAddress}, with error: ${error}`
            );
        }
    }
}

async function setTimeIntervalAdmin() {
    try {
        const tx = await oracleContract.setTimeIntervals(300, 3600);
        await tx.wait();
        console.log("time intervals has been updated:", tx.hash);
    } catch (error) {
        console.error("Error updating Oracle contract:", error);
    }
}

async function whereIsFactory() {
    const pairAddress = "0x4a46705176fac8fd5c8061f94a2c44416e7b20e6";

    const uniswapPair = new ethers.Contract(pairAddress, UniswapAbi, wallet);
    const factory = await uniswapPair.factory();

    console.log("Factory address is: ", factory);
}

async function getOracleData(pairAddress: any) {
    const data = await oracleContract.pairs(pairAddress);
    const {
        0: price0CumulativeLast,
        1: price1CumulativeLast,
        2: price0Average,
        3: price1Average,
        4: blockTimestampLast,
        5: active,
    } = data;

    return [blockTimestampLast, active, price0Average];
}

async function getPairsData() {
    for (let i = 0; i < saucerPairs.length; i++) {
        const pairName = Object.keys(saucerPairs[i])[0];
        const pairAddress = Object.values(saucerPairs[i])[0];
        try {
            const data = await oracleContract.pairs(pairAddress);

            const {
                0: price0CumulativeLast,
                1: price1CumulativeLast,
                2: price0Average,
                3: price1Average,
                4: blockTimestampLast,
                5: active,
            } = data;

            console.log(`\nPairData for ${pairName}:`);
            console.log(`  Price0 Cumulative Last: ${price0CumulativeLast}`);
            console.log(`  Price1 Cumulative Last: ${price1CumulativeLast}`);
            console.log(`  Price0 Average: ${price0Average}`);
            console.log(`  Price1 Average: ${price1Average}`);
            console.log(`  Last Block Timestamp: ${blockTimestampLast}`);
            console.log(`  Active: ${active}`);
        } catch (error) {
            console.error("Error updating Oracle contract:", error);
        }
    }
}

async function main() {
    while (true) {
        try {
            await updateOracle();
            await getPairsData();
            await retrivePrices();
            // await setTimeIntervalAdmin();
            // await whereIsFactory();
            console.log(
                `Waiting for ${Config.updateFrequencySeconds} for new updates`
            );
            await new Promise((resolve) =>
                setTimeout(resolve, Config.updateFrequencySeconds * 1000)
            );
        } catch (error) {
            console.error("Error in main loop:", error);
        }
    }
}

main().catch(console.error);
