# Deployment Guide — Arxia (ARX) ERC-20

Step-by-step deployment process for the Arxia ERC-20 contract on Base mainnet (chainId 8453) and Base Sepolia testnet (chainId 84532).

---

## Pre-deployment checklist

**Do NOT proceed to mainnet deployment unless every box below is ticked.**

### Code & build integrity

- [ ] Repository is clean: `git status` shows no uncommitted changes
- [ ] On the exact commit submitted to the auditor: `git log -1 --oneline`
- [ ] `forge build` succeeds with **zero warnings**
- [ ] `forge test` shows **all tests passing** (target: 45+ tests)
- [ ] `forge coverage --report summary` shows **100% lines + 100% functions** on `contracts/Arxia.sol`
- [ ] `slither . --config-file .slither.config.json` reports **zero findings ≥ Low**
- [ ] `aderyn .` reports **zero findings** (or only acknowledged informationals)
- [ ] `halmos` proves all invariants in `test/ArxiaHalmos.t.sol`
- [ ] Two consecutive `forge build` produce identical bytecode (deterministic):
      `sha256sum out/Arxia.sol/Arxia.json` matches across runs
- [ ] **Reference bytecode SHA256**: `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193`

### Configuration locks

- [ ] `foundry.toml`: `solc_version = "0.8.34"` (pinned)
- [ ] `foundry.toml`: `auto_detect_solc = false`
- [ ] `foundry.toml`: `bytecode_hash = "none"` (deterministic, audit-reproducible)
- [ ] `foundry.toml`: `cbor_metadata = false`
- [ ] `foundry.toml`: `optimizer = true`, `optimizer_runs = 200`
- [ ] `foundry.toml`: `via_ir = false` (auditability — IR generates non-1:1 bytecode mapping)

### Audit completion

- [ ] **InterFi audit report** received with zero Critical/High/Medium findings
- [ ] Audit report PDF stored in `audit/interfi-arx-v1.0.0.pdf` and committed
- [ ] Audit report linked from `SECURITY.md` § "Past security reviews"

### Operational readiness

- [ ] All 6 allocation addresses are **deployed multisigs or vesting contracts**:
  - [ ] `NODE_OPERATORS_ADDRESS` — Safe multisig, ≥ 3-of-5 signers
  - [ ] `ECOSYSTEM_ADDRESS` — Safe multisig, ≥ 3-of-5 signers
  - [ ] `TEAM_VESTING_ADDRESS` — Sablier V2 LockupLinear stream, vesting per agreed schedule
  - [ ] `IDO_ADDRESS` — Safe multisig, ≥ 2-of-3 signers (funds PinkSale presale)
  - [ ] `TREASURY_ADDRESS` — Safe multisig, ≥ 3-of-5 signers
  - [ ] `SEED_VESTING_ADDRESS` — Sablier V2 LockupLinear stream
- [ ] Each multisig signer uses a **hardware wallet** (Ledger / Trezor / GridPlus)
- [ ] Each multisig signer's hardware wallet has been **tested with a small transaction** on Base Sepolia
- [ ] Multisig configurations have been **simulated** (transaction proposal flow tested)
- [ ] Deployer EOA has **sufficient ETH on Base** for deployment + verification (allow ~0.005 ETH at typical gas prices)
- [ ] **Sepolia deploy executed and verified** on `sepolia.basescan.org` from this exact commit
- [ ] Sepolia bytecode SHA256 matches local build SHA256

### Communication readiness

- [ ] Arxia website at `arxia.one` is live with /token page
- [ ] Social media accounts (X, Telegram, Discord) are ready to publish the deployed address
- [ ] PinkSale presale page is configured (but not yet finalized)
- [ ] Anti-phishing communication plan: official channels prepared to publish the verified contract address immediately post-deploy

---

## Deployment process

### Step 1 — Environment setup

```bash
# From the repository root
cd ./

# Verify tooling
forge --version   # expect 1.7.x
cast --version
```

### Step 2 — Load environment

```bash
# Confirm .env is filled with REAL mainnet addresses (not Sepolia)
set -a; source .env; set +a

# Sanity-check each variable
for v in PRIVATE_KEY \
         NODE_OPERATORS_ADDRESS \
         ECOSYSTEM_ADDRESS \
         TEAM_VESTING_ADDRESS \
         IDO_ADDRESS \
         TREASURY_ADDRESS \
         SEED_VESTING_ADDRESS \
         BASE_RPC_URL \
         BASESCAN_API_KEY; do
    val="${!v}"
    if [ -z "$val" ]; then
        echo "MISSING: $v"
    elif [ "$v" = "PRIVATE_KEY" ]; then
        echo "$v: SET (hidden)"
    else
        echo "$v: $val"
    fi
done
```

### Step 3 — Pre-deploy dry run (no broadcast)

```bash
forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$BASE_RPC_URL"
```

**Verify in output**:
- Chain ID is **8453** (Base mainnet) — abort if you see anything else
- All 6 allocation addresses match the multisigs you expect
- Gas estimate is reasonable (~1.2M gas for the constructor)
- "OK invariant: totalSupply == MAX_SUPPLY" appears in logs

### Step 4 — Final confirmation

Read every variable one more time. Specifically:

- Confirm `NODE_OPERATORS_ADDRESS` ends in the correct multisig suffix
- Confirm Sablier stream addresses for team & seed are the **stream contract addresses**, NOT the team's EOA
- Confirm IDO multisig is configured for PinkSale interaction

**If any address is wrong, stop. A misallocated 250M ARX cannot be recovered.**

### Step 5 — Deploy + verify

```bash
forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$BASE_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --verify \
    --etherscan-api-key "$BASESCAN_API_KEY" \
    --slow
```

**Expected output**:
- Transaction hash printed
- "Contract Address: 0x..." printed
- Basescan verification confirmation: "Contract source code verified"

**Record immediately**:
- Deployment transaction hash
- Deployed contract address
- Block number at deployment

### Step 6 — Post-deploy verification

```bash
export DEPLOYED="0x..."   # paste from Step 5 output
EXPECTED_HASH="d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193"

# Bytecode integrity — must match local build SHA256.
# Note: on-chain bytecode is the deployed runtime, not the JSON's deployedBytecode field;
# computing apples-to-apples requires matching format. See SECURITY.md § "Verification".
cast code "$DEPLOYED" --rpc-url "$BASE_RPC_URL" > deployed-bytecode.hex
ONCHAIN_HASH=$(sha256sum deployed-bytecode.hex | awk '{print $1}')
echo "expected: $EXPECTED_HASH"
echo "on-chain: $ONCHAIN_HASH"

# Functional verification
cast call "$DEPLOYED" "name()(string)"         --rpc-url "$BASE_RPC_URL"
cast call "$DEPLOYED" "symbol()(string)"       --rpc-url "$BASE_RPC_URL"
cast call "$DEPLOYED" "decimals()(uint8)"      --rpc-url "$BASE_RPC_URL"
cast call "$DEPLOYED" "totalSupply()(uint256)" --rpc-url "$BASE_RPC_URL"
cast call "$DEPLOYED" "MAX_SUPPLY()(uint256)"  --rpc-url "$BASE_RPC_URL"
cast call "$DEPLOYED" "VERSION()(string)"      --rpc-url "$BASE_RPC_URL"

# CRITICAL — owner() must NOT exist on this contract
cast call "$DEPLOYED" "owner()(address)" --rpc-url "$BASE_RPC_URL"
# Expected: revert "function selector not found"
# If this RETURNS an address — the WRONG contract was deployed. ABORT.

# Allocation verification — all 6 must hold their expected amounts
declare -A ALLOCATIONS=(
    ["$NODE_OPERATORS_ADDRESS"]="250000000000000"   # 250M with 6 decimals
    ["$ECOSYSTEM_ADDRESS"]="200000000000000"
    ["$TEAM_VESTING_ADDRESS"]="150000000000000"
    ["$IDO_ADDRESS"]="150000000000000"
    ["$TREASURY_ADDRESS"]="130000000000000"
    ["$SEED_VESTING_ADDRESS"]="120000000000000"
)
for addr in "${!ALLOCATIONS[@]}"; do
    actual=$(cast call "$DEPLOYED" "balanceOf(address)(uint256)" "$addr" --rpc-url "$BASE_RPC_URL")
    expected="${ALLOCATIONS[$addr]}"
    if echo "$actual" | grep -q "$expected"; then
        echo "OK   $addr: $actual"
    else
        echo "FAIL $addr: expected $expected, got $actual"
    fi
done
```

### Step 7 — Public announcement

Once all verifications pass:

1. **Update README** with deployed contract address + deployment tx hash + block number
2. **Update arxia.one/token** page with the contract address
3. **Update SECURITY.md** § "Past security reviews" with audit report links
4. **Pin the verified contract** on Basescan: add a comment with brand info
5. **Publish on social channels** with the verified Basescan URL — encourage holders to verify the URL before any transaction
6. **Notify InterFi** of the live deployment so the audit record can be linked to the on-chain contract address

### Step 8 — Configure Basescan token info

Submit a token update request to Basescan with:
- Token name: `Arxia`
- Token symbol: `ARX`
- Project website: `https://arxia.one`
- Logo: 256x256 PNG with transparent background
- Description: short tagline
- Social links: X, Telegram, GitHub (this repo)
- Audit report link: InterFi public report URL

---

## Rollback procedure

**There is no rollback.** Deployment is irreversible. If a critical issue is discovered post-deployment:

1. **Communicate immediately** via all channels — do not try to hide the issue
2. **Pause off-chain integrations** (PinkSale, exchanges) if any are aware
3. **Open coordinated disclosure** with the security reporter
4. **Plan migration** to a new contract — this requires:
   - Deploying a fixed contract (with new bytecode, new audit)
   - Announcing a snapshot block on the broken contract
   - Distributing the new ARX to holders based on the snapshot
   - Documenting the migration in `MIGRATION.md`
5. **Bridge migration** to the new contract becomes the canonical state

This is a heavy process. **The pre-deployment checklist exists precisely to avoid it.**

---

## Multisig setup template

For each multisig allocation address (5 of the 6 — vesting streams are exempt):

### Safe multisig creation

1. Go to https://app.safe.global on Base mainnet
2. "Create new Safe" → Network: Base
3. Owners: add at least 5 distinct addresses (hardware wallets)
4. Threshold: 3 (3-of-5 signing required)
5. Deploy Safe (costs ~0.0005 ETH on Base)
6. **Record Safe address** — this is the ALLOCATION_ADDRESS for that bucket

### Per-signer setup

- Hardware wallet (Ledger/Trezor/GridPlus)
- Browser extension wallet (Rabby/Frame, NOT MetaMask Mobile for multisig)
- WalletConnect to Safe app
- Test signing a tiny transaction (0.0001 ETH transfer) before serving as a signer for ARX allocations

### Recovery considerations

- At least 1 signer should be a hardware wallet stored in a different jurisdiction (geographic distribution)
- Signers should NOT share infrastructure (different ISPs, different machines)
- Encrypted backup of seed phrases stored separately

---

## Vesting stream setup (Sablier V2)

For `TEAM_VESTING_ADDRESS` and `SEED_VESTING_ADDRESS`:

1. Deploy a Sablier V2 LockupLinear stream on Base via https://app.sablier.com
2. **Sender**: a Safe multisig that controls vesting parameters
3. **Recipient**: the team member's address or NFT (Sablier issues stream NFTs)
4. **Asset**: leave blank initially — will be funded with ARX after token deploy
5. **Schedule**:
   - Team: 24 months linear with 6-month cliff (or per agreed terms)
   - Seed: 18 months linear with 3-month cliff
6. **Stream address**: this is the contract address that holds the locked ARX — use as ALLOCATION_ADDRESS

After token deployment, transfer the corresponding ARX to the stream address. Sablier will release the locked tokens to the recipient over the schedule.

---

## InterFi audit submission

After deployment + verification on Basescan, submit to InterFi:

1. Visit https://www.interfi.dev (or InterFi's current submission portal)
2. Submit via the standard form. KYC is optional for our use case.
3. Provide:
   - Deployed contract address: `0x...`
   - Chain: Base (8453)
   - GitHub repository URL (this repository)
   - Commit hash matching the deployed bytecode
   - Bytecode SHA256: `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193`
   - Prior reviews: Slither + Aderyn + Halmos reports attached
4. Expected turnaround: per InterFi's stated SLA at submission time
5. Once report is received: store in `audit/`, update README + SECURITY.md, share publicly

---

## Reference

- Main contract: `contracts/Arxia.sol`
- Tests: `test/Arxia.t.sol`, `test/ArxiaHalmos.t.sol`
- Deploy script: `script/Deploy.s.sol`
- Foundry config: `foundry.toml`
- Slither config: `.slither.config.json`

**Compiler**: Solidity 0.8.34 (pinned)
**OpenZeppelin**: v5.0.2
**Foundry**: v1.7.1

---

**Last updated**: 2026-05-23
**Document version**: 1.0.0
