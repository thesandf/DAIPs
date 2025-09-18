// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../src/DAIPMarketplace.sol";
import "../../../src/GovernanceToken.sol";
import "../../Mocks/MockERC20.sol";

contract DAIPMarketplaceHandler is Test {
    DAIPMarketplace public marketplace;
    GovernanceToken public governanceToken;
    MockERC20 public mockToken;

    address[] public users;
    uint256[] public mintedTokenIds;

    address admin = address(0xA);
    address governanceAdmin = address(0xB);

    constructor(DAIPMarketplace _marketplace, GovernanceToken _governanceToken, MockERC20 _mockToken) {
        marketplace = _marketplace;
        governanceToken = _governanceToken;
        mockToken = _mockToken;

        // Setup test users
        for (uint160 i = 1; i <= 5; i++) {
            users.push(address(i));
        }

        // Mint governance & ERC20 tokens and approve spending
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            mockToken.mint(user, 1e21);
            vm.prank(user);
            mockToken.approve(address(marketplace), type(uint256).max);

            vm.startPrank(admin);
            governanceToken.mintTokens(user, 1e21);
            vm.stopPrank();
        }

        // Setup governance admin
        vm.startPrank(admin);
        governanceToken.grantRole(governanceToken.ADMIN_ROLE(), governanceAdmin);
        vm.stopPrank();
    }

    function mintDAIP(uint256 userIndex, string memory uri, uint256 royalty) public {
        royalty = bound(royalty, 0, 10);
        address user = users[userIndex % users.length];
        vm.prank(user);

        try marketplace.mintDAIP(uri, royalty) returns (uint256 tokenId) {
            mintedTokenIds.push(tokenId);
        } catch {}
    }

    function listDAIP(uint256 userIndex, uint256 tokenId, uint256 price) public {
        address user = users[userIndex % users.length];

        if (price == 0 || marketplace.ownerOf(tokenId) != user) return;

        vm.prank(user);
        try marketplace.listDAIP(tokenId, price) {} catch {}
    }

    function delistDAIP(uint256 userIndex, uint256 tokenId) public {
        address user = users[userIndex % users.length];
        if (marketplace.ownerOf(tokenId) != user) return;

        vm.prank(user);
        try marketplace.delistDAIP(tokenId) {} catch {}
    }

    function unlistDAIP(uint256 userIndex, uint256 tokenId) public {
        address user = users[userIndex % users.length];
        if (marketplace.ownerOf(tokenId) != user) return;

        vm.prank(user);
        try marketplace.unlistDAIP(tokenId) {} catch {}
    }

    function delistMultipleDAIPs(uint256 userIndex) public {
        address user = users[userIndex % users.length];
        uint256 count = mintedTokenIds.length;

        uint256[] memory tokenIds = new uint256[](count);
        uint256 j = 0;

        for (uint256 i = 0; i < count && j < count; i++) {
            uint256 id = mintedTokenIds[i];
            if (marketplace.ownerOf(id) == user) {
                tokenIds[j++] = id;
            }
        }

        vm.prank(user);
        try marketplace.delistMultipleDAIPs(tokenIds) {} catch {}
    }

    function updateTokenURI(uint256 userIndex, uint256 tokenId, string memory newURI) public {
        address user = users[userIndex % users.length];
        (,, address creator,,) = marketplace.daipListings(tokenId);

        if (user != creator) return;

        vm.prank(user);
        try marketplace.updateTokenURI(tokenId, newURI) {} catch {}
    }

    function freezeMetadata(uint256 userIndex, uint256 tokenId) public {
        address user = users[userIndex % users.length];
        (,, address creator,,) = marketplace.daipListings(tokenId);

        if (user != creator) return;

        vm.prank(user);
        try marketplace.freezeMetadata(tokenId) {} catch {}
    }

    function proposeTransferRestriction(uint256 userIndex, uint256 tokenId, bool restrict) public {
        address user = users[userIndex % users.length];
        if (marketplace.ownerOf(tokenId) != user) return;

        vm.prank(user);
        try marketplace.proposeTransferRestriction(tokenId, restrict) {} catch {}
    }

    function buyDAIP(uint256 userIndex, uint256 tokenId) public {
        address user = users[userIndex % users.length];

        (, uint256 price,,,) = marketplace.daipListings(tokenId);
        if (!marketplace.isListed(tokenId)) return;
        if (mockToken.balanceOf(user) < price) return;

        vm.prank(user);
        try marketplace.buyDAIP(tokenId) {} catch {}
    }

    function placeBid(uint256 userIndex, uint256 tokenId, uint256 amount, uint256 expiration) public {
        address user = users[userIndex % users.length];
        if (amount == 0 || expiration <= block.timestamp) return;

        vm.prank(user);
        try marketplace.placeBid(tokenId, amount, expiration) {} catch {}
    }

    function withdrawMyBid(uint256 userIndex, uint256 tokenId, uint256 bidIndex) public {
        address user = users[userIndex % users.length];

        vm.prank(user);
        try marketplace.withdrawMyBid(tokenId, bidIndex) {} catch {}
    }

    function acceptBid(uint256 userIndex, uint256 tokenId) public {
        address user = users[userIndex % users.length];
        if (marketplace.ownerOf(tokenId) != user) return;

        vm.prank(user);
        try marketplace.acceptBid(tokenId) {} catch {}
    }

    function updatePlatformFee(uint256 userIndex, uint256 fee) public {
        address user = users[userIndex % users.length];
        if (user != owner()) return;

        vm.prank(user);
        try marketplace.updatePlatformFee(fee) {} catch {}
    }

    function updateRoyalty(uint256 tokenId, uint256 royalty) public {
        if (msg.sender != governanceAdmin) return;

        royalty = bound(royalty, 0, 10);
        vm.prank(governanceAdmin);
        try marketplace.updateRoyalty(tokenId, royalty) {} catch {}
    }

    function getMintedTokenIds() external view returns (uint256[] memory) {
        return mintedTokenIds;
    }

    function mintedTokenCount() external view returns (uint256) {
        return mintedTokenIds.length;
    }

    function owner() internal view returns (address) {
        return marketplace.owner();
    }
}
