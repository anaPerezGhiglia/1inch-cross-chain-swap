# Hardhat 3 Migration Report: 1inch-cross-chain-swap

**Hardhat version installed:** `^3.4.4`
**Migration date:** 2026-05-05
**Foundry analysis:** [Foundry analysis](1inch-cross-chain-swap-foundry-migration-analysis.md)

---

**Verdict:** 🟡 **Successful with gaps**

### Notable gaps (non-blocking, medium+ impact)

- 🚩 zkSync compilation & testing — 6 contracts (~22% of codebase) cannot be tested under Hardhat; requires Matter Labs' foundry-zksync fork

## 1. Test Count Comparison

| Metric | Count |
|---|---|
| `function test*` declarations in `.t.sol` files | 94 |
| Hardhat tests run | 94 |
| Hardhat tests passing | 94 |
| Hardhat tests passing under `--coverage` | 94 |
| Tests commented out (UnsupportedCheatcode) | 0 |

**No discrepancy.** All test functions were discovered and passed, including under coverage instrumentation.

## 2. Feature Parity

### Gaps, bugs & partial support

| Feature | Parity | Impact | Workaround / Notes |
|---|---|---|---|
| zkSync compilation & testing (`--zksync`, `[profile.zksync]`) | 🚩 **Gap** | **High** — 6 contracts (~22% of codebase) in `contracts/zkSync/` cannot be compiled with zkSync semantics or tested under Hardhat 3. All 94 tests are designed to run against both EVM and zkSync paths via `FOUNDRY_PROFILE` switching, but only the EVM path is exercised under Hardhat. CI `test-zksync` job, `test:zksync` and `coverage:zksync` scripts have no Hardhat equivalent. | No tracking issue found — requires Matter Labs' `foundry-zksync` fork. Forge must be retained for zkSync testing. `@matterlabs/hardhat-zksync-solc` still declares `peerDependencies: hardhat ^2.22.5` — no HH3 support yet. |
| Gas reports (`forge test --gas-report`) | 🚩 **Gap** | **Low** — gas report target filtering (`gas_reports` in foundry.toml) not available | HH2 community plugin [`hardhat-gas-reporter`](https://www.npmjs.com/package/hardhat-gas-reporter) still declares `peerDependencies: hardhat ^2.16.0` — no HH3 support yet. `gasreport` script cannot be migrated. |
| Documentation generator (`forge doc`) | 🟡 **Partial** | **Low** — documentation generation script cannot run via Hardhat | Community plugin [`@solarity/hardhat-markup`](https://www.npmjs.com/package/@solarity/hardhat-markup) supports HH3 (`peerDependencies: hardhat ^3.0.0`) |

### Full parity

These features work equivalently in Hardhat 3:

- Solidity compilation (`forge build` → `npx hardhat compile`)
- Optimizer settings (1M runs, via-IR, shanghai EVM)
- Build profiles (`default`, `lite`)
- forge-std cheatcodes (`vm.*`) — all used cheatcodes work
- Fuzz testing (1024 runs)
- Gas snapshots (`forge snapshot` → `npx hardhat test solidity --snapshot` / `--snapshot-check`)
- Code coverage (`forge coverage` → `npx hardhat test solidity --coverage`) — 94/94 tests now pass under coverage in Hardhat 3.4.4 (previous returndata-buffer instrumentation bug appears resolved). Via-IR works natively without `--ir-minimum`.
- `vm.envString` for environment variable reading
- `fsPermissions` (read files and directories)
- Remappings (git submodule deps, cross-submodule imports, absolute imports)

**Features not used by this project:**

- Invariant testing — no invariant tests present
- Network configuration / RPC endpoints — no `[rpc_endpoints]` in foundry.toml
- Etherscan verification — no `[etherscan]` section in foundry.toml; `@nomicfoundation/hardhat-verify` is available if needed in the future
- Deployment scripting (`forge script` / `.s.sol`) — project uses shell scripts instead
- Inline test config — no `forge-config:` directives in test files

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

The `test-hardhat` script (and `coverage-hardhat`, `snapshot-hardhat`, `snapshot-check-hardhat`) sets `FOUNDRY_PROFILE=default` because `BaseSetup.setUp()` calls `vm.envString("FOUNDRY_PROFILE")` to detect the zkSync profile. Without this env var, all tests fail with `vm.envString: environment variable "FOUNDRY_PROFILE" not found`.

### ESM migration

Added `"type": "module"` to `package.json` as required by Hardhat 3. The project has no existing CommonJS `.js` files that would break.

## 4. Next Steps

1. **Retain Forge for zkSync testing** — Hardhat 3 cannot replace Forge for zkSync compilation or testing. The `test:zksync` and `coverage:zksync` scripts must continue using Matter Labs' `foundry-zksync` fork. Both toolchains will need to coexist long-term unless `@matterlabs/hardhat-zksync` adds HH3 support. (High impact — 6 contracts, ~22% of codebase untestable under Hardhat)
2. **Adopt coverage in CI** — Coverage now passes cleanly in Hardhat 3.4.4 (94/94 tests). The previously documented returndata-buffer instrumentation bug (3 tests failing) no longer reproduces. Wire `coverage-hardhat` into CI to keep parity with Forge's `coverage` job.
3. **Adopt gas snapshots in CI** — `--snapshot` and `--snapshot-check` are verified working. Integrate the `snapshot-hardhat` and `snapshot-check-hardhat` scripts into CI to detect gas regressions.
4. **Track HH3 plugin support** — Watch `hardhat-gas-reporter` and `@matterlabs/hardhat-zksync-solc` peerDependencies for HH3 compatibility. Until then, `gasreport`, `test:zksync`, and `coverage:zksync` must stay on Forge.
