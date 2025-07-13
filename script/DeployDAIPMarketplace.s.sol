// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {DAIPMarketplace} from "../src/DAIPMarketplace.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

/// @notice Script for deploying the DAIPMarketplace contract
contract DeployDAIPMarketplace is Script {
    function run(address governanceToken, address usdc) external {
        // Start broadcast to send transactions to the blockchain
        vm.startBroadcast();

        GovernanceToken governanceToken = new GovernanceToken();

        // Deploy the DAIPMarketplace contract with the provided governanceToken and USDC addresses
        DAIPMarketplace marketplace = new DAIPMarketplace(governanceToken, usdc);

        // Log the deployed contract address
        console.log("DAIPMarketplace deployed at:", address(marketplace));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
