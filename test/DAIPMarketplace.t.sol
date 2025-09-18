// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {DAIPMarketplace} from "src/DAIPMarketplace.sol";
import {GovernanceToken} from "src/GovernanceToken.sol";
import {MockERC20} from "./Mocks/MockERC20.sol";

contract DAIPMarketplaceStatelessTest is Test {
    DAIPMarketplace public marketplace;
    GovernanceToken public governance;
    MockERC20 public token;

    address public admin = address(0xA);
    address public user = address(0xB);

    function setUp() public {
        vm.prank(admin);
        governance = new GovernanceToken();
        token = new MockERC20();

        vm.startPrank(admin);
        marketplace = new DAIPMarketplace(address(governance), address(token));
        vm.stopPrank();

        token.mint(user, 1e20);
    }

    function test_MintDAIP() public {
        vm.prank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        assertEq(marketplace.mintedCount(user), 1);
    }

    function test_ListAndDelistDAIP() public {
        vm.prank(user);
        marketplace.mintDAIP("ipfs://uri", 5);

        vm.prank(user);
        marketplace.listDAIP(1, 1e18);
        (address seller,,,,) = marketplace.daipListings(1);
        assertEq(seller, user);

        vm.prank(user);
        marketplace.delistDAIP(1);
        assertEq(marketplace.isListed(1), false);
    }

    function test_UpdateRoyalty() public {
        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        vm.prank(admin);
        marketplace.updateRoyalty(1, 7);

        (,,, uint256 royalty,) = marketplace.daipListings(1);
        assertEq(royalty, 7);
    }

    function test_UpdatePlatformFee() public {
        vm.prank(admin);
        marketplace.updatePlatformFee(4);
        assertEq(marketplace.platformFee(), 4);
    }

    function test_PlaceBidAndAccept() public {
        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        token.mint(address(this), 2e18);
        token.approve(address(marketplace), 2e18);
        marketplace.placeBid(1, 2e18, block.timestamp + 1 days);

        DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(1);
        assertEq(bids.length, 1);
        assertEq(bids[0].amount, 2e18);
    }

    // function test_WithdrawMyBid() public {
    //     vm.startPrank(user);
    //     marketplace.mintDAIP("ipfs://uri", 5);
    //     marketplace.listDAIP(1, 1e18);
    //     vm.stopPrank();

    //     token.approve(address(marketplace), 2e18);
    //     marketplace.placeBid(1, 2e18, block.timestamp + 1 days);
    //     marketplace.withdrawMyBid(1, 0);

    //     DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(1);
    //     assertEq(bids[0].active, false);
    // }

    function test_UpdateURIAndFreeze() public {
        vm.prank(user);
        marketplace.mintDAIP("ipfs://uri", 5);

        vm.prank(user);
        marketplace.updateTokenURI(1, "ipfs://new");

        vm.prank(user);
        marketplace.freezeMetadata(1);

        (,,,, bool frozen) = marketplace.daipListings(1);
        assertTrue(frozen);
    }

    function test_TransferRestrictionProposal() public {
        vm.prank(user);
        marketplace.mintDAIP("ipfs://uri", 5);

        vm.prank(user);
        marketplace.proposeTransferRestriction(1, true);
        assertTrue(marketplace.restrictedTransfers(1));
    }
}
