// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20}         from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit}   from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title  Arxia (ARX) — pre-mainnet ERC-20 representation
/// @author Arxia
/// @notice Fixed-supply ERC-20 with burn + EIP-2612 permit. Will be bridged
///         1:1 to Arxia L1 native ARX at mainnet launch (M24+). The L1
///         bridge interacts with this contract via standard transferFrom
///         and is registered off-chain (documentation + Basescan comments).
/// @dev    ZERO ADMIN SURFACE. This contract has no Ownable, no setter
///         functions, no role-based access, no upgradeability. All state
///         except per-holder balances and per-owner permit nonces is set
///         at construction and immutable thereafter.
///
///         Explicitly EXCLUDES BY DESIGN:
///           - mint post-constructor (fixed supply, hard cap = MAX_SUPPLY)
///           - pause / unpause / emergency stop
///           - blacklist, freeze, seize from holders
///           - transfer fees, reflection, anti-whale, max-tx, max-wallet
///           - proxy / upgradeability (immutable bytecode)
///           - ERC20Votes / delegation (governance off-chain via Snapshot)
///           - ERC20FlashMint
///           - any admin role, owner, or privileged address whatsoever
/// @custom:security-contact arxialayer1@proton.me
contract Arxia is ERC20, ERC20Burnable, ERC20Permit {
    /// @notice Semantic version of this contract source.
    string public constant VERSION = "1.0.0";

    /// @notice Hard cap on total supply (10^15 base units = 1,000,000,000 ARX).
    ///         Equal to totalSupply() at deployment; can only decrease via burn.
    uint256 public constant MAX_SUPPLY = 1_000_000_000e6;

    // --- Allocations (base units, 6 decimals) -------------------------------
    uint256 private constant _NODE_OPERATORS = 250_000_000e6; // 25%
    uint256 private constant _ECOSYSTEM      = 200_000_000e6; // 20%
    uint256 private constant _TEAM_VESTING   = 150_000_000e6; // 15%
    uint256 private constant _IDO            = 150_000_000e6; // 15%
    uint256 private constant _TREASURY       = 130_000_000e6; // 13%
    uint256 private constant _SEED_VESTING   = 120_000_000e6; // 12%

    /// @notice Thrown when a zero address is provided where non-zero required.
    error ZeroAddress();
    /// @notice Thrown if the constructor invariant on total supply is violated.
    error TotalSupplyMismatch();

    /// @dev    All six recipients are independent and immutable after deploy.
    ///         No mechanism exists to redirect, freeze, or recover allocations.
    /// @param nodeOperatorsAddress Recipient of 250,000,000 ARX (25%) — node-rewards multisig.
    /// @param ecosystemAddress     Recipient of 200,000,000 ARX (20%) — ecosystem grants multisig.
    /// @param teamVestingAddress   Recipient of 150,000,000 ARX (15%) — Sablier vesting stream.
    /// @param idoAddress           Recipient of 150,000,000 ARX (15%) — multisig funding the
    ///                             PinkSale presale and locking LP via PinkLock post-finalization.
    /// @param treasuryAddress      Recipient of 130,000,000 ARX (13%) — treasury multisig.
    /// @param seedVestingAddress   Recipient of 120,000,000 ARX (12%) — Sablier vesting stream.
    constructor(
        address nodeOperatorsAddress,
        address ecosystemAddress,
        address teamVestingAddress,
        address idoAddress,
        address treasuryAddress,
        address seedVestingAddress
    )
        ERC20("Arxia", "ARX")
        ERC20Permit("Arxia")
    {
        if (nodeOperatorsAddress == address(0)) revert ZeroAddress();
        if (ecosystemAddress     == address(0)) revert ZeroAddress();
        if (teamVestingAddress   == address(0)) revert ZeroAddress();
        if (idoAddress           == address(0)) revert ZeroAddress();
        if (treasuryAddress      == address(0)) revert ZeroAddress();
        if (seedVestingAddress   == address(0)) revert ZeroAddress();

        _mint(nodeOperatorsAddress, _NODE_OPERATORS);
        _mint(ecosystemAddress,     _ECOSYSTEM);
        _mint(teamVestingAddress,   _TEAM_VESTING);
        _mint(idoAddress,           _IDO);
        _mint(treasuryAddress,      _TREASURY);
        _mint(seedVestingAddress,   _SEED_VESTING);

        // @dev Defensive invariant — UNREACHABLE BY CONSTRUCTION.
        //      The 6 allocation constants sum to exactly MAX_SUPPLY:
        //        250M + 200M + 150M + 150M + 130M + 120M = 1,000M
        //      This branch exists only as a guard against future regression
        //      (e.g., a developer modifying one constant without recalculating).
        //      Branch-coverage tools will report this as uncovered — this is
        //      expected and documented. See README §"Branch coverage justification"
        //      and SECURITY.md §"Known limitations" for the full justification.
        if (totalSupply() != MAX_SUPPLY) revert TotalSupplyMismatch();
    }

    /// @inheritdoc ERC20
    /// @dev ARX uses 6 decimals (aligned with USDC on Base).
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
