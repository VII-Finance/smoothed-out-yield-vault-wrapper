pragma solidity ^0.8.26;

import {ERC4626Test} from "erc4626-tests/ERC4626.test.sol";
import {SmoothYieldVault} from "src/SmoothYieldVault.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SmoothYieldVaultERC4626ness is ERC4626Test {
    uint256 smoothingPeriod = 8 hours;

    function setUp() public override {
        _underlying_ = address(new ERC20Mock());
        _vault_ = address(new SmoothYieldVault(IERC20(_underlying_), smoothingPeriod));
    }

    function setUpYield(Init memory init) public override {
        init.yield = bound(init.yield, type(int128).min, type(int128).max);
        super.setUpYield(init);
        vm.warp(block.timestamp + 4 hours);
        SmoothYieldVault(_vault_).sync();
    }
}
