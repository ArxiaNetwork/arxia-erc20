# Deployment procedure: Arxia (ARX) ERC-20

The token contract exists on a test network only. No token is live, there are no holders and there is no market. Version 1.0.0 reflects an earlier design. This page describes how the test network deployment was made and how anyone can check it.

## Pre-flight checklist

- [ ] Working tree clean, on the intended commit (`git status`, `git log -1 --oneline`)
- [ ] `forge build` succeeds with zero warnings
- [ ] `forge test` passes
- [ ] `forge coverage --report summary` shows 100% lines and 100% functions on `contracts/Arxia.sol`
- [ ] `slither . --config-file .slither.config.json` reports zero findings at Low or above
- [ ] `halmos --contract ArxiaHalmosTest` proves all checks in `test/ArxiaHalmos.t.sol`
- [ ] Two clean builds give the same `out/Arxia.sol/Arxia.json` hash (CI checks this on every push to main)
- [ ] `foundry.toml` still pins `solc_version = "0.8.34"`, `auto_detect_solc = false`, `bytecode_hash = "none"`, `cbor_metadata = false`, `optimizer_runs = 200`, `via_ir = false`
- [ ] All six constructor addresses are non-zero and are the intended ones (a wrong address cannot be corrected after deployment)

## Test network deployment

`.env.example` lists the variables the deploy script and these commands expect. Copy it to `.env`, fill it in, and never commit `.env`.

```bash
set -a; source .env; set +a

# dry run, no broadcast
forge script script/Deploy.s.sol:Deploy --rpc-url "<RPC_URL>"

# deploy and verify
forge script script/Deploy.s.sol:Deploy \
    --rpc-url "<RPC_URL>" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --verify \
    --etherscan-api-key "<EXPLORER_API_KEY>"
```

The script rejects a zero address, deploys the contract, logs every balance and reverts if `totalSupply() != MAX_SUPPLY`.

## Checking a deployment

The record of the test network deployment (address, explorer verification, post-deploy checks) is [audit/sepolia-deployment.md](audit/sepolia-deployment.md). The functional transactions are in [audit/sepolia-onchain-tests.md](audit/sepolia-onchain-tests.md).

Anyone can repeat the read checks:

```bash
cast call <ADDRESS> "name()(string)"         --rpc-url <RPC_URL>
cast call <ADDRESS> "symbol()(string)"       --rpc-url <RPC_URL>
cast call <ADDRESS> "decimals()(uint8)"      --rpc-url <RPC_URL>
cast call <ADDRESS> "totalSupply()(uint256)" --rpc-url <RPC_URL>
cast call <ADDRESS> "MAX_SUPPLY()(uint256)"  --rpc-url <RPC_URL>
cast call <ADDRESS> "VERSION()(string)"      --rpc-url <RPC_URL>

# must revert: the contract has no owner() function
cast call <ADDRESS> "owner()(address)"       --rpc-url <RPC_URL>
```

On the recorded test deployment `totalSupply()` is below `MAX_SUPPLY()` because of the burn recorded in [audit/sepolia-onchain-tests.md](audit/sepolia-onchain-tests.md).

## No rollback

The contract is immutable. A mistake at deployment can only be corrected by deploying a new contract.
