// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {DAIPMarketplace} from "src/DAIPMarketplace.sol";
import {GovernanceToken} from "src/GovernanceToken.sol";
import {MockERC20} from "../../Mocks/MockERC20.sol";

contract DAIPMarketplace_FuzzTest is Test {
    DAIPMarketplace public marketplace;
    GovernanceToken public governance;
    MockERC20 public token;

    address public admin = address(0xA);
    address public user = address(0xB);

    function setUp() public {
        vm.startPrank(admin);
        governance = new GovernanceToken();
        token = new MockERC20();

        marketplace = new DAIPMarketplace(address(governance), address(token));
        vm.stopPrank();

        token.mint(user, 1e20);
    }

    function testFuzz_MintDAIP_WithBoundedRoyalty(string memory uri, uint256 royalty) public {
        royalty = bound(royalty, 1, 10); // Royalty range: 1–10
        vm.assume(bytes(uri).length > 0);

        vm.prank(user);
        marketplace.mintDAIP(uri, royalty);

        assertEq(marketplace.balanceOf(user), 1);
    }

    function testFuzz_ListDAIP_WithPrice(uint256 price) public {
        price = bound(price, 1, 1e18);
        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, price);
        vm.stopPrank();

        (, uint256 storedPrice,,,) = marketplace.daipListings(1);
        assertEq(storedPrice, price);
    }

    function testFuzz_UpdateRoyalty(uint256 royalty) public {
        royalty = bound(royalty, 1, 10);
        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        vm.prank(admin);
        marketplace.updateRoyalty(1, royalty);

        (,,, uint256 storedRoyalty,) = marketplace.daipListings(1);
        assertEq(storedRoyalty, royalty);
    }

    function testFuzz_PlaceBid(uint256 amount, uint256 expirationOffset) public {
        amount = bound(amount, 1e6, 2e18); // max = balance
        expirationOffset = bound(expirationOffset, 1, 30 days);
        uint256 expiration = block.timestamp + expirationOffset;

        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        token.mint(address(this), 2e18);
        token.approve(address(marketplace), 2e18);

        vm.assume(amount <= 2e18);

        marketplace.placeBid(1, amount, expiration);

        DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(1);
        assertEq(bids.length, 1);
        assertEq(bids[0].amount, amount);
        assertEq(bids[0].expiration, expiration);
    }

    function testFuzz_AcceptBid(uint256 amount) public {
        amount = bound(amount, 1e18, 3e18);

        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        token.mint(address(this), 3e18);
        token.approve(address(marketplace), 3e18);

        vm.assume(amount >= 1e18 && amount <= 3e18);
        vm.assume(amount != 0);

        marketplace.placeBid(1, amount, block.timestamp + 1 days);

        vm.startPrank(user);
        marketplace.acceptBid(1);
        vm.stopPrank();

        (address seller, uint256 price,,,) = marketplace.daipListings(1);
        (,, address buyer) = marketplace.getDAIPInfoById(1);

        assertEq(seller, address(0));
        assertEq(buyer, address(this));
        assertEq(price, 0);
    }

    function testFuzz_WithdrawMyBid(uint256 amount) public {
        amount = bound(amount, 1e6, 1e20);

        vm.startPrank(user);
        marketplace.mintDAIP("ipfs://uri", 5);
        marketplace.listDAIP(1, 1e18);
        vm.stopPrank();

        token.mint(address(this), 2e20);
        token.approve(address(marketplace), 2e20);
        marketplace.placeBid(1, amount, block.timestamp + 1 days);

        vm.warp(block.timestamp + 2 days); // Ensure bid is expired
        marketplace.withdrawMyBid(1, 0);

        DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(1);
        assertEq(bids[0].active, false);
    }

    function testFuzz_UpdateTokenURI(string memory newURI) public {
        vm.assume(bytes(newURI).length > 0);

        vm.prank(user);
        marketplace.mintDAIP("ipfs://original", 5);

        vm.prank(user);
        marketplace.updateTokenURI(1, newURI);
        (, string memory uri,) = marketplace.getDAIPInfoById(1);
        assertEq(uri, newURI, "Token URI should be updated");
    }
}
