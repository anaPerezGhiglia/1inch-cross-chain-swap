# Bug: Coverage instrumentation overwrites returndata buffer in library functions

## Summary

Hardhat 3's `--coverage` instrumentation injects calls to a special address (`0xc0bEc0BEc0BeC0bEC0beC0bEC0bEC0beC0beC0BE`) for tracking code coverage. When these instrumentation calls are injected into a library function that uses `returndatasize()` / `returndatacopy()` in inline assembly, the injected call overwrites the returndata buffer, causing the assembly to read stale/wrong data.

This breaks the common Solidity pattern of forwarding revert reasons via inline assembly after a failed low-level `.call()`.

## Affected version

- Hardhat `^3.1.12`
- Solidity `0.8.23` with `via-ir = true`, optimizer runs = 1,000,000

## Minimal reproduction

**File:** `test/bugs/CoverageReturndataBug.t.sol`

Two variants of the same logic — one using a library function (breaks), one using inline assembly directly in the contract (works):

```solidity
// Library with revert forwarding (same as @1inch/solidity-utils RevertReasonForwarder)
library RevertForwarderLib {
    function reRevert() internal pure {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, returndatasize())
            revert(ptr, returndatasize())
        }
    }
}

contract LibForwarder {
    function forward(address target, bytes calldata data) external {
        (bool success,) = target.call(data);
        if (!success) RevertForwarderLib.reRevert();  // ← FAILS under coverage
    }
}

contract InlineForwarder {
    function forward(address target, bytes calldata data) external {
        (bool success,) = target.call(data);
        if (!success) {
            assembly ("memory-safe") {              // ← PASSES under coverage
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}
```

**Without coverage (both PASS):**
```bash
FOUNDRY_PROFILE=default npx hardhat test solidity test/bugs/CoverageReturndataBug.t.sol
```

**With coverage (library variant FAILS):**
```bash
FOUNDRY_PROFILE=default npx hardhat test solidity --coverage test/bugs/CoverageReturndataBug.t.sol
```

**Error:**
```
Error: Error != expected error: call to non-contract address 0xc0bEc0BEc0BeC0bEC0beC0bEC0bEC0beC0beC0BE != CustomError()
```

## Root cause

Coverage instrumentation injects calls to `0xc0bEc0BEc0BeC0bEC0beC0bEC0bEC0beC0beC0BE` to track which lines of code are executed. When this injection happens inside a library function that relies on `returndatasize()` / `returndatacopy()`, the injected call **overwrites the EVM's returndata buffer**. The subsequent `returndatacopy` then reads the result of the instrumentation call instead of the original revert data from the failed `.call()`.

The inline assembly variant works because the instrumentation is not injected between the `.call()` and the assembly block when they're in the same function — but when the assembly is in a separate library function, the instrumentation gets injected at the library function entry point, before `returndatasize()` is read.

**Key insight:** The bug is specific to **library functions** containing `returndatasize()` / `returndatacopy()`. The same assembly inlined directly in the contract does not exhibit the bug.

## Impact on this project

3 out of 94 tests fail only under `--coverage`:

| Test | File | Expected error |
|------|------|---------------|
| `test_MockPublicWithdrawDst` | `test/integration/ResolverMock.t.sol:345` | `InvalidCaller.selector` |
| `test_MockPublicCancelSrc` | `test/integration/ResolverMock.t.sol:166` | `InvalidCaller.selector` |
| `test_NoFailedNativeTokenTransferWithdrawalSrc` | `test/unit/Escrow.t.sol:718` | `NativeTokenSendingFailure.selector` |

All use `RevertReasonForwarder.reRevert()` from `@1inch/solidity-utils` (`lib/solidity-utils/contracts/libraries/RevertReasonForwarder.sol:14-21`).

## Workaround

None that preserves test correctness. The tests are correct — the coverage tool is at fault. Options:
- Use `vm.expectRevert()` (no selector) to accept any revert, but this weakens assertions
- Skip these tests during coverage runs
- Wait for upstream fix

## Suggested fix

Coverage instrumentation should not inject calls that modify the returndata buffer inside functions that use `returndatasize()` / `returndatacopy()` in inline assembly. Alternatively, the instrumentation could save and restore the returndata buffer around its tracking calls.
