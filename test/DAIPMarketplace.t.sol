// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DAIPMarketplace} from "../src/DAIPMarketplace.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MockERC20} from "../test/Mocks/MockERC20.sol";


contract DAIPMarketplaceTest is Test {
    DAIPMarketplace marketplace;
    GovernanceToken governance;
    IERC20 token;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        governance = new GovernanceToken(owner);
        token = IERC20(address(new MockERC20()));
        marketplace = new DAIPMarketplace(address(governance), address(token));
    }

    // function testMintDAIP() public {
    //     uint256 id = marketplace.mintDAIP("ipfs://uri", 5);
    //     assertEq(id, 1);
    //     (DAIPMarketplace.DAIPListing memory listing,,) = marketplace.getDAIPInfoById(id);
    //     assertEq(listing.creator, owner);
    //     assertEq(listing.royaltyPercentage, 5);
    // }

    function testMintDAIPRoyaltyTooHigh() public {
        vm.expectRevert(DAIPMarketplace.RoyaltyTooHigh.selector);
        marketplace.mintDAIP("ipfs://uri", 11);
    }

    function testUpdateAndFreezeMetadata() public {
        uint256 id = marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.updateTokenURI(id, "ipfs://new");
        marketplace.freezeMetadata(id);
        vm.expectRevert("Metadata is frozen");
        marketplace.updateTokenURI(id, "ipfs://fail");
    }

    // function testListAndDelistDAIP() public {
    //     uint256 id = marketplace.mintDAIP("ipfs://uri", 5);
    //     marketplace.listDAIP(id, 100);
    //     (DAIPMarketplace.DAIPListing memory listing,,) = marketplace.getDAIPInfoById(id);
    //     assertEq(listing.price, 100);
    //     marketplace.delistDAIP(id);
    // }

    function testBuyDAIP() public {
        MockERC20(address(token)).mint(user1, 1000);
        uint256 id = marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(id, 100);

        vm.prank(user1);
        MockERC20(address(token)).approve(address(marketplace), 100);
        vm.prank(user1);
        marketplace.buyDAIP(id);

        assertEq(marketplace.ownerOf(id), user1);
    }

    // Add more test functions to cover:
    // - Bidding system (placeBid, acceptBid, withdrawMyBid)
    // - Platform fee update
    // - Royalty update
    // - Governance checks
    // - Transfer restrictions
    // - Fallback and receive reverts
}
