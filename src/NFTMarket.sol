// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract NFTMarket is ERC721Holder {
    
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        bool isActive;
    }

    // Mapping from listing ID to Listing
    mapping(uint256 => Listing) public listings;
    
    // Counter for listing IDs
    uint256 private _listingCounter;
    
    // Events
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );
    
    event NFTPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );
    
    event ListingCancelled(uint256 indexed listingId, address indexed seller);

    // Errors
    error NotOwner();
    error NotApproved();
    error InvalidPrice();
    error ListingNotFound();
    error ListingNotActive();
    error BuyerIsSeller();
    error InsufficientPayment();
    error PaymentFailed();
    error TransferFailed();

    /**
     * @dev List an NFT for sale
     * @param nftContract The address of the ERC721 contract
     * @param tokenId The token ID to list
     * @param paymentToken The address of the ERC20 token for payment
     * @param price The price in payment tokens
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    ) external returns (uint256) {
        if (price == 0) revert InvalidPrice();
        
        IERC721 nft = IERC721(nftContract);
        
        // Check if caller is the owner of the NFT
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        
        // Check if market is approved to transfer the NFT
        if (nft.getApproved(tokenId) != address(this) && !nft.isApprovedForAll(msg.sender, address(this))) {
            revert NotApproved();
        }
        
        // Create listing
        uint256 listingId = _listingCounter++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            isActive: true
        });
        
        emit NFTListed(listingId, msg.sender, nftContract, tokenId, paymentToken, price);
        
        return listingId;
    }

    /**
     * @dev Purchase a listed NFT
     * @param listingId The ID of the listing to purchase
     * @param amount The amount of payment tokens to send
     */
    function purchaseNFT(uint256 listingId, uint256 amount) external {
        Listing storage listing = listings[listingId];
        
        if (!listing.isActive) revert ListingNotActive();
        if (msg.sender == listing.seller) revert BuyerIsSeller();
        if (amount < listing.price) revert InsufficientPayment();
        
        // Transfer payment tokens from buyer to seller
        IERC20 paymentToken = IERC20(listing.paymentToken);
        
        // Check buyer's balance and allowance
        if (paymentToken.balanceOf(msg.sender) < amount) revert InsufficientPayment();
        if (paymentToken.allowance(msg.sender, address(this)) < amount) revert InsufficientPayment();
        
        // Transfer payment tokens directly from buyer to seller
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, amount);
        if (!success) revert PaymentFailed();
        
        // Transfer NFT from seller to buyer
        IERC721 nft = IERC721(listing.nftContract);
        nft.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // Deactivate listing
        listing.isActive = false;
        
        emit NFTPurchased(
            listingId,
            msg.sender,
            listing.seller,
            listing.nftContract,
            listing.tokenId,
            listing.paymentToken,
            listing.price
        );
    }

    /**
     * @dev Cancel a listing
     * @param listingId The ID of the listing to cancel
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        
        if (!listing.isActive) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotOwner();
        
        listing.isActive = false;
        
        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @dev Get listing details
     * @param listingId The ID of the listing
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev Get the total number of listings
     */
    function totalListings() external view returns (uint256) {
        return _listingCounter;
    }
}