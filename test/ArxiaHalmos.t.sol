// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test}  from "forge-std/Test.sol";
import {Arxia} from "../contracts/Arxia.sol";

/// @title  Halmos symbolic invariants for Arxia ERC-20
/// @notice Functions prefixed with `check_` are picked up by Halmos and
///         verified for ALL possible symbolic inputs satisfying vm.assume
///         preconditions. Any counterexample halts with a model.
///
///         Run: halmos --contract ArxiaHalmosTest
contract ArxiaHalmosTest is Test {
    Arxia internal arx;

    // Concrete recipients — Halmos handles call-site symbolic args.
    address internal r0 = address(uint160(0x1001));
    address internal r1 = address(uint160(0x1002));
    address internal r2 = address(uint160(0x1003));
    address internal r3 = address(uint160(0x1004));
    address internal r4 = address(uint160(0x1005));
    address internal r5 = address(uint160(0x1006));

    uint256 internal constant MAX_SUPPLY = 1_000_000_000e6;

    function setUp() public {
        arx = new Arxia(r0, r1, r2, r3, r4, r5);
    }

    // ========================================================================
    // INVARIANT 1 — Total supply at deploy equals MAX_SUPPLY exactly.
    // ========================================================================
    function check_TotalSupplyAtDeploy() public view {
        assert(arx.totalSupply() == MAX_SUPPLY);
    }

    // ========================================================================
    // INVARIANT 2 — Transfer is exact (no fee, no rounding).
    //               For ANY symbolic (to, amount) with valid preconditions,
    //               sender loses exactly `amount`, receiver gains exactly `amount`,
    //               and totalSupply is unchanged.
    // ========================================================================
    function check_TransferIsExact(address to, uint256 amount) public {
        // Halmos picks symbolic values; we restrict to the valid input space.
        vm.assume(to != address(0));
        vm.assume(to != r0);                  // sender != receiver
        vm.assume(amount <= arx.balanceOf(r0));

        uint256 fromBefore   = arx.balanceOf(r0);
        uint256 toBefore     = arx.balanceOf(to);
        uint256 supplyBefore = arx.totalSupply();

        vm.prank(r0);
        arx.transfer(to, amount);

        assert(arx.balanceOf(r0)   == fromBefore - amount);
        assert(arx.balanceOf(to)   == toBefore   + amount);
        assert(arx.totalSupply()   == supplyBefore);
    }

    // ========================================================================
    // INVARIANT 3 — Burn is exact (reduces balance AND totalSupply by amount).
    // ========================================================================
    function check_BurnIsExact(uint256 amount) public {
        vm.assume(amount <= arx.balanceOf(r0));

        uint256 balBefore    = arx.balanceOf(r0);
        uint256 supplyBefore = arx.totalSupply();

        vm.prank(r0);
        arx.burn(amount);

        assert(arx.balanceOf(r0) == balBefore    - amount);
        assert(arx.totalSupply() == supplyBefore - amount);
    }

    // ========================================================================
    // INVARIANT 4 — totalSupply NEVER increases.
    //               No public function on this contract can grow totalSupply.
    //               (mint is internal-only, ERC20Burnable only decreases.)
    // ========================================================================
    function check_TotalSupplyNeverIncreases_AfterTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= arx.balanceOf(r0));

        uint256 supplyBefore = arx.totalSupply();
        vm.prank(r0);
        arx.transfer(to, amount);
        assert(arx.totalSupply() <= supplyBefore);
    }

    function check_TotalSupplyNeverIncreases_AfterBurn(uint256 amount) public {
        vm.assume(amount <= arx.balanceOf(r0));

        uint256 supplyBefore = arx.totalSupply();
        vm.prank(r0);
        arx.burn(amount);
        assert(arx.totalSupply() <= supplyBefore);
    }

    // ========================================================================
    // INVARIANT 5 — Approve sets allowance to exactly the requested value
    //               (no race-condition mitigation, OZ v5 standard behavior).
    // ========================================================================
    function check_ApproveIsExact(address spender, uint256 value) public {
        vm.assume(spender != address(0));

        vm.prank(r0);
        arx.approve(spender, value);

        assert(arx.allowance(r0, spender) == value);
    }

    // ========================================================================
    // INVARIANT 6 — totalSupply ≤ MAX_SUPPLY ALWAYS.
    //               After ANY single transfer or burn from the deploy state,
    //               totalSupply remains bounded by MAX_SUPPLY.
    // ========================================================================
    function check_TotalSupplyBoundedAfterTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= arx.balanceOf(r0));

        vm.prank(r0);
        arx.transfer(to, amount);

        assert(arx.totalSupply() <= MAX_SUPPLY);
    }

    function check_TotalSupplyBoundedAfterBurn(uint256 amount) public {
        vm.assume(amount <= arx.balanceOf(r0));

        vm.prank(r0);
        arx.burn(amount);

        assert(arx.totalSupply() <= MAX_SUPPLY);
    }
}
