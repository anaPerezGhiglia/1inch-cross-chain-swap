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

/// @notice Reproduces a Hardhat 3 coverage bug where returndatasize() returns 0
/// inside inline assembly after a failed .call().
///
/// All tests pass without --coverage but may fail with --coverage due to
/// coverage instrumentation resetting the returndata buffer.
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

    /// @notice Uses RevertReasonForwarder library (same as production code).
    function test_RevertDataPreservedThroughLibraryForward() public {
        vm.expectRevert(CustomError.selector);
        libForwarder.forward(
            address(reverter),
            abi.encodeCall(Reverter.doRevert, ())
        );
    }

    /// @notice Uses inline assembly (same logic, no library).
    function test_RevertDataPreservedThroughInlineForward() public {
        vm.expectRevert(CustomError.selector);
        inlineForwarder.forward(
            address(reverter),
            abi.encodeCall(Reverter.doRevert, ())
        );
    }
}
