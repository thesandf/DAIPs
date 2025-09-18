// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./facets/DiamondCutFacet.sol";
import "./facets/DiamondLoupeFacet.sol";
import "./facets/OwnershipFacet.sol";
import "./DiamondStorage.sol";

/**
 * @title GovernanceDiamond
 * @dev Minimal Diamond Standard proxy for GovernanceToken facets.
 *
 * - Add facets (GovernanceTokenFacet, DiamondCutFacet, etc.) via diamondCut.
 * - All logic is routed via fallback to the correct facet.
 * - Storage must be managed via DiamondStorage for upgradeability.
 */
contract GovernanceDiamond is IDiamondCut, IDiamondLoupe, IOwnershipFacet {
    using DiamondStorage for DiamondStorage.DiamondStorageStruct;

    constructor(address _contractOwner, address _diamondCutFacet) {
        DiamondStorage.DiamondStorageStruct storage ds = DiamondStorage.diamondStorage();
        ds.contractOwner = _contractOwner;
        // Add DiamondCutFacet to selectors
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        ds.facetFunctionSelectors[_diamondCutFacet] = selectors;
        ds.selectorToFacetAndPosition[IDiamondCut.diamondCut.selector] = DiamondStorage.FacetAddressAndSelectorPosition({
            facetAddress: _diamondCutFacet,
            selectorPosition: 0
        });
        ds.facetAddresses.push(_diamondCutFacet);
    }

    fallback() external payable {
        DiamondStorage.DiamondStorageStruct storage ds = DiamondStorage.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}

    // OwnershipFacet
    function owner() external view override returns (address) {
        return DiamondStorage.diamondStorage().contractOwner;
    }
    function transferOwnership(address newOwner) external override {
        require(msg.sender == DiamondStorage.diamondStorage().contractOwner, "Diamond: Not owner");
        DiamondStorage.diamondStorage().contractOwner = newOwner;
    }
}
