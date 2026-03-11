# Foundry Migration Analysis: 1inch-cross-chain-swap

## Package Manager

**Selected:** `yarn` (yarn.lock present, only lockfile in project)

## foundry.toml Settings

### [profile.default]
| Setting | Value |
|---|---|
| `src` | `contracts` |
| `out` | `out` |
| `libs` | `["lib"]` |
| `test` | `test` |
| `optimizer_runs` | `1000000` |
| `via-ir` | `true` |
| `evm_version` | `shanghai` |
| `solc_version` | `0.8.23` |
| `gas_reports` | `["EscrowSrc", "EscrowDst", "EscrowFactory", "MerkleStorageInvalidator"]` |
| `fs_permissions` | read: `./examples/config/config.json`, `./broadcast`, `./reports`, `./config` |

### [profile.lite.optimizer_details.yulDetails]
| Setting | Value |
|---|---|
| `optimizerSteps` | `''` (empty — disables Yul optimizer steps) |

### [profile.zksync]
| Setting | Value |
|---|---|
| `src` | `contracts` |
| `libs` | `["lib"]` |
| `fallback_oz` | `true` |
| `is_system` | `false` |
| `mode` | `"3"` |

### [fmt]
| Setting | Value |
|---|---|
| `line_length` | `140` |
| `bracket_spacing` | `true` |
| `multiline_func_header` | `params_first` |
| `wrap_comments` | `true` |

### [fuzz]
| Setting | Value |
|---|---|
| `runs` | `1024` |

## Remappings (remappings.txt)

```
@1inch/limit-order-protocol-contract/=lib/limit-order-protocol/
@1inch/limit-order-settlement/=lib/limit-order-settlement/
@1inch/solidity-utils/=lib/solidity-utils/
solidity-utils/=lib/solidity-utils/
limit-order-protocol/=lib/limit-order-protocol/
limit-order-settlement/=lib/limit-order-settlement/
```

**Missing from remappings.txt (needed):**
- `forge-std/=lib/forge-std/src/`
- `openzeppelin-contracts/=lib/openzeppelin-contracts/` (used by murky)
- `murky/=lib/murky/src/` (used by test files)
- `contracts/=./contracts/` (absolute imports — 23 files)
- `test/=./test/` (absolute imports from script/)

## Git Submodules (lib/)

| Submodule | Path | Cross-deps |
|---|---|---|
| forge-std | lib/forge-std | — |
| solidity-utils | lib/solidity-utils | openzeppelin-contracts |
| openzeppelin-contracts | lib/openzeppelin-contracts | — |
| limit-order-protocol | lib/limit-order-protocol | @1inch/solidity-utils, @openzeppelin/contracts |
| limit-order-settlement | lib/limit-order-settlement | @1inch/solidity-utils, @1inch/limit-order-protocol-contract |
| murky | lib/murky | openzeppelin-contracts |

## Directory Structure

- **Source:** `contracts/`
- **Tests:** `test/` (unit/, integration/, libraries/, utils/)
- **Scripts:** `script/`
- **Examples:** `examples/`

## Absolute Imports

23 files use absolute `contracts/` imports. 1 file uses absolute `test/` import. Approach: add remappings.

## Inline Test Config (`forge-config:`)

None found.

## Forge-Dependent package.json Scripts

| Script | Command | Forge Feature |
|---|---|---|
| `clean` | `forge clean` | Build cleanup |
| `coverage` | `forge coverage --report lcov --ir-minimum` | Coverage with IR minimum |
| `coverage:zksync` | `forge coverage --zksync ...` | zkSync coverage |
| `coverage:html` | `bash scripts/coverage.sh` | Coverage HTML |
| `doc` | `forge doc --build --out documentation` | Documentation generation |
| `gasreport` | `forge test -vvv --gas-report` | Gas reporting |
| `test` | `forge snapshot --no-match-test "testFuzz_*"` | Gas snapshot (non-fuzz) |
| `test:lite` | `FOUNDRY_PROFILE=lite forge test -vvv` | Lite profile test |
| `test:zksync` | `forge test -vvv --zksync --force` | zkSync test |
| `postinstall` | `forge install` | Submodule install |

## Test Count

94 `function test*` declarations in `.t.sol` files under `test/` (excluding examples).
