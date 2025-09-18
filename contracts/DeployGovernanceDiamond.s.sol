// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
}

contract DeployGovernanceDiamond is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy facets
        address diamondCutFacet = address(new DiamondCutFacet());
        address diamondLoupeFacet = address(new DiamondLoupeFacet());
        address ownershipFacet = address(new OwnershipFacet());
        address governanceTokenFacet = address(new GovernanceTokenFacet());
        address erc20Facet = address(new ERC20Facet());

        // 2. Deploy diamond with DiamondCutFacet
        address diamond = address(new GovernanceDiamond(msg.sender, diamondCutFacet));

        // 3. Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        // GovernanceTokenFacet
        bytes4[] memory govSelectors = new bytes4[](5);
        govSelectors[0] = GovernanceTokenFacet.mintTokens.selector;
        govSelectors[1] = GovernanceTokenFacet.createProposal.selector;
        govSelectors[2] = GovernanceTokenFacet.voteOnProposal.selector;
        govSelectors[3] = GovernanceTokenFacet.executeProposal.selector;
        govSelectors[4] = GovernanceTokenFacet.autoExecuteProposals.selector;
        cuts[0] = IDiamondCut.FacetCut({facetAddress: governanceTokenFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: govSelectors});
        // ERC20Facet
        bytes4[] memory erc20Selectors = new bytes4[](6);
        erc20Selectors[0] = ERC20Facet.name.selector;
        erc20Selectors[1] = ERC20Facet.symbol.selector;
        erc20Selectors[2] = ERC20Facet.totalSupply.selector;
        erc20Selectors[3] = ERC20Facet.balanceOf.selector;
        erc20Selectors[4] = ERC20Facet.transfer.selector;
        erc20Selectors[5] = ERC20Facet.approve.selector;
        cuts[1] = IDiamondCut.FacetCut({facetAddress: erc20Facet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: erc20Selectors});
        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cuts[2] = IDiamondCut.FacetCut({facetAddress: diamondLoupeFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: loupeSelectors});
        // OwnershipFacet
        bytes4[] memory ownerSelectors = new bytes4[](2);
        ownerSelectors[0] = OwnershipFacet.owner.selector;
        ownerSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cuts[3] = IDiamondCut.FacetCut({facetAddress: ownershipFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: ownerSelectors});

        // 4. Register facets with diamondCut
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");

        // 5. Initialize GovernanceTokenFacet (mint initial supply, set roles)
        GovernanceTokenFacet(governanceTokenFacet).initialize(msg.sender);

        vm.stopBroadcast();
    }
}
