// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../DiamondStorage.sol";
import "../interfaces/IDiamondLoupe.sol";

contract DiamondLoupeFacet is IDiamondLoupe {
    using DiamondStorage for DiamondStorage.DiamondStorageStruct;

    function facets() external view override returns (Facet[] memory) {
        DiamondStorage.DiamondStorageStruct storage ds = DiamondStorage.diamondStorage();
        Facet[] memory result = new Facet[](ds.facetAddresses.length);

        for (uint256 i = 0; i < ds.facetAddresses.length; i++) {
            address facetAddr = ds.facetAddresses[i];
            bytes4[] memory selectors = ds.facetFunctionSelectors[facetAddr];
            result[i] = Facet({facetAddress: facetAddr, functionSelectors: selectors});
        }

        return result;
    }

    function facetFunctionSelectors(address facet) external view override returns (bytes4[] memory) {
        return DiamondStorage.diamondStorage().facetFunctionSelectors[facet];
    }

    function facetAddresses() external view override returns (address[] memory) {
        return DiamondStorage.diamondStorage().facetAddresses;
    }

    function facetAddress(bytes4 selector) external view override returns (address) {
        return DiamondStorage.diamondStorage().selectorToFacetAndPosition[selector].facetAddress;
    }
}
