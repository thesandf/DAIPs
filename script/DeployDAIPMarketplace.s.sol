// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {DAIPMarketplace} from "../src/DAIPMarketplace.sol";

contract DeployDAIPMarketplace is Script {
    function run() external {
        // Start broadcast to send transactions to the blockchain
        vm.startBroadcast();

        // Deploy the DAIPMarketplace contract
        DAIPMarketplace marketplace = new DAIPMarketplace();

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Optionally log the deployed contract address
        console.log("DAIPMarketplace deployed at:", address(marketplace));
    }
}
