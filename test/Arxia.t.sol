// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test}         from "forge-std/Test.sol";
import {Arxia}        from "../contracts/Arxia.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @dev Local mirrors of OZ ERC20Permit error definitions for vm.expectRevert.
///      Custom errors are matched by 4-byte selector (signature-based), so
///      these locally-declared errors match the contract's reverts exactly.
interface IERC20PermitErrors {
    error ERC2612ExpiredSignature(uint256 deadline);
    error ERC2612InvalidSigner(address signer, address owner);
}

contract ArxiaTest is Test, IERC20PermitErrors {
    Arxia internal arx;

    // --- Allocation recipients ---------------------------------------------
    address internal nodeOperators = makeAddr("nodeOperators");
    address internal ecosystem     = makeAddr("ecosystem");
    address internal teamVesting   = makeAddr("teamVesting");
    address internal ido           = makeAddr("ido");
    address internal treasury      = makeAddr("treasury");
    address internal seedVesting   = makeAddr("seedVesting");

    // --- Test actors (with private keys for permit signing) -----------------
    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;

    // --- Constants mirrored from contract -----------------------------------
    uint256 internal constant MAX_SUPPLY      = 1_000_000_000e6;
    uint256 internal constant NODE_OPS_AMOUNT = 250_000_000e6;
    uint256 internal constant ECO_AMOUNT      = 200_000_000e6;
    uint256 internal constant TEAM_AMOUNT     = 150_000_000e6;
    uint256 internal constant IDO_AMOUNT      = 150_000_000e6;
    uint256 internal constant TREASURY_AMOUNT = 130_000_000e6;
    uint256 internal constant SEED_AMOUNT     = 120_000_000e6;

    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob,   bobPk)   = makeAddrAndKey("bob");

        arx = new Arxia(
            nodeOperators,
            ecosystem,
            teamVesting,
            ido,
            treasury,
            seedVesting
        );
    }

    // ========================================================================
    // CONSTRUCTOR — positive
    // ========================================================================

    function test_Constructor_Metadata() public view {
        assertEq(arx.name(),       "Arxia");
        assertEq(arx.symbol(),     "ARX");
        assertEq(arx.decimals(),   6);
        assertEq(arx.VERSION(),    "1.0.0");
        assertEq(arx.MAX_SUPPLY(), MAX_SUPPLY);
    }

    function test_Constructor_MintsExactAllocations() public view {
        assertEq(arx.balanceOf(nodeOperators), NODE_OPS_AMOUNT, "node ops");
        assertEq(arx.balanceOf(ecosystem),     ECO_AMOUNT,      "ecosystem");
        assertEq(arx.balanceOf(teamVesting),   TEAM_AMOUNT,     "team");
        assertEq(arx.balanceOf(ido),           IDO_AMOUNT,      "ido");
        assertEq(arx.balanceOf(treasury),      TREASURY_AMOUNT, "treasury");
        assertEq(arx.balanceOf(seedVesting),   SEED_AMOUNT,     "seed");
    }

    function test_Constructor_TotalSupplyEqualsMaxSupply() public view {
        assertEq(arx.totalSupply(), MAX_SUPPLY);
        assertEq(arx.totalSupply(), arx.MAX_SUPPLY());
    }

    function test_Constructor_SumOfBalancesEqualsTotalSupply() public view {
        uint256 sum = arx.balanceOf(nodeOperators)
                    + arx.balanceOf(ecosystem)
                    + arx.balanceOf(teamVesting)
                    + arx.balanceOf(ido)
                    + arx.balanceOf(treasury)
                    + arx.balanceOf(seedVesting);
        assertEq(sum, arx.totalSupply());
        assertEq(sum, MAX_SUPPLY);
    }

    // ========================================================================
    // CONSTRUCTOR — negative (zero-address reverts)
    // ========================================================================

    function test_Constructor_RevertsOnZero_nodeOperators() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(address(0), ecosystem, teamVesting, ido, treasury, seedVesting);
    }

    function test_Constructor_RevertsOnZero_ecosystem() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(nodeOperators, address(0), teamVesting, ido, treasury, seedVesting);
    }

    function test_Constructor_RevertsOnZero_teamVesting() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(nodeOperators, ecosystem, address(0), ido, treasury, seedVesting);
    }

    function test_Constructor_RevertsOnZero_ido() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(nodeOperators, ecosystem, teamVesting, address(0), treasury, seedVesting);
    }

    function test_Constructor_RevertsOnZero_treasury() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(nodeOperators, ecosystem, teamVesting, ido, address(0), seedVesting);
    }

    function test_Constructor_RevertsOnZero_seedVesting() public {
        vm.expectRevert(Arxia.ZeroAddress.selector);
        new Arxia(nodeOperators, ecosystem, teamVesting, ido, treasury, address(0));
    }

    // ========================================================================
    // ERC-20 — transfer
    // ========================================================================

    function test_Transfer_Succeeds() public {
        vm.prank(treasury);
        bool ok = arx.transfer(alice, 1_000e6);
        assertTrue(ok);
        assertEq(arx.balanceOf(alice),    1_000e6);
        assertEq(arx.balanceOf(treasury), TREASURY_AMOUNT - 1_000e6);
    }

    function test_Transfer_ToZero_Reverts() public {
        vm.prank(treasury);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        arx.transfer(address(0), 1);
    }

    function test_Transfer_ExceedingBalance_Reverts() public {
        vm.prank(alice); // alice has zero balance
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1)
        );
        arx.transfer(bob, 1);
    }

    function test_Transfer_ZeroAmount_Succeeds() public {
        vm.prank(treasury);
        bool ok = arx.transfer(alice, 0);
        assertTrue(ok);
        assertEq(arx.balanceOf(alice),    0);
        assertEq(arx.balanceOf(treasury), TREASURY_AMOUNT);
    }

    // ========================================================================
    // ERC-20 — approve / transferFrom
    // ========================================================================

    function test_Approve_SetsAllowance() public {
        vm.prank(treasury);
        arx.approve(alice, 500e6);
        assertEq(arx.allowance(treasury, alice), 500e6);
    }

    function test_Approve_OverwritesPrevious() public {
        vm.startPrank(treasury);
        arx.approve(alice, 500e6);
        arx.approve(alice, 1_000e6);
        vm.stopPrank();
        assertEq(arx.allowance(treasury, alice), 1_000e6);
    }

    function test_TransferFrom_RespectsAllowance() public {
        vm.prank(treasury);
        arx.approve(alice, 1_000e6);

        vm.prank(alice);
        arx.transferFrom(treasury, bob, 400e6);

        assertEq(arx.balanceOf(bob),             400e6);
        assertEq(arx.allowance(treasury, alice), 600e6);
        assertEq(arx.balanceOf(treasury),        TREASURY_AMOUNT - 400e6);
    }

    function test_TransferFrom_ExceedingAllowance_Reverts() public {
        vm.prank(treasury);
        arx.approve(alice, 100e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, alice, 100e6, 200e6
            )
        );
        arx.transferFrom(treasury, bob, 200e6);
    }

    // ========================================================================
    // BURN (ERC20Burnable)
    // ========================================================================

    function test_Burn_ReducesBalanceAndSupply() public {
        uint256 burnAmount   = 50_000e6;
        uint256 supplyBefore = arx.totalSupply();

        vm.prank(treasury);
        arx.burn(burnAmount);

        assertEq(arx.balanceOf(treasury), TREASURY_AMOUNT - burnAmount);
        assertEq(arx.totalSupply(),       supplyBefore - burnAmount);
    }

    function test_BurnFrom_RespectsAllowance() public {
        vm.prank(treasury);
        arx.approve(alice, 100e6);

        uint256 supplyBefore = arx.totalSupply();

        vm.prank(alice);
        arx.burnFrom(treasury, 60e6);

        assertEq(arx.balanceOf(treasury),        TREASURY_AMOUNT - 60e6);
        assertEq(arx.allowance(treasury, alice), 40e6);
        assertEq(arx.totalSupply(),              supplyBefore - 60e6);
    }

    function test_Burn_ExceedingBalance_Reverts() public {
        vm.prank(alice); // zero balance
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1)
        );
        arx.burn(1);
    }

    function test_BurnFrom_ExceedingAllowance_Reverts() public {
        vm.prank(treasury);
        arx.approve(alice, 10e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, alice, 10e6, 20e6
            )
        );
        arx.burnFrom(treasury, 20e6);
    }

    // ========================================================================
    // PERMIT (EIP-2612)
    // ========================================================================

    function test_Permit_SetsAllowance() public {
        uint256 value    = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce    = arx.nonces(alice);

        bytes32 digest = _permitDigest(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        arx.permit(alice, bob, value, deadline, v, r, s);

        assertEq(arx.allowance(alice, bob), value);
        assertEq(arx.nonces(alice),         nonce + 1);
    }

    function test_Permit_ExpiredDeadline_Reverts() public {
        uint256 value    = 100e6;
        uint256 deadline = block.timestamp;
        vm.warp(deadline + 1);
        uint256 nonce = arx.nonces(alice);

        bytes32 digest = _permitDigest(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        vm.expectRevert(
            abi.encodeWithSelector(ERC2612ExpiredSignature.selector, deadline)
        );
        arx.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_Permit_InvalidSignature_Reverts() public {
        uint256 value    = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce    = arx.nonces(alice);

        // Sign the digest with bob's key but claim it's alice's permit
        bytes32 digest = _permitDigest(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);

        vm.expectRevert(
            abi.encodeWithSelector(ERC2612InvalidSigner.selector, bob, alice)
        );
        arx.permit(alice, bob, value, deadline, v, r, s);
    }

    function test_Permit_NonceIncrements() public {
        assertEq(arx.nonces(alice), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = _permitDigest(alice, bob, 1, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        arx.permit(alice, bob, 1, deadline, v, r, s);

        assertEq(arx.nonces(alice), 1);
    }

    function test_Permit_DomainSeparator_NonZero() public view {
        assertTrue(arx.DOMAIN_SEPARATOR() != bytes32(0));
    }

    function test_Permit_ReplayAttack_Reverts() public {
        uint256 value    = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce    = arx.nonces(alice);

        bytes32 digest = _permitDigest(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        arx.permit(alice, bob, value, deadline, v, r, s); // first use OK

        // Replay should fail (nonce now != 0, digest is for nonce 0)
        // Recovered signer will not match alice → InvalidSigner
        vm.expectRevert();
        arx.permit(alice, bob, value, deadline, v, r, s);
    }

    // ========================================================================
    // NEGATIVE TESTS — proving exclusions (no admin, no mint, no pause, no fee)
    // ========================================================================

    /// @dev Compile-time proof: the following lines do NOT compile because
    ///      these functions do not exist on Arxia. Kept as documentation.
    ///
    ///   arx.owner();             // no Ownable
    ///   arx.mint(alice, 1);      // no public mint
    ///   arx.pause();             // no Pausable
    ///   arx.blacklist(alice);    // no blacklist
    ///   arx.setFee(100);         // no fee mechanism

    function test_NoFee_ExactAmountReceived() public {
        // Invariant: transfer(X) means receiver +X exactly, sender -X exactly.
        uint256[6] memory amounts = [
            uint256(1),
            uint256(1e6),
            uint256(1_234_567),
            uint256(999_999_999e6),
            uint256(TREASURY_AMOUNT - 1),
            TREASURY_AMOUNT
        ];

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            if (amount > arx.balanceOf(treasury)) continue;

            uint256 senderBefore   = arx.balanceOf(treasury);
            uint256 receiverBefore = arx.balanceOf(alice);

            vm.prank(treasury);
            arx.transfer(alice, amount);

            assertEq(arx.balanceOf(treasury), senderBefore   - amount, "sender wrong");
            assertEq(arx.balanceOf(alice),    receiverBefore + amount, "receiver wrong");
        }
    }

    function test_NoMint_SupplyOnlyDecreases() public {
        uint256 supplyAtDeploy = arx.totalSupply();

        // Perform many operations: transfers, approvals, burns.
        vm.prank(treasury);  arx.transfer(alice, 1e6);
        vm.prank(alice);     arx.transfer(bob, 1e5);
        vm.prank(treasury);  arx.approve(bob, 1e9);
        vm.prank(bob);       arx.transferFrom(treasury, alice, 5e8);
        vm.prank(treasury);  arx.burn(100);
        vm.prank(alice);     arx.burn(50);

        uint256 supplyAfter = arx.totalSupply();
        assertLt(supplyAfter, supplyAtDeploy, "supply must only decrease (burn)");
        assertEq(supplyAtDeploy - supplyAfter, 150, "exactly the burned amount");
    }

    function test_NoBlacklist_AnyAddressCanTransfer() public {
        // Pseudo-suspicious addresses can transact freely — three DISTINCT
        // addresses (0xdEaD and 0x000...dEaD are identical, watch out).
        address[] memory weirdAddrs = new address[](3);
        weirdAddrs[0] = address(0xdEaD);
        weirdAddrs[1] = address(0xBEEF);
        weirdAddrs[2] = address(0xC0FFEE);

        for (uint256 i = 0; i < weirdAddrs.length; i++) {
            vm.prank(treasury);
            arx.transfer(weirdAddrs[i], 1e6);
            assertEq(arx.balanceOf(weirdAddrs[i]), 1e6);
        }
    }

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    function test_MaxBalance_SingleAddress() public {
        address sink = makeAddr("sink");

        vm.prank(nodeOperators); arx.transfer(sink, NODE_OPS_AMOUNT);
        vm.prank(ecosystem);     arx.transfer(sink, ECO_AMOUNT);
        vm.prank(teamVesting);   arx.transfer(sink, TEAM_AMOUNT);
        vm.prank(ido);           arx.transfer(sink, IDO_AMOUNT);
        vm.prank(treasury);      arx.transfer(sink, TREASURY_AMOUNT);
        vm.prank(seedVesting);   arx.transfer(sink, SEED_AMOUNT);

        assertEq(arx.balanceOf(sink), MAX_SUPPLY);
        assertEq(arx.totalSupply(),   MAX_SUPPLY);
    }

    function test_MultipleSequentialTransfers() public {
        uint256 step = 1e6;
        vm.startPrank(treasury);
        for (uint256 i = 0; i < 10; i++) {
            arx.transfer(alice, step);
        }
        vm.stopPrank();
        assertEq(arx.balanceOf(alice),    10 * step);
        assertEq(arx.balanceOf(treasury), TREASURY_AMOUNT - 10 * step);
    }

    function test_BurnAllSupply() public {
        vm.prank(nodeOperators); arx.burn(NODE_OPS_AMOUNT);
        vm.prank(ecosystem);     arx.burn(ECO_AMOUNT);
        vm.prank(teamVesting);   arx.burn(TEAM_AMOUNT);
        vm.prank(ido);           arx.burn(IDO_AMOUNT);
        vm.prank(treasury);      arx.burn(TREASURY_AMOUNT);
        vm.prank(seedVesting);   arx.burn(SEED_AMOUNT);

        assertEq(arx.totalSupply(), 0);
    }

    // ========================================================================
    // FUZZ TESTS
    // ========================================================================

    function testFuzz_Transfer_NoFee(uint256 amount) public {
        amount = bound(amount, 0, TREASURY_AMOUNT);

        uint256 senderBefore   = arx.balanceOf(treasury);
        uint256 receiverBefore = arx.balanceOf(alice);

        vm.prank(treasury);
        arx.transfer(alice, amount);

        assertEq(arx.balanceOf(treasury), senderBefore   - amount);
        assertEq(arx.balanceOf(alice),    receiverBefore + amount);
        assertEq(arx.totalSupply(),       MAX_SUPPLY);
    }

    function testFuzz_Burn_ReducesSupply(uint256 amount) public {
        amount = bound(amount, 0, TREASURY_AMOUNT);
        uint256 supplyBefore = arx.totalSupply();

        vm.prank(treasury);
        arx.burn(amount);

        assertEq(arx.totalSupply(),       supplyBefore - amount);
        assertEq(arx.balanceOf(treasury), TREASURY_AMOUNT - amount);
    }

    function testFuzz_Permit_NoncesAreSequential(uint8 numPermits) public {
        numPermits = uint8(bound(uint256(numPermits), 1, 20));

        for (uint256 i = 0; i < numPermits; i++) {
            uint256 deadline = block.timestamp + 1 hours;
            uint256 nonce    = arx.nonces(alice);
            assertEq(nonce, i);

            bytes32 digest = _permitDigest(alice, bob, 1e6 * (i + 1), nonce, deadline);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
            arx.permit(alice, bob, 1e6 * (i + 1), deadline, v, r, s);
        }

        assertEq(arx.nonces(alice), numPermits);
    }

    // ========================================================================
    // INVARIANT — supply ≤ MAX_SUPPLY at all times
    // ========================================================================

    function invariant_TotalSupplyNeverExceedsMaxSupply() public view {
        assertLe(arx.totalSupply(), MAX_SUPPLY);
    }

    // ========================================================================
    // INTEGRATION — PinkSale-like presale flow
    // ========================================================================

    /// @dev Simulates the full PinkSale interaction pattern: the IDO multisig
    ///      approves a presale contract for the full 150M ARX allocation, the
    ///      presale draws funds via transferFrom, then distributes to
    ///      participants on finalization.
    function test_Integration_PinkSaleFlow() public {
        address pinksale     = makeAddr("pinksaleContract");
        address participant1 = makeAddr("participant1");
        address participant2 = makeAddr("participant2");
        address participant3 = makeAddr("participant3");

        // Step 1: IDO multisig (alloc holder) approves PinkSale for full amount.
        vm.prank(ido);
        arx.approve(pinksale, IDO_AMOUNT);
        assertEq(arx.allowance(ido, pinksale), IDO_AMOUNT);

        // Step 2: PinkSale draws funds via transferFrom (presale "funded").
        vm.prank(pinksale);
        arx.transferFrom(ido, pinksale, IDO_AMOUNT);
        assertEq(arx.balanceOf(ido),         0);
        assertEq(arx.balanceOf(pinksale),    IDO_AMOUNT);
        assertEq(arx.allowance(ido, pinksale), 0);

        // Step 3: PinkSale distributes proportionally to 3 participants
        //          (simulates finalization with claims).
        vm.startPrank(pinksale);
        arx.transfer(participant1, 50_000_000e6);
        arx.transfer(participant2, 60_000_000e6);
        arx.transfer(participant3, 40_000_000e6);
        vm.stopPrank();

        // Step 4: Verify the distribution sums exactly to the presale allocation
        //          (no fees, no shortfall).
        assertEq(arx.balanceOf(participant1), 50_000_000e6);
        assertEq(arx.balanceOf(participant2), 60_000_000e6);
        assertEq(arx.balanceOf(participant3), 40_000_000e6);
        assertEq(arx.balanceOf(pinksale),     0);

        // Step 5: totalSupply unchanged throughout the entire flow.
        assertEq(arx.totalSupply(), MAX_SUPPLY);
    }

    // ========================================================================
    // STRESS — extreme values and rapid sequences
    // ========================================================================

    /// @dev The entire MAX_SUPPLY can transit from one address to another in a
    ///      single call without overflow or precision loss.
    function test_Stress_TransferMaxSupplyBetweenTwoAddresses() public {
        address holder    = makeAddr("holder");
        address newHolder = makeAddr("newHolder");

        // Consolidate all 1B ARX to a single address.
        vm.prank(nodeOperators); arx.transfer(holder, NODE_OPS_AMOUNT);
        vm.prank(ecosystem);     arx.transfer(holder, ECO_AMOUNT);
        vm.prank(teamVesting);   arx.transfer(holder, TEAM_AMOUNT);
        vm.prank(ido);           arx.transfer(holder, IDO_AMOUNT);
        vm.prank(treasury);      arx.transfer(holder, TREASURY_AMOUNT);
        vm.prank(seedVesting);   arx.transfer(holder, SEED_AMOUNT);

        assertEq(arx.balanceOf(holder), MAX_SUPPLY);

        // Single transfer of the entire supply.
        vm.prank(holder);
        arx.transfer(newHolder, MAX_SUPPLY);

        assertEq(arx.balanceOf(holder),    0);
        assertEq(arx.balanceOf(newHolder), MAX_SUPPLY);
        assertEq(arx.totalSupply(),        MAX_SUPPLY);
    }

    /// @dev Permit with type(uint256).max deadline is valid (EIP-2612 places
    ///      no upper bound on deadline beyond the type itself).
    function test_Stress_PermitWithMaxDeadline() public {
        uint256 deadline = type(uint256).max;
        uint256 value    = type(uint256).max; // also max value
        uint256 nonce    = arx.nonces(alice);

        bytes32 digest = _permitDigest(alice, bob, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        arx.permit(alice, bob, value, deadline, v, r, s);

        assertEq(arx.allowance(alice, bob), value);
        assertEq(arx.nonces(alice),         nonce + 1);
    }

    /// @dev approve(spender, type(uint256).max) creates an "infinite" allowance
    ///      that OpenZeppelin v5 does NOT decrement on transferFrom (gas saver).
    ///      This is documented OZ behavior, verified here.
    function test_Stress_ApproveMaxUint256_NoDecrementOnTransferFrom() public {
        vm.prank(treasury);
        arx.approve(alice, type(uint256).max);
        assertEq(arx.allowance(treasury, alice), type(uint256).max);

        // Multiple transferFroms should NOT decrement the infinite allowance.
        vm.startPrank(alice);
        arx.transferFrom(treasury, bob, 1e6);
        arx.transferFrom(treasury, bob, 5e6);
        arx.transferFrom(treasury, bob, 100e6);
        vm.stopPrank();

        assertEq(arx.balanceOf(bob),             106e6);
        assertEq(arx.allowance(treasury, alice), type(uint256).max);
    }

    /// @dev 100 sequential burns with increasing amounts — exercises burn
    ///      bookkeeping under rapid state mutation.
    function test_Stress_MultipleRapidBurns() public {
        uint256 totalBurned = 0;
        uint256 supplyBefore = arx.totalSupply();
        uint256 balanceBefore = arx.balanceOf(treasury);

        vm.startPrank(treasury);
        for (uint256 i = 0; i < 100; i++) {
            uint256 amount = 1_000e6 + (i * 100e6); // 1k, 1.1k, 1.2k, ... 10.9k
            arx.burn(amount);
            totalBurned += amount;
        }
        vm.stopPrank();

        assertEq(arx.balanceOf(treasury), balanceBefore - totalBurned);
        assertEq(arx.totalSupply(),       supplyBefore - totalBurned);
        // Sanity: totalSupply still <= MAX_SUPPLY (decreasing).
        assertLt(arx.totalSupply(), MAX_SUPPLY);
    }

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================

    function _permitDigest(
        address owner_,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner_, spender, value, nonce, deadline)
        );
        return keccak256(
            abi.encodePacked("\x19\x01", arx.DOMAIN_SEPARATOR(), structHash)
        );
    }
}
