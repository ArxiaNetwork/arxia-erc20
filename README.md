# Arxia (ARX) ERC-20 token contract

Source, tests and security records for the ARX ERC-20 token contract, version 1.0.0.

Arxia is an offline settlement layer: transactions are created, signed and propagated over long range radio with no internet, and the result anchors to an existing chain when a connection returns. The protocol code is at https://github.com/ArxiaNetwork/Arxia.

## Status

- The token contract exists on a test network only. No token is live, there are no holders and there is no market. Dated deployment and analysis records are indexed in [audit/README.md](audit/README.md).
- Version 1.0.0 reflects an earlier design.
- This contract does not anchor or settle anything. The settlement layer is a direction we have committed to, not code that exists today. We will show it when it runs.

## Audit

ERC-20 token contract audited by SolidProof, zero findings. The protocol, bridge, wallet and embedded code have not been audited yet.

Team KYC verified at SolidProof Gold Tier.

Automated analysis kept in this repository:

| Tool | Type | Result | Record |
|---|---|---|---|
| Slither | Static analysis, 101 detectors | 0 findings | [audit/slither-report.txt](audit/slither-report.txt) |
| Halmos | Symbolic execution | 8 of 8 invariants proven | [audit/halmos-report.txt](audit/halmos-report.txt) |
| Aderyn | Static analysis | Configured in CI, no result recorded here | [.github/workflows/aderyn.yml](.github/workflows/aderyn.yml) |

## Contract properties

| Property | Value |
|---|---|
| Name | Arxia |
| Symbol | ARX |
| Decimals | 6 |
| Supply | Minted once at construction (`MAX_SUPPLY`); no mint function; holders can burn their own tokens |
| Compiler | Solidity 0.8.34 (pinned) |
| OpenZeppelin | v5.0.2 |
| License | MIT |

## Design: zero admin surface

After deployment the contract has no `owner()` function, no mint, pause, blacklist, fee or proxy, no setter of any kind, no upgrade path and no address with any privilege. Any contract that later interacts with ARX uses standard `transferFrom` and needs no privilege on the token, so none is granted.

Absent by design (see `contracts/Arxia.sol` and the negative tests in `test/Arxia.t.sol`):

- mint after the constructor
- pause and unpause
- blacklist, freeze, seize
- transfer fees (`transfer(X)` delivers exactly `X`)
- reflection, anti-whale, max-tx, max-wallet
- proxy and upgradeability
- ERC20Votes and delegation
- ERC20FlashMint
- owner, admin role or privileged address

## Source comments and names

The comments in `contracts/Arxia.sol` and in its flattened copy `audit/Arxia.flat.sol` are kept unchanged, so that the source stays identical to the contract verified on the test network explorer. Where they, the constructor parameter names, the test names, the deploy script or the environment template (`.env.example`) describe deployment plans, a bridge, distribution plans, governance tooling, a specific network or an earlier contact address, they reflect the earlier design and are superseded by this README. The contact address is arxia.network@proton.me.

## Build and test

Requires [Foundry](https://book.getfoundry.sh/) and [Slither](https://github.com/crytic/slither).

```bash
git clone --recurse-submodules https://github.com/ArxiaNetwork/arxia-erc20
cd arxia-erc20

forge build
forge test -vvv
forge coverage --report summary
slither . --config-file .slither.config.json
FOUNDRY_PROFILE=ci forge test
```

## Deployment

The test network deployment procedure and its pre-flight checklist are in [DEPLOYMENT.md](DEPLOYMENT.md).

## Branch coverage justification

`forge coverage` reports 100% line and function coverage on `contracts/Arxia.sol` and 85.7% branch coverage. The one uncovered branch is the constructor guard `if (totalSupply() != MAX_SUPPLY) revert TotalSupplyMismatch();`. It cannot be reached because the six constructor mint constants in the contract sum exactly to `MAX_SUPPLY`; it is kept as a guard against future edits. `check_TotalSupplyAtDeploy` in `test/ArxiaHalmos.t.sol` proves that total supply equals `MAX_SUPPLY` after the constructor.

## Security

Report vulnerabilities to arxia.network@proton.me. Do not open public issues for security matters. See [SECURITY.md](SECURITY.md) and [THREAT-MODEL.md](THREAT-MODEL.md).

EIP-2612 permit signatures can be submitted by anyone who sees them. This is not a vulnerability: the allowance is the same whoever submits it. Front ends should use short deadlines.

## Links

- Website: https://arxia.network
- Protocol: https://github.com/ArxiaNetwork/Arxia
- X: https://x.com/ArxiaNetwork
- Contact: arxia.network@proton.me

## License

MIT, see [LICENSE](LICENSE).
