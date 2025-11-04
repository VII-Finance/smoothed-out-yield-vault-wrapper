pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SmoothYieldVault} from "src/SmoothYieldVault.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SmoothYieldVaultTest is Test {
    uint256 smoothingPeriod = 100;

    address owner = makeAddr("owner");
    SmoothYieldVault vault;
    ERC20Mock underlying;

    function setUp() public {
        underlying = new ERC20Mock();
        vault = new SmoothYieldVault(IERC20(address(underlying)), smoothingPeriod, owner);
    }

    function test_total_assets(uint256 initialBalance, uint256 profit) public {
        initialBalance = bound(initialBalance, 1 ether, 1_000_000 ether);
        profit = bound(profit, 1 ether, 100_000 ether);

        initialBalance = 1000 ether;
        profit = 10 ether;

        // Example test to ensure setup works
        underlying.mint(address(this), initialBalance);
        underlying.approve(address(vault), initialBalance);
        vault.deposit(initialBalance, address(this));

        underlying.mint(address(vault), profit); // Simulate yield

        //test when time elapsed is less than remaining period
        for (uint256 i = 1; i < 100; i++) {
            uint256 divider = smoothingPeriod / i;
            vm.warp(block.timestamp + divider); // Advance time by smoothingPeriod / i
            assertEq(vault.totalAssets(), initialBalance + (profit * divider / smoothingPeriod)); // profit / i should be available
            vm.warp(block.timestamp - divider); // back to where we were
        }

        // //for time exactly equal to remaining period
        // //it should simply return full profit
        vm.warp(block.timestamp + smoothingPeriod);
        assertEq(vault.totalAssets(), initialBalance + profit);

        underlying.mint(address(vault), profit);
        profit = profit + profit;

        for (uint256 i = 2; i < 100; i++) {
            uint256 divider = smoothingPeriod / i;
            vm.warp(block.timestamp + divider); // Advance time by smoothingPeriod / i
            assertEq(vault.totalAssets(), initialBalance + (profit / 2) + ((profit / 2) * divider / smoothingPeriod)); // profit / i should be available
            vm.warp(block.timestamp - divider); // back to where we were
        }
    }

    function test_total_assets_sync(uint256 initialBalance, uint256 profit) public {
        initialBalance = bound(initialBalance, 1 ether, 1_000_000 ether);
        profit = bound(profit, 1 ether, 100_000 ether);

        initialBalance = 1000 ether;
        profit = 10 ether;

        // Example test to ensure setup works
        underlying.mint(address(this), initialBalance);
        underlying.approve(address(vault), initialBalance);
        vault.deposit(initialBalance, address(this));

        underlying.mint(address(vault), profit); // Simulate yield

        //test when time elapsed is less than remaining period
        for (uint256 i = 1; i < smoothingPeriod; i++) {
            vm.warp(block.timestamp + 1); // Advance time by smoothingPeriod / i
            vault.sync();
            assertEq(vault.totalAssets(), initialBalance + (profit * i / smoothingPeriod)); // profit / i should be available
        }

        // //for time exactly equal to remaining period
        // //it should simply return full profit
        vm.warp(block.timestamp + 1);
        vault.sync();
        assertEq(vault.totalAssets(), initialBalance + profit);
    }

    function test_name_and_symbol() public {
        assertEq(underlying.name(), "ERC20Mock");
        assertEq(underlying.symbol(), "E20M");
        assertEq(vault.name(), "Smoothed Wrapped ERC20Mock");
        assertEq(vault.symbol(), "SW-E20M");
    }

    function test_setSmoothingPeriod(uint256 newSmoothingPeriod) public {
        newSmoothingPeriod = bound(newSmoothingPeriod, 1, 1 days);

        vm.prank(owner);
        vault.setSmoothingPeriod(newSmoothingPeriod);

        assertEq(vault.smoothingPeriod(), newSmoothingPeriod);
    }
}
