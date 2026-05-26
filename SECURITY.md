# Security Policy — Arxia (ARX) ERC-20

This document covers the threat model, trust assumptions, known limitations, and responsible disclosure process for the Arxia ERC-20 contract deployed on Base mainnet.

## Scope

- **In scope**: `contracts/Arxia.sol` and any related code in this repository.
- **Out of scope** (covered by separate audits or operational policies):
  - The future Lock-and-Mint bridge contract (separate codebase, separate audit at M24)
  - Sablier V2 vesting contracts (audited externally)
  - PinkSale presale and PinkLock liquidity locker (audited externally)
  - Multisig wallet configurations (Safe contracts, audited externally)
  - Off-chain infrastructure (RPC nodes, indexers, frontends)

## Threat model

### Assets at risk

| Asset | Value | Recovery if compromised |
|---|---|---|
| ARX balances of token holders | Market value of held ARX | None — transfers are irreversible |
| Total token supply integrity | Trust in 1B fixed cap | None — supply is constructor-fixed |
| Permit signatures in flight | Approved value | Limited — short deadlines mitigate |

### Adversary capabilities

| Adversary | Capability | Mitigation |
|---|---|---|
| External attacker (no privileged keys) | Standard ERC-20 interactions, MEV, mempool inspection | Contract has no admin functions to attack. Permit deadlines should be short. |
| Compromised allocation recipient (e.g., a multisig signer key) | Can transfer their own allocation | Multisig threshold prevents single-key compromise. Vesting contracts time-lock release. |
| Compromised deployer EOA | Cannot affect post-deploy state | Deployer has **no privilege** after deploy. Renouncing is structural (no Ownable). |
| MEV searcher | Front-run `permit()` submissions | Permit submissions are deterministic and authorization-equivalent regardless of submitter — not a security issue, only ordering. |
| Cloning / impersonation | Deploy lookalike contract on another chain | Bridge contract address publication on Basescan + arxia.one prevents confusion. |

### Out-of-threat-model

- **Governance attacks** — there is no on-chain governance on this contract
- **Oracle manipulation** — no oracle dependency
- **Flash loan attacks** — no flash mint, no economic surface to attack on this token
- **Reentrancy** — no external calls in any code path on this contract
- **Upgrade attacks** — contract is non-upgradeable, immutable

## Trust assumptions

1. **Solidity compiler 0.8.34** — assumes no critical bugs in solc 0.8.34 (compiler is pinned for reproducibility). 0.8.34 includes the fix for SOL-2025-1 (`LostStorageArrayWriteOnSlotOverflow`, fixed in 0.8.32) — though this bug is structurally inapplicable to Arxia (no storage arrays, no inline assembly).
2. **OpenZeppelin Contracts v5.0.2** — assumes OZ v5.0.2 ERC20 / ERC20Burnable / ERC20Permit are bug-free. These have been audited multiple times by OZ team, Certora, Trail of Bits, and others.
3. **EVM correctness** — assumes Base EVM implements EVM semantics correctly (Optimism-derived OP Stack).
4. **EIP-712 / EIP-2612 implementation** — `permit()` correctness depends on correct EIP-712 domain separator computation. Verified by tests including replay-attack reverts.

## Known limitations

### 1. Permit front-running (by-design)

`permit()` signatures placed in the mempool can be observed and submitted by any party before the intended submitter. **This is not a vulnerability**: the resulting state (spender allowance) is identical regardless of submitter.

**Mitigation**: Front-ends signing permits should use **short deadlines** (recommended: `block.timestamp + 1 hour` maximum). The shorter the deadline, the smaller the window for a stale signature to be replayed.

### 2. Loss of tokens sent to the contract address

ARX or other ERC-20 tokens sent directly to the `Arxia` contract address are **permanently locked**. This is intentional — there is no admin recovery function (which would itself be an admin power). Users must verify recipient addresses before sending.

### 3. Vesting recipient compromise

If the team multisig signing a Sablier vesting stream is compromised, the attacker gains access only to the stream's claimable balance at that time — not the full vested allocation. Sablier's design enforces time-locked release independent of recipient key control.

### 4. Bridge address discovery

The L1 bridge address is **not registered on-chain** in this contract (intentional — see README §"Why no Bridge Whitelist"). Users must obtain the correct bridge address from the official documentation at arxia.one. **Phishing risk**: attackers may publish fake bridge addresses. Verify against the official source.

### 5. Gas spike attacks

Base sequencer occasionally experiences gas spikes. While not a contract-level concern, users should set reasonable gas limits and be aware that pending transactions may be delayed.

### 6. 85.7% branch coverage on Arxia.sol

The single uncovered branch is the constructor's defensive check `if (totalSupply() != MAX_SUPPLY) revert TotalSupplyMismatch();`. This branch is **mathematically unreachable** because the six allocation constants sum to exactly MAX_SUPPLY (250 + 200 + 150 + 150 + 130 + 120 = 1,000 million ARX). The check is kept as a defensive invariant guard against future modifications. See README §"Branch coverage justification".

## Disclosure process

### Reporting a vulnerability

If you discover a security issue in this contract, please **do not** open a public GitHub issue. Instead:

1. **Email**: `arxialayer1@proton.me` (ProtonMail — end-to-end encrypted for Proton-to-Proton senders; PGP public key auto-published on `keys.openpgp.org` for external senders)
2. **Encrypted subject suggestion**: `[ARXIA SECURITY] <short description>`

### Information to include

- Affected contract address (if deployed)
- Affected function(s) and line numbers (if known)
- Reproduction steps or proof-of-concept code (Foundry test preferred)
- Impact assessment (which assets are at risk)
- Your suggested mitigation (if any)
- Whether you wish to be credited publicly

### Our commitment

| Phase | Target time |
|---|---|
| Initial acknowledgment | Within 48 hours |
| Triage decision (in/out of scope, severity) | Within 7 days |
| Fix development | Severity-dependent (Critical: ≤ 14 days, High: ≤ 30 days) |
| Public disclosure (post-fix) | Coordinated with reporter, typically 30-90 days post-fix |

**Note**: Because this contract is non-upgradeable, "fix development" for an exploitable bug means deploying a new contract and coordinating a migration with holders. We commit to clear, honest communication if this ever becomes necessary.

### Out of scope reports

- Bugs in OpenZeppelin Contracts → report to https://github.com/OpenZeppelin/openzeppelin-contracts/security
- Bugs in Solidity compiler → report to https://github.com/ethereum/solidity/security
- Bugs in Base / OP Stack → report to https://www.base.org/security
- Bugs in PinkSale / PinkLock → report to PinkSale support

### Bug bounty

A formal bug bounty program may be announced post-mainnet (M24+). Until then, valid reports will be acknowledged publicly (with reporter consent) in the audit history section of the README.

## Past security reviews

| Date       | Reviewer            | Type                 | Findings                  | Report                            |
|------------|---------------------|----------------------|---------------------------|-----------------------------------|
| TBD        | InterFi             | Smart Contract Audit | submission pending        | `audit/interfi-arx-v1.0.0.pdf` (to be added post-audit) |
| Pending CI | Aderyn (automated)  | Static analysis      | configured via CI         | `audit/aderyn-notes.md` + `.github/workflows/aderyn.yml` |
| 2026-05-23 | Slither (automated) | Static analysis      | 0 findings (101 detectors)| `audit/slither-report.txt`        |
| 2026-05-23 | Halmos (automated)  | Symbolic execution   | 8 / 8 invariants proven   | `audit/halmos-report.txt`         |

## Verification

To verify the deployed contract matches this audited source:

```bash
# Local build (with foundry.toml's deterministic settings)
forge build

# Expected deployed bytecode SHA256
# d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193

# Compare against on-chain bytecode
cast code <DEPLOYED_ADDRESS> --rpc-url https://mainnet.base.org > deployed.bin
sha256sum deployed.bin
```

## License

This security policy is part of the Arxia repository, licensed under MIT.

---

**Contact**: arxialayer1@proton.me
**Last updated**: 2026-05-23
**Document version**: 1.0.0
