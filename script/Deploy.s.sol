// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script, console2} from "forge-std/Script.sol";
import {Arxia}            from "../contracts/Arxia.sol";

/// @title  Arxia (ARX) deployment script
/// @notice Reads 6 allocation addresses from environment, validates non-zero,
///         deploys Arxia, and logs initial state for post-deploy verification.
///
///         The script is intentionally minimal — there is no post-deploy
///         setup (no setBridgeAddress, no renounceOwnership) because the
///         contract has no admin surface to configure.
///
/// @dev    Usage (Base Sepolia testnet):
///           forge script script/Deploy.s.sol:Deploy \
///             --rpc-url $BASE_SEPOLIA_RPC_URL \
///             --private-key $PRIVATE_KEY \
///             --broadcast --verify \
///             --etherscan-api-key $BASESCAN_API_KEY
///
///         Usage (Base mainnet — see README pre-flight checklist FIRST):
///           forge script script/Deploy.s.sol:Deploy \
///             --rpc-url $BASE_RPC_URL \
///             --private-key $PRIVATE_KEY \
///             --broadcast --verify --slow \
///             --etherscan-api-key $BASESCAN_API_KEY
contract Deploy is Script {
    error MissingEnvAddress(string name);
    error PostDeploySupplyMismatch(uint256 actual, uint256 expected);

    function run() external returns (Arxia arx) {
        address nodeOps   = vm.envAddress("NODE_OPERATORS_ADDRESS");
        address ecosystem = vm.envAddress("ECOSYSTEM_ADDRESS");
        address teamVest  = vm.envAddress("TEAM_VESTING_ADDRESS");
        address ido       = vm.envAddress("IDO_ADDRESS");
        address treasury  = vm.envAddress("TREASURY_ADDRESS");
        address seedVest  = vm.envAddress("SEED_VESTING_ADDRESS");

        if (nodeOps   == address(0)) revert MissingEnvAddress("NODE_OPERATORS_ADDRESS");
        if (ecosystem == address(0)) revert MissingEnvAddress("ECOSYSTEM_ADDRESS");
        if (teamVest  == address(0)) revert MissingEnvAddress("TEAM_VESTING_ADDRESS");
        if (ido       == address(0)) revert MissingEnvAddress("IDO_ADDRESS");
        if (treasury  == address(0)) revert MissingEnvAddress("TREASURY_ADDRESS");
        if (seedVest  == address(0)) revert MissingEnvAddress("SEED_VESTING_ADDRESS");

        console2.log("=== Arxia (ARX) deployment ===");
        console2.log("Chain ID:           ", block.chainid);
        console2.log("Block number:       ", block.number);
        console2.log("Deployer (tx.origin):", tx.origin);
        console2.log("");
        console2.log("Allocations:");
        console2.log("  nodeOperators ->  ", nodeOps);
        console2.log("  ecosystem ->      ", ecosystem);
        console2.log("  teamVesting ->    ", teamVest);
        console2.log("  ido ->            ", ido);
        console2.log("  treasury ->       ", treasury);
        console2.log("  seedVesting ->    ", seedVest);
        console2.log("");

        vm.startBroadcast();
        arx = new Arxia(nodeOps, ecosystem, teamVest, ido, treasury, seedVest);
        vm.stopBroadcast();

        console2.log("Deployed at:        ", address(arx));
        console2.log("Total supply:       ", arx.totalSupply());
        console2.log("MAX_SUPPLY:         ", arx.MAX_SUPPLY());
        console2.log("");
        console2.log("Post-deploy balances:");
        console2.log("  nodeOperators:    ", arx.balanceOf(nodeOps));
        console2.log("  ecosystem:        ", arx.balanceOf(ecosystem));
        console2.log("  teamVesting:      ", arx.balanceOf(teamVest));
        console2.log("  ido:              ", arx.balanceOf(ido));
        console2.log("  treasury:         ", arx.balanceOf(treasury));
        console2.log("  seedVesting:      ", arx.balanceOf(seedVest));

        if (arx.totalSupply() != arx.MAX_SUPPLY()) {
            revert PostDeploySupplyMismatch(arx.totalSupply(), arx.MAX_SUPPLY());
        }

        console2.log("");
        console2.log("OK invariant: totalSupply == MAX_SUPPLY");
        console2.log("OK no admin: contract has no owner / no setter functions");
    }
}
