# Hardhat 3 Migration Report: 1inch-cross-chain-swap

**Hardhat version installed:** `^3.1.12`
**Migration date:** 2026-03-11
**Foundry analysis:** [Foundry analysis](1inch-cross-chain-swap-foundry-migration-analysis.md)

---

**Verdict:** 🟡 **Successful with gaps**

### Notable gaps (non-blocking, medium+ impact)

- 🚩 zkSync compilation & testing — 6 contracts (~22% of codebase) cannot be tested under Hardhat; requires Matter Labs' foundry-zksync fork
- 🚩 No equivalent for `forge snapshot` — gas snapshot workflow unavailable ([#7769](https://github.com/NomicFoundation/hardhat/issues/7769))
- 🟡 Code coverage — 3/94 tests fail only under `--coverage` (revert data lost during instrumentation); via-IR works natively

## 1. Test Count Comparison

| Metric | Count |
|---|---|
| `function test*` declarations in `.t.sol` files | 94 |
| Hardhat tests run | 94 |
| Hardhat tests passing | 94 |
| Tests commented out (UnsupportedCheatcode) | 0 |

**No discrepancy.** All test functions were discovered and passed.

## 2. Feature Parity

### Gaps, bugs & partial support

| Feature | Parity | Impact | Workaround / Notes |
|---|---|---|---|
| zkSync compilation & testing (`--zksync`, `[profile.zksync]`) | 🚩 **Gap** | **High** — 6 contracts (~22% of codebase) in `contracts/zkSync/` cannot be compiled with zkSync semantics or tested under Hardhat 3. All 94 tests are designed to run against both EVM and zkSync paths via `FOUNDRY_PROFILE` switching, but only the EVM path is exercised under Hardhat. CI `test-zksync` job, `test:zksync` and `coverage:zksync` scripts have no Hardhat equivalent. | No tracking issue found — requires Matter Labs' `foundry-zksync` fork. Forge must be retained for zkSync testing. Hardhat's [zkSync plugin ecosystem](https://docs.zksync.io/build/tooling/hardhat) targets HH2, not HH3. |
| Gas snapshots (`forge snapshot`) | 🚩 **Gap** | **Medium** — `test` script uses `forge snapshot`; no snapshot comparison in CI | [#7769](https://github.com/NomicFoundation/hardhat/issues/7769) — no workaround currently |
| Gas reports (`forge test --gas-report`) | 🚩 **Gap** | **Low** — gas report target filtering (`gas_reports` in foundry.toml) not available | HH2 community plugin [`hardhat-gas-reporter`](https://www.npmjs.com/package/hardhat-gas-reporter) exists but requires `hardhat ^2.16.0` — no HH3 support yet. `gasreport` script cannot be migrated. |
| Code coverage (`forge coverage`) | 🟡 **Partial** | **Medium** — 91/94 tests pass under `--coverage`; 3 fail (pass without coverage). Via-IR works natively — no `--ir-minimum` equivalent needed. | Coverage instrumentation bug in library functions using inline assembly `returndatasize()`. See [bug report & minimal repro](https://github.com/anaPerezGhiglia/repro-coverage-returndata-bug). |
| `forge doc` | 🟡 **Partial** | **Low** — documentation generation script cannot run via Hardhat | Community plugin [`@solarity/hardhat-markup`](https://www.npmjs.com/package/@solarity/hardhat-markup) supports HH3 |
| Etherscan verification | 🟡 **Partial** | **Low** — not configured in foundry.toml but project has deploy scripts | `@nomicfoundation/hardhat-verify` available if needed |

### Full parity

These features work equivalently in Hardhat 3:

- Solidity compilation (`forge build` → `npx hardhat compile`)
- Optimizer settings (1M runs, via-IR, shanghai EVM)
- Build profiles (`default`, `lite`)
- forge-std cheatcodes (`vm.*`) — all used cheatcodes work
- Fuzz testing (1024 runs)
- `vm.envString` for environment variable reading
- `fsPermissions` (read files and directories)
- Remappings (git submodule deps, cross-submodule imports, absolute imports)

**Features not used by this project:**
- Invariant testing — no invariant tests present
- Network configuration / RPC endpoints — no `[rpc_endpoints]` in foundry.toml
- Contract verification — no `[etherscan]` section in foundry.toml
- Deployment scripts (`forge script` / `.s.sol`) — project uses shell scripts instead

## 3. Workarounds Applied

### Remappings added to `remappings.txt`

Five remappings were added to the root `remappings.txt`:

| Remapping | Reason |
|---|---|
| `forge-std/=lib/forge-std/src/` | forge-std as submodule needs explicit remapping (Hardhat's npm allowlist doesn't apply to `lib/`) |
| `openzeppelin-contracts/=lib/openzeppelin-contracts/` | Used by murky submodule's internal imports |
| `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/` | Used by limit-order-protocol submodule (`@openzeppelin/contracts/` npm-style imports resolve through this remapping instead of `node_modules/`) |
| `murky/=lib/murky/` | Used by test files importing `murky/src/Merkle.sol` |
| `contracts/=./contracts/` and `test/=./test/` | 23 files use absolute imports like `import "contracts/Foo.sol"` — Hardhat 3 doesn't support absolute imports natively. Forge resolves these via `src = "contracts"` which implicitly maps the `contracts/` prefix. Remappings reproduce this behavior. |

**Root cause:** Forge resolves imports through a combination of `src`/`test`/`libs` config and global remappings that apply to all files. Hardhat 3 uses Node.js module resolution for npm packages and scoped `remappings.txt` for local paths. Submodule cross-dependencies that Forge handles transparently via `libs = ["lib"]` need explicit remappings in Hardhat.

### Environment variable for test script

The `test-hardhat` script sets `FOUNDRY_PROFILE=default` because `BaseSetup.setUp()` calls `vm.envString("FOUNDRY_PROFILE")` to detect the zkSync profile. Without this env var, all tests fail with `vm.envString: environment variable "FOUNDRY_PROFILE" not found`.

### ESM migration

Added `"type": "module"` to `package.json` as required by Hardhat 3. The project has no existing CommonJS `.js` files that would break.

## 4. Next Steps

1. **Retain Forge for zkSync testing** — Hardhat 3 cannot replace Forge for zkSync compilation or testing. The `test:zksync` and `coverage:zksync` scripts must continue using Matter Labs' `foundry-zksync` fork. Both toolchains will need to coexist long-term unless Hardhat's zkSync plugin ecosystem adds HH3 support. (High impact — 6 contracts, ~22% of codebase untestable under Hardhat)
2. **File upstream coverage bug** — 3 tests fail under `--coverage` because coverage instrumentation injects calls that overwrite the EVM returndata buffer inside library functions using inline assembly (`returndatasize` / `returndatacopy`). Bug report and minimal repro at [anaPerezGhiglia/repro-coverage-returndata-bug](https://github.com/anaPerezGhiglia/repro-coverage-returndata-bug). Consider filing on [NomicFoundation/hardhat](https://github.com/NomicFoundation/hardhat/issues).
3. **Evaluate gas snapshot alternative** — if gas regression detection is needed in CI, consider a custom script that parses Hardhat gas reporter output. ([#7769](https://github.com/NomicFoundation/hardhat/issues/7769))
