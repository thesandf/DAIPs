// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DAIPMarketplace is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIds;
    uint256 public platformFee = 2; // Default platform fee is 2%

    struct DAIPListing {
        address seller;
        uint256 price;
        address creator;
        uint256 royaltyPercentage;
    }

    mapping(uint256 => DAIPListing) public daipListings;
    mapping(uint256 => bool) public restrictedTransfers;

    event DAIPMinted(uint256 indexed daipId, address indexed creator, string tokenURI);
    event DAIPListed(uint256 indexed daipId, address indexed seller, uint256 price);
    event DAIPSold(uint256 indexed daipId, address indexed buyer, uint256 price);
    event DAIPDelisted(uint256 indexed daipId);

    // Custom errors
    error NotOwner();
    error PriceTooLow();
    error IncorrectPayment();
    error TransferRestricted();
    error RoyaltyTooHigh();

    constructor() ERC721("Decentralized IP", "DAIP") Ownable(msg.sender) {}

    function mintDAIP(string memory _tokenURI, uint256 _royaltyPercentage) external returns (uint256) {
        if (_royaltyPercentage > 10) revert RoyaltyTooHigh(); // Max royalty is 10%

        _tokenIds += 1; // Increment the token ID
        uint256 newItemId = _tokenIds;

        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        daipListings[newItemId] = DAIPListing(msg.sender, 0, msg.sender, _royaltyPercentage);

        emit DAIPMinted(newItemId, msg.sender, _tokenURI);
        return newItemId;
    }

    function listDAIP(uint256 _daipId, uint256 _price) external {
        if (ownerOf(_daipId) != msg.sender) revert NotOwner();
        if (_price == 0) revert PriceTooLow();

        daipListings[_daipId].seller = msg.sender;
        daipListings[_daipId].price = _price;

        emit DAIPListed(_daipId, msg.sender, _price);
    }

    function getListingPrice(uint256 _daipId) external view returns (uint256) {
        return daipListings[_daipId].price;
    }

    function buyDAIP(uint256 _daipId) external payable nonReentrant {
        DAIPListing memory listing = daipListings[_daipId];

        if (listing.price == 0) revert PriceTooLow();
        if (msg.value < listing.price) revert IncorrectPayment(); // Revert if payment is lower than the listing price
        if (restrictedTransfers[_daipId]) revert TransferRestricted();

        uint256 platformCut = (listing.price * platformFee) / 100;
        uint256 royalty = (listing.price * listing.royaltyPercentage) / 100;
        uint256 sellerProceeds = listing.price - platformCut - royalty;

        _transfer(listing.seller, msg.sender, _daipId);

        // Transfer the appropriate funds to the seller and creator
        payable(listing.seller).transfer(sellerProceeds);
        if (royalty > 0) {
            payable(listing.creator).transfer(royalty);
        }

        // If the buyer sent more than the listing price, refund the excess
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }

        emit DAIPSold(_daipId, msg.sender, listing.price);
    }

    function proposeTransferRestriction(uint256 _daipId, bool restrictTransfer) external {
        if (ownerOf(_daipId) != msg.sender) revert NotOwner();
        setTransferRestriction(_daipId, restrictTransfer);
    }

    function setTransferRestriction(uint256 _daipId, bool _restrictTransfer) internal {
        restrictedTransfers[_daipId] = _restrictTransfer;
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        if (_newFee > 10) revert RoyaltyTooHigh(); // Max platform fee is 10%
        platformFee = _newFee;
    }

    function delistDAIP(uint256 _daipId) external {
        if (ownerOf(_daipId) != msg.sender) revert NotOwner();
        if (daipListings[_daipId].price == 0) revert PriceTooLow();

        delete daipListings[_daipId];

        emit DAIPDelisted(_daipId);
    }

    // delet all DAIP that the owner can mint.
    function delistAllDAIPs() external {
        uint256 totalDAIPs = _tokenIds;

        for (uint256 i = 1; i <= totalDAIPs; i++) {
            if (ownerOf(i) == msg.sender && daipListings[i].price > 0) {
                delete daipListings[i];
                emit DAIPDelisted(i);
            }
        }
    }

    function getUserStats(address _user) external view returns (uint256 minted, uint256 sold) {
        uint256 totalDAIPs = _tokenIds;
        uint256 mintedCount = 0;
        uint256 soldCount = 0;

        for (uint256 i = 1; i <= totalDAIPs; i++) {
            if (daipListings[i].seller == _user) {
                mintedCount++;
            }
            if (ownerOf(i) != _user) {
                soldCount++;
            }
        }

        return (mintedCount, soldCount);
    }
}
