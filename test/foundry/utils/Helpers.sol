// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;
import {Deployers} from "./Deployers.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {SFProtocolToken} from "../../../contracts/SFProtocolToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

contract Helpers is Test, Deployers {
    uint256 constant USDC_USER_AMOUNT = 100000000000e20;
    uint256 constant WETH_USER_AMOUNT = 100000000000e20;
    uint256 constant WBTC_USER_AMOUNT = 100000000000e20;
    uint256 constant NATIVE_USER_AMOUNT = 100000000000e20;

    function supplyUnderlyingHBAR(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        sfHBAR.supplyUnderlyingNative{value: _amount}();
        vm.stopPrank();
    }

    function supplyUnderlyingBTC(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        wbtc.approve(address(sfWBTC), type(uint256).max);
        sfWBTC.supplyUnderlying(_amount);
        vm.stopPrank();
    }

    function supplyUnderlyingETH(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        weth.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(_amount);
        vm.stopPrank();
    }

    function supplyUnderlyingETHArb(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        wethArb.approve(address(sfWEth), type(uint256).max);
        sfWEth.supplyUnderlying(_amount);
        vm.stopPrank();
    }

    function supplyUnderlyingUSDC(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        usdc.approve(address(sfUSDC), type(uint256).max);
        sfUSDC.supplyUnderlying(_amount);
        vm.stopPrank();
    }

    function borrowMaxSFProtocolToken(
        address _user,
        SFProtocolToken _contract
    ) public {
        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            _user,
            address(_contract)
        );

        console.log("borrowable", borrowable);

        vm.prank(_user);
        _contract.borrow(borrowable);
    }

    function borrowSFProtocolToken(
        uint256 _amount,
        address _user,
        SFProtocolToken _contract
    ) public {
        vm.prank(_user);
        _contract.borrow(_amount);
    }

    function borrowMaxHBAR(address _user) public returns (uint256) {
        uint256 borrowable = marketPositionManager.getBorrowableAmount(
            _user,
            address(sfHBAR)
        );

        vm.prank(_user);
        sfHBAR.borrow(borrowable);
        return borrowable;
    }

    function BorrowSFPHBAR(uint256 _amount, address _user) public {
        vm.startPrank(_user);
        sfHBAR.borrow(_amount);
        vm.stopPrank();
    }

    function warpTimeForwards(uint256 _seconds) public {
        vm.warp(block.timestamp + _seconds);
    }

    function roundToDecimals(
        uint256 _value,
        uint256 _decimals
    ) public pure returns (uint256) {
        return (_value / 10 ** _decimals) * 10 ** _decimals;
    }

    function dealBunch(address[] memory _users) public {
        for (uint i = 0; i < _users.length; i++) {
            deal(address(wbtc), _users[i], WBTC_USER_AMOUNT);
            deal(address(weth), _users[i], WETH_USER_AMOUNT);
            deal(address(usdc), _users[i], USDC_USER_AMOUNT);
            // deal(
            //     address(0x435FC409F14b2500A1E24C20516250Ad89341627),
            //     _users[i],
            //     WBTC_USER_AMOUNT
            // );
            deal(
                address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
                _users[i],
                USDC_USER_AMOUNT
            );
            deal(_users[i], NATIVE_USER_AMOUNT);
        }
    }
}
