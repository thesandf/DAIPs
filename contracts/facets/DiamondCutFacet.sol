// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title DiamondCutFacet
 * @dev Implements EIP-2535 DiamondCut for adding/replacing/removing facets.
 */
interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
}

contract DiamondCutFacet is IDiamondCut {
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        // Implementation will be in the main Diamond contract
        revert("DiamondCutFacet: Use Diamond contract for diamondCut");
    }
}
