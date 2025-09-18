// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

/// @title DAIP Marketplace Contract
/// @author THE SANDF
/// @notice Marketplace for minting, listing, bidding, and selling NFTs representing decentralized intellectual property
/// @dev Integrates governance-based access control and royalty logic, based on ERC721 and ERC20 standards

/// @dev Access Control:
/// onlyOwner`: Protocol owner (platform-level settings)
/// onlyGovernanceAdmin`: DAO or governance contract role (metadata, royalties)

interface IGovernanceToken {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function ADMIN_ROLE() external view returns (bytes32);
}

contract DAIPMarketplace is ERC721, ERC2981, Ownable, ReentrancyGuard {
    /// @dev Required for multiple inheritance (ERC721, ERC2981)
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    // ========== State Variables ==========

    uint256 private _tokenIds;

    mapping(uint256 tokenId => string) private _tokenURIs;

    uint256[] public listedDAIPIds; // Track currently listed

    /// @notice Fee percentage (e.g. 2%) taken by platform on each sale
    uint256 public platformFee = 2;

    /// @notice Address of the governance contract used for role checks
    address public governanceContract;

    /// @notice Accepted ERC20 token for purchases and bids (e.g. USDC)
    IERC20 public acceptedToken;

    /// @notice Minimum percentage increment required for new bids
    uint256 public constant MIN_BID_INCREMENT_PERCENT = 5;

    /// @notice Listing details for each DAIP NFT
    struct DAIPListing {
        address seller;
        uint256 price;
        address creator;
        uint256 royaltyPercentage;
        bool metadataFrozen;
    }

    /// @notice Structure of a bid placed on a DAIP token
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 expiration;
        bool isEscrowed;
        bool active; // false if withdrawn or accepted
    }

    /// @notice Stores metadata and listing info for each DAIP token by ID
    mapping(uint256 => DAIPListing) public daipListings;
    /// @notice All bids placed for each DAIP token ID (history of bids)
    mapping(uint256 => Bid[]) public daipBids;
    /// @notice Index of the currently highest active bid in the `daipBids` array per DAIP token ID
    mapping(uint256 => uint256) public highestBidIndex;
    /// @notice Tracks whether transfers are restricted for a specific DAIP token (e.g., for licensing control)
    mapping(uint256 => bool) public restrictedTransfers;
    /// @notice Number of DAIP tokens minted by each address (used for creator stats)
    mapping(address => uint256) public mintedCount;
    /// @notice Number of DAIP tokens listed by each address (used for creator stats)
    mapping(address => uint256) public listedCount;
    /// @notice Number of DAIP tokens sold/transferred by each address (used for seller stats)
    mapping(address => uint256) public soldCount;
    /// @notice Tracks whether a DAIP token is currently listed for sale
    mapping(uint256 => bool) public isListed;

    // ========== Events ==========

    event DAIPMinted(uint256 indexed daipId, address indexed creator, string tokenURI);
    event DAIPListed(uint256 indexed daipId, address indexed seller, uint256 price);
    event DAIPSold(uint256 indexed daipId, address indexed buyer, uint256 price);
    event DAIPDelisted(uint256 indexed daipId);
    event DAIPUnlist(uint256 indexed daipId, address indexed unlistBy);
    event BidPlaced(uint256 indexed daipId, address indexed bidder, uint256 amount, uint256 expiration);
    event BidAccepted(uint256 indexed daipId, address indexed bidder, uint256 amount);
    event BidRefunded(uint256 indexed daipId, address indexed bidder);
    event PlatformFeeUpdated(uint256 newFee);
    event RoyaltyUpdated(uint256 daipId, uint256 newRoyalty);
    event MetadataUpdated(uint256 indexed daipId, string newURI);
    event Metadata_Frozen(uint256 indexed daipId);

    // ========== Errors ==========

    error NotGovernanceAdmin();
    error NotOwner();
    error NotCreator();
    error MetadataFrozen();
    error MetadataAlreadyFrozen();
    error PriceTooLow();
    error NotSeller();
    error NotListed();
    error ZeroBid();
    error InvalidExpiration();
    error HighestBidInactive();
    error InsufficientBalance();
    error TransferFailed();
    error BidTooLow();
    error EscrowTransferFailed();
    error NoValidBid();
    error SellerTransferFailed();
    error RoyaltyTransferFailed();
    error NotBidder();
    error BidInactive();
    error CannotWithdrawActiveTopBid();
    error IncorrectPayment();
    error TransferRestricted();
    error RoyaltyTooHigh();
    error NoBids();
    error NotAuthorized();
    error BidExpired();
    error FallbackNotSupported();
    error ETHNotAccepted();

    /// @notice Initializes the DAIP Marketplace
    /// @param _governanceContract Address of the governance contract (with roles)
    /// @param _acceptedToken ERC20 token accepted for transactions (e.g., USDC)

    constructor(address _governanceContract, address _acceptedToken)
        ERC721("Decentralized IP", "DAIP")
        Ownable(msg.sender)
    {
        governanceContract = _governanceContract;
        acceptedToken = IERC20(_acceptedToken);
    }

    // ========== Modifiers ==========

    /// @dev Restricts access to governance admins
    modifier onlyGovernanceAdmin() {
        if (
            !IGovernanceToken(governanceContract).hasRole(IGovernanceToken(governanceContract).ADMIN_ROLE(), msg.sender)
        ) {
            revert NotGovernanceAdmin();
        }
        _;
    }

    /// @dev Restricts access to current NFT owner
    modifier onlyOwnerOf(uint256 _tokenId) {
        if (ownerOf(_tokenId) != msg.sender) revert NotOwner();
        _;
    }

    // ========== Core Functions ==========

    /// @notice Mint a new DAIP NFT
    /// @param _tokenURI Metadata URI
    /// @param _royaltyPercentage Percentage of royalties (max 10%)
    /// @return ID of the newly minted token
    function mintDAIP(string memory _tokenURI, uint256 _royaltyPercentage) external nonReentrant returns (uint256) {
        if (_royaltyPercentage > 10) revert RoyaltyTooHigh();

        _tokenIds++;
        uint256 newItemId = _tokenIds;

        _safeMint(msg.sender, newItemId);
        _setTokenRoyalty(newItemId, msg.sender, uint96(_royaltyPercentage * 100)); // 5% → 500
        _setTokenURI(newItemId, _tokenURI);

        daipListings[newItemId] = DAIPListing(msg.sender, 0, msg.sender, _royaltyPercentage, false);
        emit DAIPMinted(newItemId, msg.sender, _tokenURI);
        mintedCount[msg.sender]++;
        return newItemId;
    }

    /// @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
    ///  Emits {IERC4906-MetadataUpdate}.
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        _tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdated(tokenId, _tokenURI);
    }

    /// @notice Updates token URI
    /// @dev Only if metadata is not frozen
    /// @param _daipId Token ID
    /// @param _newURI New metadata URI
    function updateTokenURI(uint256 _daipId, string memory _newURI) external {
        DAIPListing storage listing = daipListings[_daipId];

        if (msg.sender != listing.creator) revert NotCreator();
        if (listing.metadataFrozen) revert MetadataFrozen();

        _setTokenURI(_daipId, _newURI);
        emit MetadataUpdated(_daipId, _newURI);
    }

    /// @notice Freezes metadata permanently
    /// @param _daipId Token ID to freeze
    function freezeMetadata(uint256 _daipId) external {
        DAIPListing storage listing = daipListings[_daipId];

        if (msg.sender != listing.creator) revert NotCreator();
        if (listing.metadataFrozen) revert MetadataAlreadyFrozen();

        listing.metadataFrozen = true;
        emit Metadata_Frozen(_daipId);
    }

    /// @notice List an NFT for sale
    /// @param _daipId Token ID
    /// @param _price Sale price
    function listDAIP(uint256 _daipId, uint256 _price) external onlyOwnerOf(_daipId) {
        if (_price == 0) revert PriceTooLow();
        if (!isListed[_daipId]) {
            listedDAIPIds.push(_daipId);
            isListed[_daipId] = true;
        }
        daipListings[_daipId].seller = msg.sender;
        daipListings[_daipId].price = _price;
        listedCount[msg.sender]++;
        emit DAIPListed(_daipId, msg.sender, _price);
    }

    /// @notice Unlists a DAIP internal function
    /// @param _daipId Token ID to unlist
    /// q
    function _unlistDAIP(uint256 _daipId) internal {
        daipListings[_daipId].price = 0;
        daipListings[_daipId].seller = address(0);
        isListed[_daipId] = false;
        emit DAIPUnlist(_daipId, msg.sender);
    }

    /// @notice Unlists a DAIP from only by seller
    /// @param _daipId Token ID to unlist
    function unlistDAIP(uint256 _daipId) external {
        if (daipListings[_daipId].seller != msg.sender) revert NotSeller();
        _unlistDAIP(_daipId);
    }

    /// @notice Purchase a listed DAIP token at its fixed listing price
    /// @dev Transfers funds to seller and creator, updates sale count, and transfers the token to buyer
    /// @param _daipId The ID of the DAIP token being purchased
    function buyDAIP(uint256 _daipId) external nonReentrant {
        if (!isListed[_daipId]) revert NotListed();

        DAIPListing memory listing = daipListings[_daipId];
        if (listing.price == 0) revert PriceTooLow();

        // Reject the purchase if the token has restricted transfers
        if (restrictedTransfers[_daipId]) revert TransferRestricted();

        // Calculate platform and royalty fees from the total price
        uint256 platformCut = (listing.price * platformFee) / 100;
        uint256 royalty = (listing.price * listing.royaltyPercentage) / 100;

        // Calculate the final amount seller receives
        uint256 sellerProceeds = listing.price - platformCut - royalty;

        // Transfer total amount from buyer to contract & Transfer proceeds to seller
        // Check balance before trying to transfer
        if (acceptedToken.balanceOf(msg.sender) < listing.price) revert InsufficientBalance();

        // Safe transfers with return value checks
        bool success;

        success = acceptedToken.transferFrom(msg.sender, address(this), listing.price);
        if (!success) revert TransferFailed();

        success = acceptedToken.transfer(listing.seller, sellerProceeds);
        if (!success) revert TransferFailed();

        if (royalty > 0) {
            success = acceptedToken.transfer(listing.creator, royalty);
            if (!success) revert TransferFailed();
        }

        // Transfer DAIP ownership to the buyer
        _transfer(listing.seller, msg.sender, _daipId);

        // Update internal sale count for analytics
        soldCount[listing.seller]++;
        // Remove listing after successful sale
        _unlistDAIP(_daipId);
        emit DAIPUnlist(_daipId, address(this));
        emit DAIPSold(_daipId, msg.sender, listing.price);
    }

    /// @notice Place a bid on a specific DAIP token
    /// @dev Stores the bid, checks against the current highest bid, and escrows the bid amount in the contract
    /// @param _daipId The ID of the DAIP token to place a bid on
    /// @param _amount The bid amount in the accepted ERC-20 token
    /// @param _expiration The timestamp when the bid becomes invalid
    function placeBid(uint256 _daipId, uint256 _amount, uint256 _expiration) external {
        if (_amount == 0) revert ZeroBid();
        if (_expiration <= block.timestamp) revert InvalidExpiration();

        Bid[] storage bids = daipBids[_daipId];

        // If there's at least one previous bid, enforce minimum increment rule
        if (bids.length > 0) {
            Bid storage current = bids[highestBidIndex[_daipId]];
            // Ensure the highest bid is still active (hasn't been withdrawn or accepted)
            if (!current.active) revert HighestBidInactive();
            // New bid must be greater than current highest + min increment percentage
            uint256 minIncrement = current.amount + (current.amount * MIN_BID_INCREMENT_PERCENT) / 100;
            if (_amount <= minIncrement) revert BidTooLow();
        }

        // Transfer bid amount to contract
        bool success = acceptedToken.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert EscrowTransferFailed();

        // Store the new bid in the bids array
        bids.push(Bid({bidder: msg.sender, amount: _amount, expiration: _expiration, isEscrowed: true, active: true}));

        // Update the index pointing to the current highest bid
        highestBidIndex[_daipId] = bids.length - 1;
        emit BidPlaced(_daipId, msg.sender, _amount, _expiration);
    }

    /// @notice Accept the highest active bid on a DAIP token
    /// @dev Transfers ownership of the DAIP to the highest bidder, distributes platform and royalty fees, and marks the bid as completed
    /// @param _daipId The ID of the DAIP token whose bid is being accepted
    function acceptBid(uint256 _daipId) external nonReentrant onlyOwnerOf(_daipId) {
        // Load the current highest bid for the given DAIP token
        Bid storage bid = daipBids[_daipId][highestBidIndex[_daipId]];

        // Load the listing info to calculate royalty
        DAIPListing memory listing = daipListings[_daipId];

        // Ensure the bid is still valid, escrowed, and not expired
        if (!bid.active || !bid.isEscrowed) revert NoValidBid();
        if (block.timestamp > bid.expiration) revert BidExpired();

        // Calculate platform fee and creator royalty from the total bid amount
        uint256 platformCut = (bid.amount * platformFee) / 100;
        uint256 royalty = (bid.amount * listing.royaltyPercentage) / 100;

        // Remaining amount goes to the seller (DAIP owner)
        uint256 sellerProceeds = bid.amount - platformCut - royalty;

        // Transfer funds to seller
        bool sentToSeller = acceptedToken.transfer(msg.sender, sellerProceeds);
        if (!sentToSeller) revert SellerTransferFailed();

        // Transfer royalty to original creator if applicable
        if (royalty > 0) {
            bool sentToCreator = acceptedToken.transfer(listing.creator, royalty);
            if (!sentToCreator) revert RoyaltyTransferFailed();
        }

        // Transfer the NFT ownership from seller to bidder
        _transfer(msg.sender, bid.bidder, _daipId);

        // If the DAIP was listed, unlist it now
        if (bid.active) {
            _unlistDAIP(_daipId);
            emit DAIPUnlist(_daipId, msg.sender);
        }

        // Mark bid as completed so it cannot be reused or withdrawn
        bid.active = false;
        bid.isEscrowed = false;

        emit BidAccepted(_daipId, bid.bidder, bid.amount);
    }

    /// @notice Withdraw a bid placed on a DAIP token
    /// @dev Allows the bidder to manually withdraw a bid if it is expired or no longer the highest bid
    /// @param _daipId The ID of the DAIP token the bid was placed on
    /// @param _index The index of the bid in the bid array for the given DAIP token
    function withdrawMyBid(uint256 _daipId, uint256 _index) external {
        Bid storage bid = daipBids[_daipId][_index];

        if (bid.bidder != msg.sender) revert NotBidder();
        if (!bid.active) revert BidInactive();

        // Only allow withdrawal if the bid has expired
        // OR if it is not the currently highest bid
        bool isExpired = block.timestamp > bid.expiration;
        bool isNotHighest = _index != highestBidIndex[_daipId];

        if (!isExpired && !isNotHighest) revert CannotWithdrawActiveTopBid();

        // Mark the bid as inactive and remove it from escrow
        bid.active = false;
        bid.isEscrowed = false;

        // Refund the bidder
        bool success = acceptedToken.transfer(msg.sender, bid.amount);
        if (!success) revert TransferFailed();

        emit BidRefunded(_daipId, msg.sender);
    }

    /// @notice Propose to restrict or unrestrict NFT transfer
    /// @dev Only token owner can propose restriction
    /// @param _daipId Token ID
    /// @param restrictTransfer True to restrict, false to unrestrict
    function proposeTransferRestriction(uint256 _daipId, bool restrictTransfer) external onlyOwnerOf(_daipId) {
        restrictedTransfers[_daipId] = restrictTransfer;
    }

    /// @notice Update platform fee
    /// @dev Only contract owner can update; capped at 10%
    /// @param _newFee New fee percentage
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        if (_newFee > 10) revert RoyaltyTooHigh();
        platformFee = _newFee;
        emit PlatformFeeUpdated(_newFee);
    }

    /// @notice Update royalty percentage for a specific DAIP
    /// @dev Only callable by governance admin; capped at 10%
    /// @param _daipId Token ID
    /// @param _newRoyalty New royalty percentage
    function updateRoyalty(uint256 _daipId, uint256 _newRoyalty) external onlyGovernanceAdmin {
        if (_newRoyalty > 10) revert RoyaltyTooHigh();
        daipListings[_daipId].royaltyPercentage = _newRoyalty;
        emit RoyaltyUpdated(_daipId, _newRoyalty);
    }

    /// @notice Delist a DAIP from sale
    /// @dev Only token owner can delist; must currently be listed
    /// @param _daipId Token ID
    function delistDAIP(uint256 _daipId) external onlyOwnerOf(_daipId) {
        if (daipListings[_daipId].price == 0) revert PriceTooLow();
        delete daipListings[_daipId];
        _unlistDAIP(_daipId);
        emit DAIPDelisted(_daipId);
    }

    /// @notice Delist multiple DAIPs by IDs
    /// @param tokenIds Array of token IDs to delist
    /// q tokenId or _daipId in _unlistDAIP ?
    function delistMultipleDAIPs(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (ownerOf(tokenId) == msg.sender && daipListings[tokenId].price > 0) {
                delete daipListings[tokenId];
                _unlistDAIP(tokenId);
                emit DAIPDelisted(tokenId);
            }
        }
    }

    /// @notice Returns all bids for a specific DAIP
    /// @param _daipId Token ID
    /// q
    function getAllBid(uint256 _daipId) external view returns (Bid[] memory) {
        return daipBids[_daipId];
    }

    /// @notice Returns only active bids (not withdrawn/accepted) for a DAIP
    /// @param _daipId Token ID
    function getActiveBids(uint256 _daipId) external view returns (Bid[] memory) {
        Bid[] storage allBids = daipBids[_daipId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allBids.length; i++) {
            if (allBids[i].active) activeCount++;
        }

        Bid[] memory activeBids = new Bid[](activeCount);
        uint256 j = 0;

        for (uint256 i = 0; i < allBids.length; i++) {
            if (allBids[i].active) {
                activeBids[j] = allBids[i];
                j++;
            }
        }

        return activeBids;
    }

    /// @notice Returns the current highest bid for a DAIP (tracked by index)
    /// @param _daipId Token ID
    function getHighestBid(uint256 _daipId) external view returns (Bid memory) {
        if (daipBids[_daipId].length == 0) revert NoBids();
        return daipBids[_daipId][highestBidIndex[_daipId]];
    }

    /// @notice Returns full info for a minted DAIP token
    /// @param _tokenId The token ID of the DAIP
    /// @return listing The DAIPListing metadata
    /// @return uri The metadata URI
    /// @return owner The current owner of the token
    function getDAIPInfoById(uint256 _tokenId)
        external
        view
        returns (DAIPListing memory listing, string memory uri, address owner)
    {
        listing = daipListings[_tokenId];
        uri = _tokenURIs[_tokenId];
        owner = ownerOf(_tokenId); // from ERC721

        return (listing, uri, owner);
    }

    // Minimal getAllDAIPs (read-only, safe for small use or off-chain)
    function getAllDAIPsInfo()
        external
        view
        returns (DAIPListing[] memory, string[] memory uris, address[] memory owners)
    {
        DAIPListing[] memory all = new DAIPListing[](_tokenIds);
        uris = new string[](_tokenIds);
        owners = new address[](_tokenIds);
        for (uint256 i = 1; i <= _tokenIds; i++) {
            uint256 index = i - 1;
            all[index] = daipListings[i];
            uris[index] = tokenURI(i);
            owners[index] = ownerOf(i);
        }
        return (all, uris, owners);
    }

    /// @notice Returns listing info for a DAIP
    /// @param _daipId Token ID
    function getListedDAIP(uint256 _daipId) external view returns (DAIPListing memory) {
        return daipListings[_daipId];
    }
    /// @notice Returns the number of DAIPs currently listed
    /// @return The count of currently listed DAIPs

    function getListedDAIPCount() external view returns (uint256) {
        return listedDAIPIds.length;
    }

    // all[index] = daipListings[i];
    // Minimal getListedDAIPs (read-only, safe for small use or off-chain)
    function getListedDAIPs() external view returns (DAIPListing[] memory) {
        uint256 count = 0;

        // First pass: count active listings
        for (uint256 i = 0; i < listedDAIPIds.length; i++) {
            if (isListed[listedDAIPIds[i]]) {
                count++;
            }
        }

        DAIPListing[] memory listed = new DAIPListing[](count);
        uint256 j = 0;

        // Second pass: collect active listings
        for (uint256 i = 0; i < listedDAIPIds.length; i++) {
            uint256 tokenId = listedDAIPIds[i];
            if (isListed[tokenId]) {
                listed[j] = daipListings[tokenId];
                j++;
            }
        }

        return listed;
    }

    /// @notice Get user stats including minted , listed and sold DAIPs
    /// @param _user Address to query
    /// @return minted Number of NFTs created by user
    /// @return sold Number of NFTs transferred away by user
    function getUserStats(address _user) external view returns (uint256, uint256, uint256) {
        return (mintedCount[_user], listedCount[_user], soldCount[_user]);
    }

    fallback() external payable {
        revert FallbackNotSupported();
    }

    receive() external payable {
        revert ETHNotAccepted();
    }
}
