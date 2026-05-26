# Arxia (ARX) — Base Sepolia Testnet Deployment Record

**Date**: 2026-05-23
**Status**: Deployed, verified, post-deploy checks passed
**Purpose**: End-to-end validation of deploy pipeline before Base mainnet submission to InterFi Network

---

## Current deployment (Solc 0.8.34)

| Field | Value |
|---|---|
| **Contract address** | `0x8c2fCd0808Fab8f15C103b1D137209b5d6F0170C` |
| **Network** | Base Sepolia (chainId 84532) |
| **Block** | 41,938,870 |
| **Deployer** | `0xC7B37D8ef39a1F2B3A6fc21EE3f49D66584B0a90` |
| **Gas used** | 1,497,262 |
| **Gas price** | 0.011 gwei |
| **Total cost** | ~0.0000165 ETH (Sepolia) |
| **Compiler** | Solidity 0.8.34 (pinned — fixes SOL-2025-1 LostStorageArrayWriteOnSlotOverflow) |
| **Optimizer runs** | 200 |
| **EVM version** | osaka (default for 0.8.34) |
| **Bytecode SHA256** | `d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193` |

### Basescan links

- Contract: https://sepolia.basescan.org/address/0x8c2fcd0808fab8f15c103b1d137209b5d6f0170c
- Verified source: https://sepolia.basescan.org/address/0x8c2fcd0808fab8f15c103b1d137209b5d6f0170c#code
- Read functions: https://sepolia.basescan.org/address/0x8c2fcd0808fab8f15c103b1d137209b5d6f0170c#readContract

---

## Previous deployment (Solc 0.8.27) — superseded

A first deployment was made on 2026-05-23 at block 41,938,611 with compiler 0.8.27 (address `0x922776D3f40ebAE19A50238840d901D2c2db9C9c`). It was superseded after Remix Analyzer flagged that 0.8.27 contains the SOL-2025-1 bug (`LostStorageArrayWriteOnSlotOverflow`, fixed in 0.8.32). The bug is **structurally impossible to trigger in our contract** (no storage arrays, no inline assembly), but the compiler upgrade eliminates the informational warning for audit cleanliness.

**Notable**: the bytecode SHA256 is **identical between 0.8.27 and 0.8.34 builds** (`d2a936d316f312da169526c05ac5ee81569a957a674fb603672eee4504bac193`). This proves:
- Our contract uses no language features that changed between these versions
- `bytecode_hash = "none"` + `cbor_metadata = false` properly strip compiler metadata
- Build is fully reproducible across compiler versions

---

## Verification status

- [OK] Source code submitted to Basescan
- [OK] Basescan response: `Pass - Verified`
- [OK] Constructor args correctly encoded
- [OK] Bytecode matches local build (SHA256 stable across compiler versions)

## Post-deploy verification

### Metadata
- `name()` → `"Arxia"` [OK]
- `symbol()` → `"ARX"` [OK]
- `decimals()` → `6` [OK]
- `VERSION()` → `"1.0.0"` [OK]
- `MAX_SUPPLY()` → `1000000000000000` (10^15) [OK]
- `totalSupply()` → `1000000000000000` (matches MAX_SUPPLY) [OK]

### Zero admin surface verified
- `owner()` → **`execution reverted` (function selector not found)** [OK]
  - Confirms no Ownable inheritance, no owner ever existed on-chain

### Allocation balances (all exact)

| Recipient      | Address                                      | Allocated                                | Status |
|----------------|----------------------------------------------|------------------------------------------|--------|
| Node Operators | `0x2740989460d49880b82b9551fc32F7813c1d63E8` | 250,000,000,000,000 (250M with 6 dec)    | [OK]   |
| Ecosystem      | `0x89E7B0c6Be4Dd3fb1D3946D68F0f4B05c7A94468` | 200,000,000,000,000 (200M)               | [OK]   |
| Team Vesting   | `0x0093B8e1cc4b4BF726ea3B15d6E508FFedf278Bd` | 150,000,000,000,000 (150M)               | [OK]   |
| IDO            | `0x26eb41E86F02C5B9AB87e2d4d70DE68b25cd2B3d` | 150,000,000,000,000 (150M)               | [OK]   |
| Treasury       | `0xec06BC80924e1C2C18664A4E607429bE85E4d207` | 130,000,000,000,000 (130M)               | [OK]   |
| Seed Vesting   | `0x0Dc94804Ca48E445e27bcb43cAc04407DE222A28` | 120,000,000,000,000 (120M)               | [OK]   |
| **Sum**        | —                                            | **1,000,000,000,000,000**                | **= MAX_SUPPLY** |

## Verification commands (reproducible)

```bash
export CONTRACT=0x8c2fCd0808Fab8f15C103b1D137209b5d6F0170C
export RPC=https://sepolia.base.org

cast call $CONTRACT "name()(string)"        --rpc-url $RPC
cast call $CONTRACT "symbol()(string)"      --rpc-url $RPC
cast call $CONTRACT "decimals()(uint8)"     --rpc-url $RPC
cast call $CONTRACT "totalSupply()(uint256)" --rpc-url $RPC
cast call $CONTRACT "MAX_SUPPLY()(uint256)" --rpc-url $RPC
cast call $CONTRACT "VERSION()(string)"     --rpc-url $RPC

# Negative check — must revert
cast call $CONTRACT "owner()(address)" --rpc-url $RPC
```

## Conclusion

The Sepolia deployment **validates the full pipeline end-to-end** with the production compiler version 0.8.34:
- Foundry script execution
- Env var loading
- Constructor allocation logic
- Automatic Basescan source verification
- All public state matches expected post-deploy
- No compiler-known-bug informational warnings on the audit submission
- Reproducible build verified across two compiler versions

The same script (`script/Deploy.s.sol`) is ready for Base mainnet deployment with mainnet addresses (multisigs + Sablier streams) once the mainnet pre-flight checklist (DEPLOYMENT.md) is satisfied.
