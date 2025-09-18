// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../DiamondStorage.sol";
import "../interfaces/IOwnershipFacet.sol";

contract OwnershipFacet is IOwnershipFacet {
    function owner() external view override returns (address) {
        return DiamondStorage.diamondStorage().contractOwner;
    }

    function transferOwnership(address newOwner) external override {
        DiamondStorage.DiamondStorageStruct storage ds = DiamondStorage.diamondStorage();
        require(msg.sender == ds.contractOwner, "Diamond: Not contract owner");
        ds.contractOwner = newOwner;
    }
}
