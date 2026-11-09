# Security policy: Arxia (ARX) ERC-20 token contract

## Scope

In scope: `contracts/Arxia.sol` in this repository.

Out of scope: OpenZeppelin Contracts (report to the OpenZeppelin project), the Solidity compiler (report to the Solidity project), the network the contract is deployed on, the addresses set at construction, and off-chain infrastructure.

## Status

The token contract exists on a test network only. No token is live, there are no holders and there is no market.

ERC-20 token contract audited by SolidProof, zero findings. The protocol, bridge, wallet and embedded code have not been audited yet.

## Reporting a vulnerability

Do not open a public GitHub issue. Email arxia.network@proton.me with the subject `[ARXIA SECURITY] <short description>` and include:

- the affected function(s) and line numbers, if known
- reproduction steps or a proof of concept (a Foundry test is preferred)
- the impact
- a suggested mitigation, if any
- whether you want public credit

| Phase | Target |
|---|---|
| Initial acknowledgment | Within 48 hours |
| Triage decision (scope, severity) | Within 7 days |
| Public disclosure | Coordinated with the reporter after a fix |

The contract cannot be upgraded. A fix for an exploitable bug means deploying a new contract.

## Trust assumptions

1. Solidity 0.8.34 (pinned) has no critical bug affecting this contract.
2. OpenZeppelin Contracts v5.0.2 (`ERC20`, `ERC20Burnable`, `ERC20Permit`) behave as specified.
3. The network the contract is deployed on implements EVM semantics correctly.
4. `permit()` depends on a correct EIP-712 domain separator, which includes the chain ID and the contract address. Tests cover replay reverts.

## Known limitations

1. **Permit front-running (by design).** A signed EIP-2612 permit can be submitted by anyone who sees it. The resulting allowance is the same whoever submits it. Front ends should use short deadlines.
2. **Tokens sent to the contract address are locked permanently.** There is no recovery function, because one would itself be an admin power.
3. **Branch coverage is 85.7%.** The one uncovered branch is the constructor guard `revert TotalSupplyMismatch()`, which cannot be reached because the six constructor mint constants sum exactly to `MAX_SUPPLY`. See README, "Branch coverage justification".

## Reviews and verification

Audit and automated analysis: see the Audit section of [README.md](README.md) and the records in [audit/](audit/). The test network deployment was verified on its block explorer against this source; the address and links are in [audit/sepolia-deployment.md](audit/sepolia-deployment.md).

Contact: arxia.network@proton.me
