// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

contract DeployGovernanceToken is Script {
    function run() external {
        vm.startBroadcast();

        GovernanceToken governanceToken = new GovernanceToken();

        console.log("GovernanceToken deployed at:", address(governanceToken));

        vm.stopBroadcast();
    }
}
