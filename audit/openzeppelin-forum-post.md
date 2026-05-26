# Pre-audit community review: minimalist ERC-20 with fixed supply, EIP-2612 permit, no admin

**Forum**: https://forum.openzeppelin.com/c/general/16
**Category**: General > Community Reviews
**Target audience**: OZ maintainers, ERC-20 implementers, audit firms

---

## Post body

Hi all,

We're preparing to submit a fixed-supply ERC-20 to InterFi Network for audit before launching on Base mainnet, and we'd appreciate a community sanity-check from the OZ-savvy folks here before we ship.

### Token overview

**Arxia (ARX)** — a pre-mainnet ERC-20 representation of a future Layer 1 native token. The L1 launches in ~24 months; until then, ARX exists on Base for liquidity, treasury management, and ecosystem activities. At L1 mainnet launch, ARX bridges 1:1 to native ARX.

**Parameters**:
- Name: Arxia, Symbol: ARX, Decimals: 6
- Total supply: 1,000,000,000 ARX (fixed at constructor, no mint after)
- Network: Base mainnet (chainId 8453)
- License: MIT, Solidity 0.8.34, OpenZeppelin v5.0.2

### Design philosophy

We deliberately built the absolute minimum ERC-20 that satisfies our requirements:

- `ERC20` + `ERC20Burnable` + `ERC20Permit` — three OZ extensions
- No `Ownable` — the contract has `owner() == address(0)` from block 1
- No setter functions of any kind
- No upgradeability (no proxy, no UUPS, no Beacon)
- No bridge whitelist on-chain (the future bridge interacts via standard `transferFrom`; its address is documented off-chain)

The constructor mints 6 allocations to provided addresses. The total minted is asserted to equal `MAX_SUPPLY` via `revert TotalSupplyMismatch()` as a defensive invariant guard.

### What we removed (and where feedback would be most welcome)

After internal review, we removed several common patterns:

1. **No `setBridgeAddress()` + `renounceOwnership()` pattern** — initially we had a one-shot setter for transparency. We removed it because:
   - The bridge needs zero privilege on the token
   - Even a one-shot setter creates an ownership window that automated scanners flag
   - Off-chain documentation is more flexible (V1 → V2 bridge migration possible)

2. **No `recoverERC20()` rescue function** — even with an immutable recovery destination, this introduces a privileged drain path. We chose to accept that mis-sent tokens are permanently lost.

3. **No public `MAX_SUPPLY` getter** initially — we added it because composability with future contracts that want to verify the cap is genuinely useful and zero risk.

4. **No ERC-165 `supportsInterface`** — ERC-20 predates ERC-165 and no major consumer (Uniswap, PinkSale, our future bridge) checks for it on ERC-20 tokens.

5. **No constructor "completion" event** — the 6 `Transfer(0, recipient, amount)` events from `_mint` already prove successful distribution; a redundant completion event would be noise.

### Specific questions for community review

1. **Bridge whitelist removal** — is removing the on-chain bridge registry entirely the right call? Or should we keep an immutable constructor-set bridge address (with the chicken-and-egg problem at deploy time)?

2. **`assert` → `revert TotalSupplyMismatch()`** in constructor — we replaced the original `assert(totalSupply() == _TOTAL_SUPPLY)` with `if (totalSupply() != MAX_SUPPLY) revert TotalSupplyMismatch();`. Some auditors flag `assert` (gas consumption on failure). Is the revert variant cleaner?

3. **Branch coverage** — the `TotalSupplyMismatch` revert is unreachable by construction (the 6 constants sum to `MAX_SUPPLY`). This shows as 85.7% branch coverage. Is there a cleaner way to express the invariant that auditors will not flag?

4. **EIP-2612 permit front-running** — we document this as a known limitation (it is not a vulnerability — the signed value goes to the same spender regardless of submitter). Is there messaging guidance from the OZ team on how to communicate this to retail users?

5. **6 decimals choice** — we chose 6 for USDC parity on Base. Most newer Base tokens are 18. Will this cause any unexpected integration issues with DEX aggregators or wallets?

### What we have already done

- **43 Foundry tests** passing — positive, negative, fuzz (10k runs), invariant (1k runs × 100k calls)
- **100% line coverage, 100% function coverage** on `contracts/Arxia.sol`
- **Slither** 0 findings (101 detectors, OZ deps filtered)
- **Halmos** symbolic execution — 8/8 invariants proven [link to report]
- **Aderyn** static analysis — configured in GitHub Actions [link to report]
- **Deterministic build** verified — two clean builds produce identical bytecode
- **Bytecode SHA256**: `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193`

### Code

GitHub: [link to repo]

Direct link to main contract: [link to `contracts/Arxia.sol`]

Direct link to tests: [link to `test/Arxia.t.sol`]

SECURITY.md: [link]

### Ask

Specifically looking for:

- **Bugs we missed** — any edge case in the test coverage that should be added?
- **Style/idiom feedback** — does the code match OZ v5 conventions?
- **Patterns we should reconsider** — any of the 5 "removed features" that you think we should add back?
- **Documentation feedback** — is the NatSpec exhaustive? Is the README clear?
- **Audit firm intelligence** — anyone who has submitted similar minimalist tokens to InterFi has notes on common findings to preempt?

Thanks in advance for the time. Community pre-review is a high-value step before a paid audit, and we will read every reply.

— Arxia team
