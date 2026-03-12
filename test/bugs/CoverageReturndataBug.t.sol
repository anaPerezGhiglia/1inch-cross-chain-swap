// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { RevertReasonForwarder } from "solidity-utils/contracts/libraries/RevertReasonForwarder.sol";

error CustomError();

/// @dev Target contract that reverts with a custom error.
contract Reverter {
    function doRevert() external pure {
        revert CustomError();
    }
}

/// @dev Forwarder using the exact same library as ResolverExample/NoReceiveCaller.
contract LibForwarder {
    function forward(address target, bytes calldata data) external {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = target.call(data);
        if (!success) RevertReasonForwarder.reRevert();
    }
}

/// @dev Forwarder with inline assembly (same logic, no library call).
contract InlineForwarder {
    function forward(address target, bytes calldata data) external {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = target.call(data);
        if (!success) {
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}

/// @notice Reproduces a Hardhat 3 coverage bug where coverage instrumentation
/// injects calls to 0xc0bEc0BEc0BeC0bEC0beC0bEC0bEC0beC0beC0BE inside library
/// functions, overwriting the EVM returndata buffer. This causes returndatasize()
/// to return stale data instead of the original revert reason.
///
/// The library variant (LibForwarder) FAILS under --coverage.
/// The inline variant (InlineForwarder) PASSES under --coverage.
///
/// Related real-world failures:
///   - IntegrationResolverMockTest#test_MockPublicWithdrawDst()
///   - IntegrationResolverMockTest#test_MockPublicCancelSrc()
///   - EscrowTest#test_NoFailedNativeTokenTransferWithdrawalSrc()
contract CoverageReturndataBugTest is Test {
    Reverter reverter;
    LibForwarder libForwarder;
    InlineForwarder inlineForwarder;

    function setUp() public {
        reverter = new Reverter();
        libForwarder = new LibForwarder();
        inlineForwarder = new InlineForwarder();
    }

    /// @notice FAILS under --coverage. Uses RevertReasonForwarder library — coverage
    /// injects a call to 0xc0bE..c0BE at the library function entry, overwriting returndata.
    function test_RevertDataPreservedThroughLibraryForward() public {
        vm.expectRevert(CustomError.selector);
        libForwarder.forward(
            address(reverter),
            abi.encodeCall(Reverter.doRevert, ())
        );
    }

    /// @notice PASSES under --coverage. Same logic inlined — no library boundary
    /// means no instrumentation call between .call() and returndatacopy.
    function test_RevertDataPreservedThroughInlineForward() public {
        vm.expectRevert(CustomError.selector);
        inlineForwarder.forward(
            address(reverter),
            abi.encodeCall(Reverter.doRevert, ())
        );
    }
}
