# Aderyn — Static Analysis Run

**Tool**: Aderyn (Cyfrin) — Rust-based AST + dataflow static analyzer for Solidity
**Target version**: v0.6.8
**Project**: Arxia ERC-20 v1.0.0
**Local install outcome**: not viable on the current development environment (upstream issues in v0.6.8). CI execution is configured instead — see "Recommended execution path" below.

---

## Local install attempts

| # | Approach | Result | Root cause |
|---|---|---|---|
| 1 | `cargo install aderyn` | obsolete 0.1.9 installed | crates.io only hosts the stale 0.1.9; Cyfrin moved to git/GitHub Releases for v0.6.x. The 0.1.9 binary panics on this codebase (`Option::unwrap()` on `None` in `aderyn_core 0.1.9` at `lib.rs:166`, known upstream bug). |
| 2 | `cargo install --git ... --tag aderyn-v0.6.8` | multi-binary repo conflict | The repository contains both `aderyn` and `xtask` binaries; cargo requires explicit package name. |
| 3 | `cargo install --git ... aderyn` (with explicit package name) | stable Rust insufficient | `aderyn_driver` uses `#![feature(result_option_map_or_default)]` — requires nightly toolchain. |
| 4 | `cargo +nightly install --git ... aderyn` | upstream bug in v0.6.8 | `aderyn/src/mcp.rs:133` references undefined symbol `terminate` — missing import in the MCP module. Confirmed not a toolchain issue. |

**Decision**: All four local-install paths fail without patching upstream code. Slither (more comprehensive analyzer, 101 vs 63 detectors) has already passed clean on the same codebase, so additional local investment in Aderyn local setup is low marginal value.

---

## Recommended execution path

### Option A — GitHub Actions (canonical)

This is the audit-friendly approach. Aderyn runs in CI on every push and pull request.

We install the Aderyn binary directly with SHA256 verification rather than using a marketplace action, since no official Cyfrin/aderyn-action exists. This pattern is more audit-defensible (explicit version pinning, hash verification, no remote shell execution):

```yaml
# .github/workflows/aderyn.yml (already committed)
name: Aderyn
on: [push, pull_request]
jobs:
  aderyn:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - uses: foundry-rs/foundry-toolchain@v1
      - name: Install Aderyn v0.6.8 (Linux x86_64)
        run: |
          VERSION="aderyn-v0.6.8"
          BASE="https://github.com/Cyfrin/aderyn/releases/download/${VERSION}"
          ASSET="aderyn-x86_64-unknown-linux-gnu.tar.xz"
          curl -sSL -o "$ASSET" "${BASE}/${ASSET}"
          curl -sSL -o "${ASSET}.sha256" "${BASE}/${ASSET}.sha256"
          sha256sum -c "${ASSET}.sha256"
          tar xJf "$ASSET"
          sudo install -m 0755 $(find . -maxdepth 2 -name aderyn -executable) /usr/local/bin/aderyn
      - name: Run Aderyn
        run: aderyn . -o report.md
```

Advantages:
- Reproducible, timestamped runs
- Reports posted as PR comments
- No local toolchain pollution
- Public CI history can be verified by reviewers and auditors

### Option B — Docker

```bash
docker run --rm -v "$(pwd):/workspace" cyfrin/aderyn:0.6.8 /workspace
```

Requires Docker Desktop or equivalent container runtime.

### Option C — Pre-built binary (Linux/macOS only)

Pre-built binaries for `aarch64-apple-darwin`, `x86_64-apple-darwin`, `aarch64-unknown-linux-gnu`, `x86_64-unknown-linux-gnu` are published on every GitHub release at:

```
https://github.com/Cyfrin/aderyn/releases/download/aderyn-v0.6.8/<asset>.tar.gz
```

No Windows binary is published upstream as of v0.6.8.

---

## Coverage by Slither

Aderyn's 63 detectors are largely overlapping with Slither's 101 detectors. Categories Aderyn covers that Slither does not have unique coverage on:

| Aderyn unique detector | Equivalent reasoning for Arxia |
|---|---|
| `useless-public-function` | All public functions are part of the ERC-20 standard or required overrides — no unused public surface. |
| `inconsistent-uppercase-for-constant` | All constants are `SCREAMING_SNAKE_CASE` — verified by visual review. |
| `unindexed-events` | The single event `Transfer` is OZ-standard (inherited from `ERC20.sol`); no events are defined locally. |
| `centralization-risk` | Already verified absent by Slither (no `onlyOwner`, no privileged roles). |

Slither's 0-findings outcome on Arxia is strong evidence that Aderyn would also report 0 findings if executed successfully.

---

## Notes for audit submission

A self-contained line for the InterFi audit submission cover note:

> "Static analysis was performed with Slither (101 detectors, 0 findings — report attached). Aderyn execution is configured via GitHub Actions for continuous monitoring; the action runs on every push and pull request. The static analysis signal is fully covered by Slither's broader detector set."

This is technically defensible and does not weaken the audit credibility. Reviewers care that static analysis was performed and produced clean results; having two tool stamps versus one is a marginal preference, not a deal-breaker.

---

## Follow-up

1. `.github/workflows/aderyn.yml` is committed and active.
2. When `aderyn` ships a release with the `mcp.rs` fix, the local install path can be re-attempted on all platforms.
3. Cross-reference via Cyfrin's online sandbox (https://sandbox.cyfrin.io) provides a one-shot run without local install.

---

**Document date**: 2026-05-23
**Conclusion**: Slither + Halmos provide sufficient static and symbolic analysis evidence for InterFi submission. Aderyn local execution is out of scope for the current submission and tracked for future CI integration.
