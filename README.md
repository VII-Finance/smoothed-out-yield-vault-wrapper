# SmoothYieldVault

**SmoothYieldVault** is an ERC4626 compliant vault that wraps yield-generating rebasing tokens (like stETH) and smooths their yield distribution over time. Instead of immediately reflecting yield gains from the underlying asset, the vault gradually releases profits over a configurable smoothing period, providing users with predictable and steady yield accrual.