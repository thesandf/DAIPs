// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {GovernanceToken, DAIPGovernance} from "../src/GovernanceToken.sol";

contract DeployGovernanceToken is Script {
    function run() external {
        vm.startBroadcast();

        GovernanceToken governanceToken = new GovernanceToken();

        console.log("GovernanceToken deployed at:", address(governanceToken));

        DAIPGovernance daipGovernance = new DAIPGovernance(address(governanceToken));

        console.log("DAIPGovernance deployed at:", address(daipGovernance));

        vm.stopBroadcast();
    }
}
