// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {console} from "lib/forge-std/src/console.sol";

/// @title SmoothYieldVault
/// @notice ERC4626 vault that smooths yield distribution over time for yield generating rebasing tokens instead of immediate distribution
contract SmoothYieldVault is Ownable, ERC4626 {
    /// @notice Last synced asset balance
    uint256 public lastSyncedBalance;
    /// @notice Timestamp of last sync
    uint256 public lastSyncedTime;
    /// @notice Period over which yield is smoothed (in seconds)
    uint256 public smoothingPeriod;

    uint256 public remainingPeriod;

    event SmoothingPeriodUpdated(uint256 newSmoothingPeriod);
    event Sync();

    constructor(IERC20 _asset, uint256 _smoothingPeriod, address _owner) ERC4626(_asset) ERC20("", "") Ownable(_owner) {
        _setSmoothingPeriod(_smoothingPeriod);
        lastSyncedTime = block.timestamp;
        remainingPeriod = _smoothingPeriod;
    }

    function name() public view override(ERC20, IERC20Metadata) returns (string memory) {
        return string(bytes.concat("Smoothed Wrapped ", bytes(IERC20Metadata(asset()).name())));
    }

    function symbol() public view override(ERC20, IERC20Metadata) returns (string memory) {
        return string(bytes.concat("SW-", bytes(IERC20Metadata(asset()).symbol())));
    }

    /// @notice Calculate unsmoothed profit since last sync
    function _profit() internal view returns (uint256) {
        uint256 currentBalance = IERC20(asset()).balanceOf(address(this));
        /// @dev If there is a negative yield, no profit will be reported until it is recovered by positive yield
        return currentBalance < lastSyncedBalance ? 0 : currentBalance - lastSyncedBalance;
    }

    /// @notice Calculate smoothed profit based on time elapsed
    /// @dev Profit distribution logic:
    /// - If less than a smoothing period has passed: linear distribution based on time elapsed
    /// - If one or more periods have passed without sync:
    ///   * 1 period passed: half of profit available immediately, the other half smoothed over next period
    ///   * 2 periods passed: 2/3 of profit available immediately, 1/3 smoothed over next period
    ///   * n periods passed: n/(n+1) of profit available immediately, 1/(n+1) smoothed over next period
    function _smoothedProfit() internal view returns (uint256 smoothedProfit, uint256 newRemainingPeriod) {
        uint256 timeElapsed = block.timestamp - lastSyncedTime;
        if (timeElapsed == 0) {
            return (0, remainingPeriod);
        } else {
            uint256 profit = _profit();
            if (smoothingPeriod == 0) {
                return (profit, 0);
            }

            if (timeElapsed > smoothingPeriod) {
                //smoothing periods passed
                uint256 periodsPassed = (timeElapsed / smoothingPeriod) + 1;
                smoothedProfit = profit - (profit / periodsPassed);
                profit = profit - smoothedProfit;
                timeElapsed = timeElapsed % smoothingPeriod;
            }

            newRemainingPeriod =
                remainingPeriod >= timeElapsed ? remainingPeriod - timeElapsed : smoothingPeriod - timeElapsed;
            smoothedProfit += (profit * timeElapsed) / (newRemainingPeriod + timeElapsed);

            return (smoothedProfit, newRemainingPeriod);
        }
    }

    /// @notice Manually sync smoothed profit to lastSyncedBalance
    function sync() public {
        (uint256 smoothedProfit, uint256 newRemainingPeriod) = _smoothedProfit();
        if (smoothedProfit > 0) {
            lastSyncedBalance += smoothedProfit;
            lastSyncedTime = block.timestamp;
            remainingPeriod = newRemainingPeriod;
            emit Sync();
        }
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        sync();
        lastSyncedBalance += assets;
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        sync();
        lastSyncedBalance -= assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Set smoothing period (only owner)
    /// @param _smoothingPeriod New smoothing period in seconds
    function setSmoothingPeriod(uint256 _smoothingPeriod) external onlyOwner {
        sync();
        _setSmoothingPeriod(_smoothingPeriod);
    }

    function _setSmoothingPeriod(uint256 _smoothingPeriod) internal {
        smoothingPeriod = _smoothingPeriod;
        emit SmoothingPeriodUpdated(_smoothingPeriod);
    }

    /// @notice Get total assets including smoothed profit
    function totalAssets() public view override returns (uint256) {
        (uint256 smoothedProfit,) = _smoothedProfit();
        return lastSyncedBalance + smoothedProfit;
    }
}
