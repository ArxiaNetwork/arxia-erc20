# Arxia (ARX) — Pre-Mainnet ERC-20

Fixed-supply, minimalist ERC-20 representation of the future Arxia L1 native token, deployed on **Base mainnet**. Will be bridged 1:1 to native ARX at mainnet launch (M24+).

| Property        | Value                              |
|-----------------|------------------------------------|
| Name            | Arxia                              |
| Symbol          | ARX                                |
| Decimals        | 6                                  |
| Total supply    | 1,000,000,000 ARX (fixed, no mint) |
| Network         | Base mainnet (chainId 8453)        |
| License         | MIT                                |
| Compiler        | Solidity 0.8.34 (pinned)           |
| OpenZeppelin    | v5.x                               |
| Audit           | InterFi Network (submission pending) |
| Contract        | TBD (post-deployment)              |

## Initial allocation

| Recipient                | Amount             | %    |
|--------------------------|--------------------|------|
| Node operators           | 250,000,000        | 25%  |
| Ecosystem grants         | 200,000,000        | 20%  |
| Team (Sablier vesting)   | 150,000,000        | 15%  |
| IDO (PinkSale presale)   | 150,000,000        | 15%  |
| Treasury                 | 130,000,000        | 13%  |
| Seed (Sablier vesting)   | 120,000,000        | 12%  |
| **Total**                | **1,000,000,000**  | 100% |

All six recipients are independent addresses fixed at deployment. There is no mechanism, anywhere, to modify these allocations after deployment.

---

## Design philosophy: "Code is law"

This contract has **zero admin surface**. After deployment:

- No `owner()` function exists
- No mint, no pause, no blacklist, no fees, no proxy
- No setter functions of any kind
- No upgradeability mechanism
- No address has any privilege whatsoever

### Why no Ownable?

We considered an `Ownable`-gated `setBridgeAddress()` for transparency (registering the future L1 bridge contract on-chain). We rejected it because:

1. **The bridge needs no privilege on the token.** It interacts via standard `transferFrom`. Registering its address on-chain grants nothing operational — it would be a purely informational pointer.
2. **Even a one-shot setter with auto-renounce** creates a window between deploy and bridge readiness where automated audit scanners flag "Centralization Risk: Owner exists".
3. **A two-year ownership window** (from deploy to mainnet at M24+) is unacceptable from a holder-trust perspective. Automated audit scanners typically flag any persistent `owner()` as a centralization risk regardless of intent.
4. **Off-chain registration is more flexible.** If bridge V1 needs to be replaced with V2 (bug fix, upgrade), documentation can be updated without contract changes.

**Result:** `owner() == address(0)` from block 1. The contract is structurally immutable.

### Why no Bridge Whitelist?

The L1 bridge address will be published off-chain via:

- This README (updated at M24+ with the deployed bridge contract address)
- Basescan contract comment
- Arxia documentation site (arxia.one/bridge)

The bridge is just an EVM address that holds ARX. It is technically indistinguishable from any other ARX holder. Its "official" status is a social/legal claim, not a technical permission embedded in the token contract.

### Explicit exclusions (verified by tests)

The following functionalities are absent by design and proven absent by `test/Arxia.t.sol`:

- No mint post-constructor (fixed supply)
- No pause / unpause
- No blacklist, freeze, seize
- No transfer fees (`transfer(X)` ⇒ receive exactly `X`)
- No reflection, anti-whale, max-tx, max-wallet
- No proxy / upgradeability
- No ERC20Votes / delegation (governance off-chain via Snapshot)
- No ERC20FlashMint
- No owner, no admin role, no privileged address

---

## Project structure

```
.
├── contracts/Arxia.sol         Main contract
├── test/Arxia.t.sol            Foundry tests (positive + negative + fuzz + invariant)
├── script/Deploy.s.sol         Deployment script
├── foundry.toml                Foundry config (pinned solc 0.8.34, deterministic build)
├── .slither.config.json        Slither config (fails on any Low+ finding)
├── .env.example                Environment variable template
├── .gitignore
├── LICENSE                     MIT
└── README.md                   This file
```

---

## Setup

Requires [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`) and [Slither](https://github.com/crytic/slither).

```bash
# 1. Install Foundry (if not already)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Install Slither (Python)
pip install slither-analyzer

# 3. Clone and install dependencies
git clone <repo-url> arxia-token
cd arxia-token
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
forge install foundry-rs/forge-std --no-commit
```

---

## Build, test, audit

```bash
# Build
forge build

# Tests (with gas report)
forge test --gas-report -vvv

# Coverage (target: 100% on contracts/Arxia.sol)
forge coverage --report summary
forge coverage --report lcov

# Static analysis (must return zero findings ≥ Low)
slither . --config-file .slither.config.json

# CI profile (high-iteration fuzz + invariant)
FOUNDRY_PROFILE=ci forge test
```

---

## Deployment

### Base Sepolia (testnet)

```bash
cp .env.example .env
# Fill in: PRIVATE_KEY, 6 allocation addresses, BASE_SEPOLIA_RPC_URL, BASESCAN_API_KEY

source .env  # bash / zsh

forge script script/Deploy.s.sol:Deploy \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY
```

### Base mainnet — pre-flight checklist

**Do NOT proceed unless every box is checked:**

- [ ] `slither . --config-file .slither.config.json` returns **zero findings ≥ Low**
- [ ] `forge test` shows **100% pass** (all positive, negative, fuzz, invariant tests green)
- [ ] `forge coverage --report summary` shows **100% line + branch coverage** on `contracts/Arxia.sol`
- [ ] Two consecutive `forge build` produce **identical bytecode** (deterministic build):
      `sha256sum out/Arxia.sol/Arxia.json` matches across runs
- [ ] Compiler is **locked**: `foundry.toml` has `solc_version = "0.8.34"` and `auto_detect_solc = false`
- [ ] Metadata is **stripped**: `bytecode_hash = "none"`, `cbor_metadata = false`
- [ ] Sepolia deploy executed and contract **verified** on `sepolia.basescan.org`
- [ ] All 6 allocation addresses are **confirmed multisigs or vesting contracts** (not single-key EOAs)
- [ ] Multisig signers use **hardware wallets**, not browser keys
- [ ] **InterFi audit submitted and report received** with zero Critical/High/Medium findings
- [ ] Audit report PDF stored in `audit/` and linked from this README
- [ ] Deployer EOA has **sufficient ETH** on Base for deployment + verification (~0.005 ETH at typical gas)
- [ ] **Dry-run** the deploy script: `forge script ... --rpc-url $BASE_RPC_URL` (no `--broadcast`) — confirm gas estimate, allocations, deployer

### Base mainnet — deploy command

```bash
forge script script/Deploy.s.sol:Deploy \
    --rpc-url $BASE_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY \
    --slow
```

The `--slow` flag waits for transaction confirmation between sequential txs (here only one, but safe default).

### Post-deploy verification

```bash
export DEPLOYED=0x...  # paste address from script output

# 1. Bytecode integrity — deployed code matches locally compiled artifact
cast code $DEPLOYED --rpc-url $BASE_RPC_URL > deployed.bin
jq -r '.deployedBytecode.object' out/Arxia.sol/Arxia.json | xxd -r -p > local.bin
cmp deployed.bin local.bin && echo "OK bytecode matches"

# 2. Public state matches expectations
cast call $DEPLOYED "name()(string)"         --rpc-url $BASE_RPC_URL
cast call $DEPLOYED "symbol()(string)"       --rpc-url $BASE_RPC_URL
cast call $DEPLOYED "decimals()(uint8)"      --rpc-url $BASE_RPC_URL
cast call $DEPLOYED "totalSupply()(uint256)" --rpc-url $BASE_RPC_URL
cast call $DEPLOYED "MAX_SUPPLY()(uint256)"  --rpc-url $BASE_RPC_URL
cast call $DEPLOYED "VERSION()(string)"      --rpc-url $BASE_RPC_URL

# 3. CRITICAL — confirm NO owner() function exists
cast call $DEPLOYED "owner()(address)" --rpc-url $BASE_RPC_URL
# Expected: Error / execution reverted (function selector not found)
# If this returns an address, ABORT — the wrong contract was deployed.

# 4. All 6 allocations land correctly
for addr in $NODE_OPERATORS_ADDRESS $ECOSYSTEM_ADDRESS $TEAM_VESTING_ADDRESS \
            $IDO_ADDRESS $TREASURY_ADDRESS $SEED_VESTING_ADDRESS; do
    bal=$(cast call $DEPLOYED "balanceOf(address)(uint256)" $addr --rpc-url $BASE_RPC_URL)
    echo "$addr: $bal"
done

# 5. Sum of balances == totalSupply
# (Manual check from above output; sum must equal 1000000000000000)
```

---

## Interacting with ARX

### Standard transfer

```bash
cast send $DEPLOYED "transfer(address,uint256)" $RECIPIENT $AMOUNT \
    --rpc-url $BASE_RPC_URL --private-key $KEY
```

### Burn

```bash
cast send $DEPLOYED "burn(uint256)" $AMOUNT \
    --rpc-url $BASE_RPC_URL --private-key $KEY
```

### Permit (EIP-2612 gasless approval)

Off-chain signing, on-chain submission by anyone. See OpenZeppelin's [ERC20Permit examples](https://docs.openzeppelin.com/contracts/5.x/erc20#ERC20Permit).

**Security note:** `permit()` signatures are technically front-runnable (anyone seeing the signed message in the mempool can submit it first). This is not a vulnerability — the spender receives the same allowance regardless of who submits. Use **short deadlines** (e.g., `block.timestamp + 1 hour`) in your front-end to limit exposure.

---

## Bridge migration (M24+)

When the Arxia L1 mainnet launches, the bridge will be a separately-audited Lock-and-Mint contract. To bridge ARX → native ARX:

1. User sends ARX to the bridge contract address (published below at M24)
2. Bridge contract emits a `Lock` event
3. Off-chain validators mint equivalent native ARX on L1 to the holder's L1 address
4. Locked ARX on Base remains in the bridge contract indefinitely (1:1 backing)

**No action required on this ERC-20 contract for the migration.** It will continue to exist, with the supply locked in the bridge contract representing the canonical L1 native supply.

**Bridge contract address (M24+):** TBD

---

## Security contact

- Email: `arxialayer1@proton.me`

Please report vulnerabilities via encrypted email. Do not open public GitHub issues for security matters.

---

## Branch coverage justification

`forge coverage --report summary` reports **100% line coverage** and **100% function coverage** on `contracts/Arxia.sol`, with **85.7% branch coverage**.

The single uncovered branch is:

```solidity
if (totalSupply() != MAX_SUPPLY) revert TotalSupplyMismatch();
```

This branch is **mathematically unreachable** because the six allocation constants sum to exactly MAX_SUPPLY:

```
_NODE_OPERATORS + _ECOSYSTEM + _TEAM_VESTING + _IDO + _TREASURY + _SEED_VESTING
= 250M + 200M + 150M + 150M + 130M + 120M
= 1,000M
= MAX_SUPPLY
```

The check is kept as a **defensive invariant guard** against future code modifications. Coverage tools cannot detect that the branch is dead code by construction. The Halmos symbolic execution proof in `test/ArxiaHalmos.t.sol` formally verifies that no execution path can hit the `revert TotalSupplyMismatch()`.

The 85.7% figure reflects this single unreachable branch only; the remaining 6/7 reachable branches are fully exercised. Reviewers may verify unreachability via the Halmos proof referenced above.

## Audit history

| Date       | Auditor  | Scope                            | Result                       | Report                            |
|------------|----------|----------------------------------|------------------------------|-----------------------------------|
| TBD        | InterFi  | Full contract                    | submission pending           | `audit/interfi-arx-v1.0.0.pdf` (to be added post-audit) |
| 2026-05-23 | Halmos   | Symbolic invariants              | 8 / 8 proven                 | `audit/halmos-report.txt`         |
| 2026-05-23 | Slither  | Static analysis (101 detectors)  | 0 findings                   | `audit/slither-report.txt`        |
| Pending CI | Aderyn   | Static analysis (63 detectors)   | configured via GitHub Action | `audit/aderyn-notes.md` + `.github/workflows/aderyn.yml` |

---

## License

MIT — see [LICENSE](./LICENSE).
