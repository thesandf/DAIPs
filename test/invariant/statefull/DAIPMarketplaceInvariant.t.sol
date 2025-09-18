// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../src/DAIPMarketplace.sol";
import "../../../src/GovernanceToken.sol";
import "../../Mocks/MockERC20.sol";
import "./DAIPMarketplaceHandler.sol";

contract DAIPMarketplaceInvariant is Test {
    DAIPMarketplace public marketplace;
    GovernanceToken public governanceToken;
    MockERC20 public mockToken;
    DAIPMarketplaceHandler public handler;

    address admin = address(0xA);

    function setUp() public {
        mockToken = new MockERC20();

        vm.startPrank(admin);
        governanceToken = new GovernanceToken();
        marketplace = new DAIPMarketplace(address(governanceToken), address(mockToken));

        // Role assignments
        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 LOCKER_ROLE = keccak256("LOCKER_ROLE");
        bytes32 VESTER_ROLE = keccak256("VESTER_ROLE");

        governanceToken.grantRole(MINTER_ROLE, admin);
        governanceToken.grantRole(MINTER_ROLE, address(marketplace));
        governanceToken.grantRole(LOCKER_ROLE, address(marketplace));
        governanceToken.grantRole(VESTER_ROLE, address(marketplace));
        governanceToken.grantRole(ADMIN_ROLE, admin);
        vm.stopPrank();

        handler = new DAIPMarketplaceHandler(marketplace, governanceToken, mockToken);
        targetContract(address(handler));
    }

    function tokenExists(uint256 tokenId) public view returns (bool) {
        try marketplace.ownerOf(tokenId) returns (address owner) {
            return owner != address(0);
        } catch {
            return false;
        }
    }

    function invariant_PlatformFee_WithinBounds() public view {
        assertLe(marketplace.platformFee(), 10);
    }

    function invariant_Royalty_WithinBounds() public view {
        uint256 total = handler.mintedTokenCount();
        for (uint256 i = 0; i < total; i++) {
            uint256 tokenId = handler.mintedTokenIds(i);
            (,,, uint256 royalty,) = marketplace.daipListings(tokenId);
            assertLe(royalty, 10);
        }
    }

    function invariant_ListedDAIPs_HavePrice() public view {
        uint256 count = marketplace.getListedDAIPCount();
        for (uint256 i = 0; i < count; i++) {
            // Note: listedDAIPIds is public so auto getter exists
            uint256 tokenId = marketplace.listedDAIPIds(i);
            if (marketplace.isListed(tokenId)) {
                (, uint256 price,,,) = marketplace.daipListings(tokenId);
                assertGt(price, 0, "Listed DAIP has zero price");
            }
        }
    }

    function invariant_ListedDAIPs_HaveSeller() public view {
        uint256 total = handler.mintedTokenCount();
        for (uint256 i = 0; i < total; i++) {
            uint256 tokenId = handler.mintedTokenIds(i);
            if (marketplace.isListed(tokenId)) {
                (address seller,,,,) = marketplace.daipListings(tokenId);
                assertTrue(seller != address(0), "Listed DAIP has zero seller");
            }
        }
    }

    function invariant_AllDAIPs_HaveCreator() public view {
        uint256 total = handler.mintedTokenCount();
        for (uint256 i = 0; i < total; i++) {
            uint256 tokenId = handler.mintedTokenIds(i);
            if (!tokenExists(tokenId)) continue; // 🔐 ✅
            (,, address creator,,) = marketplace.daipListings(tokenId);
            assertTrue(creator != address(0), "DAIP has no creator");
        }
    }

    function invariant_HighestBid_IsActive() public view {
        uint256 total = handler.mintedTokenCount();
        for (uint256 i = 0; i < total; i++) {
            uint256 tokenId = handler.mintedTokenIds(i);
            if (!tokenExists(tokenId)) continue;

            DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(tokenId);
            if (bids.length > 0) {
                uint256 idx = marketplace.highestBidIndex(tokenId);
                if (idx < bids.length) {
                    assertTrue(bids[idx].active, "Highest bid is not active");
                }
            }
        }
    }

    function invariant_Bids_NonZeroAmount() public view {
        uint256 total = handler.mintedTokenCount();
        for (uint256 i = 0; i < total; i++) {
            uint256 tokenId = handler.mintedTokenIds(i);
            DAIPMarketplace.Bid[] memory bids = marketplace.getAllBid(tokenId);
            for (uint256 j = 0; j < bids.length; j++) {
                assertGt(bids[j].amount, 0, "Bid has zero amount");
            }
        }
    }
}
