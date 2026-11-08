# Security records

Records for version 1.0.0 of the ARX token contract.

ERC-20 token contract audited by SolidProof, zero findings. The protocol, bridge, wallet and embedded code have not been audited yet.

The dated records below are kept as evidence. Statements in them about future deployments, an audit submission or the earlier design are superseded by the [README](../README.md).

| File | Content |
|---|---|
| [sepolia-deployment.md](sepolia-deployment.md) | Test network deployment, 2026-05-23: address, explorer verification, post-deploy checks |
| [sepolia-onchain-tests.md](sepolia-onchain-tests.md) | Five functional transactions on that deployment, 2026-05-23 |
| [slither-report.txt](slither-report.txt) | Slither static analysis, 0 findings |
| [halmos-report.txt](halmos-report.txt) | Halmos symbolic execution, 8 of 8 invariants proven |
| [remix-static-analysis.md](remix-static-analysis.md) | Remix Analyzer and Solhint run, 0 findings located in `contracts/Arxia.sol` |
| [aderyn-notes.md](aderyn-notes.md) | Notes on running Aderyn, which is configured in CI |
| [Arxia.flat.sol](Arxia.flat.sol) | Flattened source generated from `contracts/Arxia.sol`, not the canonical source |
