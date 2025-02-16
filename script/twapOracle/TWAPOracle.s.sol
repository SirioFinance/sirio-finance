// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SaucerSwapTWAPOracle} from "../../contracts/SaucerSwapTWAPOracle.sol";

contract DeployCrowdfunding is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryV1 = 0x0000000000000000000000000000000000103780;
        address hbar = 0x0000000000000000000000000000000000163B5a;
        address usdc = 0x000000000000000000000000000000000006f89a;

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        SaucerSwapTWAPOracle saucerSwapTWAPOracle = new SaucerSwapTWAPOracle(
            factoryV1,
            hbar,
            usdc
        );

        vm.stopBroadcast();

        console.log(
            "SaucerSwapTWAPOracle was deployed at: ",
            address(saucerSwapTWAPOracle)
        );
    }
}
