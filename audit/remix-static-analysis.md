# Remix Static Analysis — Arxia (ARX) v1.0.0

**Run date**: 2026-05-23
**Tool**: Remix IDE 2.2.0 Web — Static Analysis plugin
**Analyzers used**: Remix Analyzer (full) + Solhint
**Analyzer skipped**: Slither (not available in Remix Web — requires Remix Desktop or `remixd` daemon; equivalent run locally with 0 findings)
**Compilation target**: Solc 0.8.34 (matches the project's pinned compiler in `foundry.toml`)

---

## Result — 0 genuine findings on Arxia.sol

All findings reported by Remix fall into one of these categories:

| Category | Count | Source | Validity |
|---|---|---|---|
| `INTERNAL ERROR` in Remix Analyzer (Check-effects-interaction, Constant/View/Pure) | 2 | Bug in Remix Analyzer's JavaScript code | Ignore — tool bug, not a finding |
| Inline assembly | ~45 | OpenZeppelin v5 libraries (Math, ECDSA, ShortStrings, MessageHashUtils, StorageSlot, Bytes, Strings, SafeCast) | Out of scope — OZ is externally audited |
| Block timestamp use (Pos 51:12) | 1 | `ERC20Permit.permit()` checking `block.timestamp <= deadline` | By-design EIP-2612 |
| "Infinite gas" for `name`, `symbol`, `transfer`, `burn`, etc. | 12 | Remix Analyzer's gas estimator | **False positive** — `forge test --gas-report` shows bounded costs (transfer ~41k, burn ~30k, deployment 1.15M) |
| For loop over dynamic array | 2 | OpenZeppelin Math / ECDSA | Out of scope — OZ |
| Similar variable names | ~50 | OpenZeppelin (`_name`/`name_`, `bstr`/`str`, `aa`/`xn` in Math.sqrt) | OZ intentional naming convention |
| No return | ~30 | OpenZeppelin interfaces and library functions using assembly to return | OZ standard pattern |
| Data truncated (integer division) | 11 | OpenZeppelin Math library | Intentional OZ math |
| Solhint "explicit visibility" Pos 5:58 | 1 | Obsolete rule (since Solidity 0.7+ constructors don't need explicit visibility) | False positive |

**Total findings actually located in `contracts/Arxia.sol`: 0**

---

## Why so much noise?

Remix Web's "Hide warnings for external libraries" checkbox does **not** reliably filter findings in imported OpenZeppelin code. This is a known Remix Web limitation. The analyzer runs on the full compilation unit (Arxia.sol + all OZ dependencies) and reports everything, regardless of the filter.

For a fair comparison: when Slither was run locally on the same scope (with `filter_paths: "lib"` properly applied), the result was **0 findings on 101 detectors**.

---

## "Infinite gas" — specifically debunked

Remix Analyzer reports the following Arxia functions as having "infinite gas":

```
Arxia.name              → Remix: infinite | Actual: 3,153 gas
Arxia.symbol            → Remix: infinite | Actual: 3,151 gas
Arxia.transfer          → Remix: infinite | Actual: 7,259-51,591 gas (avg 41,764)
Arxia.allowance         → Remix: infinite | Actual: 2,810 gas
Arxia.approve           → Remix: infinite | Actual: 4,857-46,701 gas (avg 24,530)
Arxia.transferFrom      → Remix: infinite | Actual: 10,177-57,641 gas (avg 13,271)
Arxia.burn              → Remix: infinite | Actual: 7,005-33,869 gas (avg 29,694)
Arxia.burnFrom          → Remix: infinite | Actual: 9,834-39,830 gas (avg 10,462)
Arxia.permit            → Remix: infinite | Actual: 26,640-75,437 gas (avg 45,216)
Arxia.DOMAIN_SEPARATOR  → Remix: infinite | Actual: 383 gas
Arxia.VERSION           → Remix: infinite | Actual: 545 gas
```

Source: `forge test --gas-report` (see project root). Remix's gas analyzer is unable to handle inherited functions that use modifiers or overrides; it defaults to "infinite" when it can't statically bound a function. This is a documented limitation of the Remix Analyzer.

---

## Conclusion for audit submission

This Remix run **adds no security signal** beyond what Slither (more comprehensive, 101 vs ~30 detectors) and Halmos (formal proofs on 8 invariants) already provide. It is included in the audit folder for completeness and to demonstrate that Remix's basic checks were also performed.

**No action required on `contracts/Arxia.sol` based on this report.**
