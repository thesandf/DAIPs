// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/DAIPMarketplace.sol";

contract DAIPMarketplaceTest is Test {
    DAIPMarketplace marketplace;
    address owner;
    address seller;
    address buyer;

    address nonOwner;

    function setUp() public {
        owner = address(this); // Set the owner to the test contract
        seller = vm.addr(1); // Define a seller
        buyer = vm.addr(2); // Define a buyer
        nonOwner = vm.addr(3); // Define a non-owner address

        marketplace = new DAIPMarketplace(); // Deploy the contract
    }

    // Test for minting DAIP
    function testMintDAIP() public {
        vm.prank(seller); // Simulate the seller calling the function
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);
        assertEq(daipId, 1); // Check if DAIP ID is 1
        assertEq(marketplace.ownerOf(daipId), seller); // Ensure the owner is correct

        (address sellerAddress, uint256 price, address creatorAddr, uint256 royaltyPercentage) = marketplace.daipListings(daipId);
        assertEq(sellerAddress, seller);
        assertEq(price, 0);
        assertEq(creatorAddr, seller);
        assertEq(royaltyPercentage, 5);
    }

    // Test for minting with excessive royalty percentage
    function testMintDAIPWithExcessiveRoyalty() public {
        vm.prank(seller);
        vm.expectRevert(DAIPMarketplace.RoyaltyTooHigh.selector);
        marketplace.mintDAIP("ipfs://sample-uri", 15); // Royalty > 10% should fail
    }

    // Test listing a DAIP
    function testListDAIP() public {
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);

        vm.prank(seller);
        marketplace.listDAIP(daipId, 1 ether); // List DAIP with a price

        (address sellerAddress, uint256 price,,) = marketplace.daipListings(daipId);
        assertEq(sellerAddress, seller);
        assertEq(price, 1 ether);
    }

    // Test listing DAIP by someone other than the owner
    function testListDAIPNotOwner() public {
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);

        vm.prank(buyer); // Not the owner
        vm.expectRevert(DAIPMarketplace.NotOwner.selector);
        marketplace.listDAIP(daipId, 1 ether);
    }

    // Test buying a DAIP
    function testBuyDAIP() public {
        // Arrange: Mint and list DAIP
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);
        vm.prank(seller);
        marketplace.listDAIP(daipId, 1 ether);

        // Act: Set up a buyer and make the purchase
        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        marketplace.buyDAIP{value: 1 ether}(daipId);

        // Assert: Check ownership and platform fee
        assertEq(marketplace.ownerOf(daipId), buyer);

        uint256 platformFee = marketplace.platformFee();

        assertEq(platformFee, 2);  // Adjust this based on the fee percentage

    }

    // Test buying DAIP with incorrect payment
    function testBuyDAIPWithIncorrectPayment() public {
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);

        vm.prank(seller);
        marketplace.listDAIP(daipId, 1 ether);

        vm.prank(buyer);
        vm.deal(buyer, 0.5 ether); // Only 0.5 ether
        vm.expectRevert(DAIPMarketplace.IncorrectPayment.selector);
        marketplace.buyDAIP{value: 0.5 ether}(daipId);
    }

    // Test proposing transfer restriction
    function testProposeTransferRestriction() public {
        // Arrange: Mint a DAIP and list it
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);
         vm.prank(seller);
        marketplace.listDAIP(daipId, 1e18); // List for 1 ETH
        vm.prank(seller);

        marketplace.proposeTransferRestriction(daipId, true);  // Restrict transfers for this DAIP

        // Act: Attempt to buy the DAIP, which should revert due to the restriction
        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        vm.expectRevert(DAIPMarketplace.TransferRestricted.selector);  // Expect the transfer restriction error
        marketplace.buyDAIP{value: 1 ether}(daipId);  // Should revert due to restriction
    }

    // Test updating platform fee
    function testUpdatePlatformFee() public {
        vm.prank(owner);
        marketplace.updatePlatformFee(5); // Set platform fee to 5%

        assertEq(marketplace.platformFee(), 5);

        // Test that platform fee is capped at 10%
        vm.prank(owner);
        vm.expectRevert(DAIPMarketplace.RoyaltyTooHigh.selector);
        marketplace.updatePlatformFee(15); // Fee > 10% should revert
    }

    // Test delisting DAIP
    function testDelistDAIP() public {
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);

        vm.prank(seller);
        marketplace.listDAIP(daipId, 1 ether);

        vm.prank(seller);
        marketplace.delistDAIP(daipId); // Delist DAIP

        (address sellerAddress, uint256 price,,) = marketplace.daipListings(daipId);
        assertEq(sellerAddress, address(0));
        assertEq(price, 0);
    }

    // Test getting user stats
    function testGetUserStats() public {
        vm.prank(seller);
        marketplace.mintDAIP("ipfs://sample-uri-1", 5);

        vm.prank(seller);
        marketplace.mintDAIP("ipfs://sample-uri-2", 5);

        vm.prank(seller);
        marketplace.listDAIP(1, 1 ether); // List first DAIP

        vm.prank(buyer);
        vm.deal(buyer, 1 ether);
        marketplace.buyDAIP{value: 1 ether}(1); // Buyer purchases DAIP 1

        (uint256 minted, uint256 sold) = marketplace.getUserStats(seller);

        assertEq(minted, 2); // Seller minted 2 DAIPs
        assertEq(sold, 1);   // Seller sold 1 DAIP
    }

    // Test delisting all DAIPs
    function testDelistAllDAIPs() public {
        // Arrange: Mint two DAIPs
        vm.prank(seller);
        uint256 daipId1 = marketplace.mintDAIP("ipfs://sample-uri-1", 5);
        vm.prank(seller);
        uint256 daipId2 = marketplace.mintDAIP("ipfs://sample-uri-2", 5);

        // Act: List both DAIPs by the seller
        vm.prank(seller);
        marketplace.listDAIP(daipId1, 1 ether);
        vm.prank(seller);
        marketplace.listDAIP(daipId2, 2 ether);

        // Assert: Only the owner should be able to delist
        vm.prank(seller);
        marketplace.delistDAIP(daipId1);  // Should succeed
        vm.expectRevert(DAIPMarketplace.NotOwner.selector);
        vm.prank(nonOwner);  // Someone else tries to delist
        marketplace.delistDAIP(daipId2);
    }

    // Additional Tests From Upper Script:
    function testBuyDAIPWithPlatformFeeAdjustment() public {
        marketplace.updatePlatformFee(5);  // Set platform fee to 5%
        vm.deal(buyer, 2 ether);

        // Mint and List DAIP
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);
        vm.prank(seller);
        marketplace.listDAIP(daipId, 1e18); // List for 1 ETH

        // Buyer purchases DAIP
        vm.prank(buyer);
        marketplace.buyDAIP{value: 1e18}(daipId);

        // Verify ownership and platform fee
        assertEq(marketplace.ownerOf(daipId), buyer);
        assertEq(marketplace.platformFee(), 5);
    }

    function testBuyDAIPWithTransferRestriction() public {
        // Mint and List DAIP
        vm.prank(seller);
        uint256 daipId = marketplace.mintDAIP("ipfs://sample-uri", 5);
        vm.prank(seller);
        marketplace.proposeTransferRestriction(daipId, true); // Restrict
         vm.prank(seller);
        marketplace.listDAIP(daipId, 1e18); // List for 1 ETH
        vm.deal(buyer, 1e18); // Fund buyer

        // Buyer should not be able to buy due to restriction
        vm.prank(buyer);
        vm.expectRevert(DAIPMarketplace.TransferRestricted.selector);
        marketplace.buyDAIP{value: 1e18}(daipId);
    }
}
