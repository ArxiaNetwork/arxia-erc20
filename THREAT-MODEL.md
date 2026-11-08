# Arxia (ARX) — Threat Model

> **Note.** This threat model dates from May 2026, before the token contract audit, and is kept as a record of the pre-audit analysis. Its network, distribution and bridge references describe plans Arxia no longer follows. ERC-20 token contract audited by SolidProof, zero findings. The protocol, bridge, wallet and embedded code have not been audited yet. The token contract exists on a test network only; no token is live, there are no holders and there is no market.

**Document version**: 1.0.0
**Last updated**: 2026-05-23
**Scope**: `contracts/Arxia.sol`
**Status**: ERC-20 token contract audited by SolidProof, zero findings. The protocol, bridge, wallet and embedded code have not been audited yet.
**Related**: [SECURITY.md](./SECURITY.md) · [DEPLOYMENT.md](./DEPLOYMENT.md) · [README.md](./README.md) · [audit/halmos-report.txt](./audit/halmos-report.txt) · [audit/sepolia-onchain-tests.md](./audit/sepolia-onchain-tests.md)

---

## 1. Overview

| Field | Value |
|---|---|
| Contract | `Arxia` (ARX) ERC-20 |
| Version | v1.0.0 |
| Network | Test network only (see §10.4). No token is live, no holders, no market. |
| Total supply | Minted once at construction (`MAX_SUPPLY`); no mint function; holders can burn their own tokens |
| Decimals | 6 |
| Compiler | Solidity 0.8.34 (pinned, post LostStorageArrayWriteOnSlotOverflow fix in 0.8.32) |
| Optimizer | enabled, runs = 200, via_ir = false |
| Build metadata | `bytecode_hash = "none"`, `cbor_metadata = false` (deterministic builds) |
| OpenZeppelin | v5.0.2 |
| **Deployed bytecode SHA256** | `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193` |
| License | MIT |
| Security contact | arxia.network@proton.me |

**Inheritance chain**: `ERC20`, `ERC20Burnable`, `ERC20Permit` (OpenZeppelin v5.0.2). No `Ownable`, no `Pausable`, no proxy, no upgradeability.

**Validation summary**:
- **Foundry**: 39 unit, integration and stress tests, 3 fuzz tests at 10,000 runs and 1 invariant test at 1,000 runs of depth 100 (43 tests in total), all passing at the 2026-05-23 run
- **Halmos symbolic execution**: 8/8 invariants proven (Z3 SMT solver)
- **Slither**: 0 findings across 101 detectors
- **Test network**: deployment with verified source code; on-chain functional tests passed for transfer, burn, approve, transferFrom, permit (see §10.4)

---

## 2. Trust Assumptions

### 2.1 Deployer wallet

The deployer EOA (or multisig) that submits the `CREATE` transaction has **no privileged role** on the contract after deployment. It is indistinguishable from any other holder thereafter. The deployer must:
- Hold enough of the network's native token to pay the deployment gas (~1.5M gas units)
- Correctly supply the six addresses as constructor arguments

Mis-typing an address at deploy time is irreversible — the contract is immutable.

### 2.2 Six constructor recipients

The six addresses passed to the constructor (see §3.1) are assumed to be:

- **Independent**: not controlled by a single party with a single key
- **Operationally secure**: multisig wallets with hardware-wallet signers, or audited contracts
- **Not coordinated maliciously**: the contract makes no assumption about their honesty, only their independence

If multiple recipient addresses share a single signer or collude, that is a social/operational risk, not a smart contract risk.

### 2.3 Token holders

Holders of ARX trust:
- The EVM's signature and hashing primitives (ECDSA, keccak256)
- The consensus and sequencing of the network the contract is deployed on
- The immutability of the deployed bytecode

Holders do **not** trust:
- The Arxia team (no ongoing on-chain privilege exists)
- Any oracle (none used)
- Any external contract (no cross-contract calls in any code path)

### 2.4 Future integrations

Any contract that later interacts with ARX does so through the standard ERC-20 interface, like any other address. It has no privilege on this contract. Such contracts are out of scope for this document.

---

## 3. Privileged Flows

The Arxia contract has **exactly one privileged execution flow**: the constructor.

### 3.1 Constructor (one-time, at deployment)

```solidity
constructor(
    address nodeOperatorsAddress,
    address ecosystemAddress,
    address teamVestingAddress,
    address idoAddress,
    address treasuryAddress,
    address seedVestingAddress
) ERC20("Arxia", "ARX") ERC20Permit("Arxia")
```

The constructor:
1. Validates all six addresses are non-zero (`revert ZeroAddress()` otherwise)
2. Mints the fixed amounts set in the contract to each address via OpenZeppelin's internal `_mint()`
3. Verifies `totalSupply() == MAX_SUPPLY` post-mint (`revert TotalSupplyMismatch()` if violated — unreachable by construction)
4. Initializes the ERC20Permit EIP-712 domain separator

After the constructor returns, **no privileged operation exists**. Every subsequent state change is initiated by a holder operating on their own balance/allowance, with no admin capable of intervening.

### 3.2 No post-deployment privileges

The contract has no:
- `Ownable` / `owner()` (calling reverts with "function selector not found")
- `AccessControl` / role-based gating
- `setX(...)` setters of any kind
- `pause()` / `unpause()`
- Public/external `mint(...)` (only internal `_mint`, called only in constructor)
- Upgradeability mechanism (no proxy, no delegate, immutable bytecode)
- Emergency or recovery functions

---

## 4. Failure Cases — Expected Reverts (By Design)

### 4.1 Constructor

| Trigger | Revert |
|---|---|
| Any of the six addresses is `address(0)` | `ZeroAddress()` |
| Post-mint `totalSupply()` ≠ `MAX_SUPPLY` | `TotalSupplyMismatch()` (defensive, mathematically unreachable) |

### 4.2 `transfer(address to, uint256 amount)` (OZ ERC20)

| Trigger | Revert |
|---|---|
| `to == address(0)` | `ERC20InvalidReceiver(0)` |
| `amount > balanceOf(msg.sender)` | `ERC20InsufficientBalance(sender, balance, needed)` |

### 4.3 `transferFrom(address from, address to, uint256 amount)`

| Trigger | Revert |
|---|---|
| `to == address(0)` | `ERC20InvalidReceiver(0)` |
| `from == address(0)` | `ERC20InvalidSender(0)` |
| `amount > balanceOf(from)` | `ERC20InsufficientBalance(from, balance, needed)` |
| `amount > allowance(from, msg.sender)` | `ERC20InsufficientAllowance(spender, allowance, needed)` |

### 4.4 `approve(address spender, uint256 amount)`

| Trigger | Revert |
|---|---|
| `spender == address(0)` | `ERC20InvalidSpender(0)` |

### 4.5 `burn(uint256 amount)` (OZ ERC20Burnable)

| Trigger | Revert |
|---|---|
| `amount > balanceOf(msg.sender)` | `ERC20InsufficientBalance(sender, balance, needed)` |

### 4.6 `burnFrom(address account, uint256 amount)`

| Trigger | Revert |
|---|---|
| `account == address(0)` | `ERC20InvalidSender(0)` |
| `amount > allowance(account, msg.sender)` | `ERC20InsufficientAllowance(spender, allowance, needed)` |
| `amount > balanceOf(account)` | `ERC20InsufficientBalance(account, balance, needed)` |

### 4.7 `permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)`

| Trigger | Revert |
|---|---|
| `block.timestamp > deadline` | `ERC2612ExpiredSignature(deadline)` |
| Signature does not recover to `owner` (invalid sig, wrong nonce, replay) | `ERC2612InvalidSigner(recovered, owner)` |

---

## 5. Failure Cases — Unexpected (None Identified)

After Halmos symbolic execution, Foundry invariant testing, Slither analysis, and on-chain testing on the test network, **no unexpected failure cases were identified**.

The following theoretical failure modes are **proven impossible by construction**:

| Theoretical failure | Why impossible |
|---|---|
| `TotalSupplyMismatch` revert in constructor | The six constructor mint constants in `contracts/Arxia.sol` sum to exactly `MAX_SUPPLY`. Mathematically unreachable. Branch retained as a defensive guard against future refactoring. |
| Sum-of-balances ≠ totalSupply | Inherited from OZ ERC20 standard correctness, additionally enforced by Halmos `check_TotalSupplyAtDeploy` and the Foundry invariant test (`invariant_TotalSupplyNeverExceedsMaxSupply`). |
| Reentrancy attack | Zero external calls in any code path. `_update`, `_mint`, `_burn`, `_approve`, and `permit` all manipulate storage directly without invoking external contracts. |
| Integer overflow/underflow | Solidity 0.8.34 checked arithmetic enabled by default. No `unchecked { ... }` blocks in custom code. |
| Unexpected mint post-constructor | `_mint` is `internal` and called exclusively from the constructor. No public/external function exposes it. |

---

## 6. Invariants (Proven by Halmos Symbolic Execution)

The following invariants are **mathematically proven** by Halmos (Z3 SMT solver) over the entire input space — not just sampled by fuzzing. See [`audit/halmos-report.txt`](./audit/halmos-report.txt) and [`test/ArxiaHalmos.t.sol`](./test/ArxiaHalmos.t.sol).

1. **Deploy-state supply**
   `totalSupply() == MAX_SUPPLY` immediately after constructor execution.

2. **Supply boundedness (transfer)**
   After any `transfer(to, amount)` from the deploy state: `totalSupply() <= MAX_SUPPLY`.

3. **Supply boundedness (burn)**
   After any `burn(amount)` from the deploy state: `totalSupply() <= MAX_SUPPLY`.

4. **Supply monotonicity (transfer never increases supply)**
   For any symbolic `(to, amount)`: `totalSupply()` after `transfer` ≤ `totalSupply()` before.

5. **Supply monotonicity (burn strictly decreases supply when amount > 0)**
   For any symbolic `amount ≤ balance`: `totalSupply()` after `burn` = `totalSupply()` before − `amount`.

6. **Transfer exactness (no fee, no rounding)**
   For any valid `(to, amount)`:
   - `balanceOf(sender)` decreases by exactly `amount`
   - `balanceOf(to)` increases by exactly `amount`
   - `totalSupply` is preserved

7. **Approve exactness**
   For any `(spender, value)` where `spender ≠ 0`: `allowance(caller, spender) == value` after the call.

8. **No path to mint**
   No public function on the contract can grow `totalSupply` beyond its previous value. Combined with invariant #1, this gives an inductive proof: `totalSupply ≤ MAX_SUPPLY` is preserved through every possible call sequence.

The Foundry invariant test `invariant_TotalSupplyNeverExceedsMaxSupply` additionally runs 1,000 runs of depth 100 (100,000 calls) without ever violating this property.

---

## 7. Attack Surface Analysis

| Surface | Coverage | Risk Assessment |
|---|---|---|
| **External calls from this contract** | **None.** No `call`, `delegatecall`, `transfer` (ETH), or `send` to external addresses in any code path. | Zero reentrancy surface. |
| **Storage writes** | Confined to inherited OZ slots: `_balances`, `_allowances`, `_totalSupply` (ERC20); `_nonces` (Nonces); EIP-712 domain cache (ERC20Permit). No custom storage variables grant privilege. | No storage-collision (no proxy). |
| **Access control** | None implemented. `owner()` does not exist; calls revert with selector-not-found. | Zero admin-abuse surface. |
| **Upgradeability** | None. Immutable bytecode. No proxy, no UUPS, no Beacon, no `delegatecall`. | Zero upgrade-attack surface. |
| **Cross-contract dependencies** | None at runtime. The contract depends only on OZ libraries inlined at compile time. | Composability attacks via external contract not possible. |
| **Signature verification** | EIP-2612 `permit` uses `ECDSA.recover` (OZ-audited) with EIP-712 typed-data hashing. Domain separator includes chain ID and contract address. | Cross-chain and cross-contract replay both prevented. |
| **Gas griefing** | Constant-time operations; no unbounded loops; no SSTORE patterns sensitive to gas spikes. | Not applicable. |
| **MEV / front-running** | Permit signatures are publicly observable in the mempool; any party can submit. The resulting state is identical regardless of submitter. | Not a security issue (by EIP-2612 design). |

---

## 8. Known Limitations (Acknowledged)

### 8.1 Permit signature front-running (by design)

EIP-2612 `permit()` signatures placed in the mempool can be submitted by any third party. **This is not a vulnerability**: the resulting allowance is identical regardless of submitter. Front-ends generating permits should use **short deadlines** (recommended: `block.timestamp + 1 hour`) to limit the window in which a stale signature could be submitted later.

### 8.2 ERC-20 approve race condition (by inheritance)

The classic ERC-20 approve race condition is inherited from the standard. If Alice approves Bob for X tokens, then later approves Bob for Y tokens, Bob can race between the two transactions and consume both X + Y. **Mitigation**: front-ends should set allowance to 0 before changing it, or prefer `permit()` (which sets a fresh allowance per signature).

### 8.3 Tokens sent to the contract are unrecoverable

If a user accidentally sends ARX or any other ERC-20 to the `Arxia` contract address (e.g., via a confused front-end), the tokens are **permanently locked**. There is **no recovery function** by design — adding one would itself be a privileged operation contradicting the "zero admin surface" design. Holders must verify recipient addresses before transferring.

### 8.4 Branch coverage 85.7% (not 100%)

`forge coverage` reports 100% line coverage and 100% function coverage on `contracts/Arxia.sol`, with 85.7% branch coverage (6/7 branches). The single uncovered branch is the constructor's `revert TotalSupplyMismatch()`, which is mathematically unreachable (see §5). Auditors should treat this as equivalent to 100% for security purposes; the branch is retained as a defensive guard against future code modifications.

---

## 9. Out of Scope

This threat model covers only `contracts/Arxia.sol`. The following are deliberately excluded:

| Item | Reason |
|---|---|
| **OpenZeppelin Contracts v5.0.2** | Externally audited (OpenZeppelin security team, Trail of Bits, Certora, ConsenSys Diligence) |
| **Addresses set at construction** | External wallets or contracts, not part of this repository |
| **Any contract that later integrates with ARX** | Separate code, out of scope for this document |
| **Websites, DNS and other off-chain infrastructure** | Operational; covered by the SECURITY.md disclosure process |

---

## 10. Auditor Quick Start

### 10.1 Code to audit

- **`contracts/Arxia.sol`** — ~120 lines of custom code (excluding NatSpec and OZ imports)
- Inherits `ERC20`, `ERC20Burnable`, `ERC20Permit` from OpenZeppelin v5.0.2 (audited externally)
- No other custom contracts in scope

### 10.2 Reproducing all checks locally

```bash
# Clone and install dependencies
git clone <repo-url> arxia-token
cd arxia-token
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2
forge install foundry-rs/forge-std

# Build (deterministic)
forge build

# Run all Foundry tests
forge test --gas-report
# Expected: 43 tests passed, 0 failed (fuzz and invariant tests included)

# Coverage
forge coverage --report summary
# Expected: 100% lines + 100% functions on contracts/Arxia.sol
# (85.7% branches — see §8.4)

# Static analysis
slither . --config-file .slither.config.json
# Expected: 0 findings (101 detectors, 21 contracts including OZ)

# Symbolic execution
pip install halmos
halmos --contract ArxiaHalmosTest
# Expected: 8/8 invariants proven
```

### 10.3 Verifying the deployed bytecode

The reference build SHA256 is `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193`. This hash is **stable across compiler versions** 0.8.27 and 0.8.34 because:
- `bytecode_hash = "none"` strips compiler metadata
- `cbor_metadata = false` strips CBOR-encoded metadata
- The contract uses no language features that changed between these versions

```bash
# Local build → extract deployedBytecode → SHA256
forge build
# Compare with on-chain bytecode after deploy:
cast code <DEPLOYED_ADDRESS> --rpc-url <RPC_URL>
```

### 10.4 Test network reference deployment

A test network deployment validates the full pipeline end to end. The contract address, the network, the explorer verification and the transaction hashes of the on-chain tests (transfer, burn, approve, transferFrom, permit, all passing) are recorded in [audit/sepolia-deployment.md](./audit/sepolia-deployment.md) and [audit/sepolia-onchain-tests.md](./audit/sepolia-onchain-tests.md).

### 10.5 Focus areas suggested for auditor scrutiny

1. **Constructor invariant arithmetic**: confirm the six constructor mint constants sum to exactly `MAX_SUPPLY`. Modifying any constant requires updating the sum or the constructor will revert with `TotalSupplyMismatch()`.
2. **No admin surface**: invoke `owner()`, `mint(...)`, `pause(...)`, any `setX(...)` on the deployed contract — all should revert with "function selector not found".
3. **Permit replay resistance**: confirm that a permit signature for nonce N cannot be re-submitted after the nonce has incremented to N+1.
4. **Permit deadline enforcement**: confirm `permit` with `deadline < block.timestamp` reverts with `ERC2612ExpiredSignature`.
5. **Transfer/burn exactness**: confirm there is no scenario where balance changes differ from the requested amount (no fees, no rounding, no transfer hooks).
6. **EIP-712 domain separator**: confirm that the domain separator includes the chain ID and contract address, preventing cross-chain and cross-contract replay.

### 10.6 Contact for clarifications

Email: `arxia.network@proton.me`

For audit-related findings or disputes, please reference this document and any associated transaction hashes from the test network deployment.

---

**End of threat model.**
