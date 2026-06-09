// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/TestNFT.sol";
import "../src/MyToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    TestNFT public nft;
    MyToken public paymentToken;
    
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public otherUser = address(0x3);
    
    uint256 public constant TOKEN_MINT_AMOUNT = 1e10 * 1e18;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000 * 1e18;
    uint256 public constant LISTING_PRICE = 100 * 1e18;
    
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

    function setUp() public {
        vm.startPrank(seller);
        
        // Deploy contracts
        market = new NFTMarket();
        nft = new TestNFT();
        paymentToken = new MyToken("Payment Token", "PAY");
        
        // Mint NFT to seller
        uint256 tokenId = nft.mint(seller);
        
        // Approve market to transfer NFT
        nft.approve(address(market), tokenId);
        
        // Transfer payment tokens to buyer
        paymentToken.transfer(buyer, INITIAL_TOKEN_SUPPLY);
        paymentToken.transfer(otherUser, INITIAL_TOKEN_SUPPLY);
        
        vm.stopPrank();
    }

    // ==================== Listing Tests ====================

    function test_ListNFT_Success() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        
        vm.expectEmit(true, true, true, true);
        emit NFTListed(
            0,
            seller,
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        assertEq(listingId, 0);
        
        NFTMarket.Listing memory listing = market.getListing(listingId);
        assertEq(listing.seller, seller);
        assertEq(listing.nftContract, address(nft));
        assertEq(listing.tokenId, tokenId);
        assertEq(listing.paymentToken, address(paymentToken));
        assertEq(listing.price, LISTING_PRICE);
        assertTrue(listing.isActive);
        
        vm.stopPrank();
    }

    function test_ListNFT_NotOwner() public {
        uint256 tokenId = 0;
        
        vm.startPrank(buyer);
        
        vm.expectRevert(NFTMarket.NotOwner.selector);
        market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        vm.stopPrank();
    }

    function test_ListNFT_NotApproved() public {
        uint256 tokenId = 0;
        
        // Revoke approval
        vm.startPrank(seller);
        nft.approve(address(0), tokenId);
        
        vm.expectRevert(NFTMarket.NotApproved.selector);
        market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        vm.stopPrank();
    }

    function test_ListNFT_InvalidPrice() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        
        vm.expectRevert(NFTMarket.InvalidPrice.selector);
        market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            0
        );
        
        vm.stopPrank();
    }

    function test_ListNFT_MultipleListings() public {
        vm.startPrank(seller);
        
        // Mint another NFT
        uint256 tokenId2 = nft.mint(seller);
        nft.approve(address(market), tokenId2);
        
        // List first NFT
        uint256 listingId1 = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        
        // List second NFT
        uint256 listingId2 = market.listNFT(
            address(nft),
            tokenId2,
            address(paymentToken),
            LISTING_PRICE * 2
        );
        
        assertEq(listingId1, 0);
        assertEq(listingId2, 1);
        assertEq(market.totalListings(), 2);
        
        vm.stopPrank();
    }

    // ==================== Purchase Tests ====================

    function test_PurchaseNFT_Success() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        
        vm.expectEmit(true, true, true, true);
        emit NFTPurchased(
            listingId,
            buyer,
            seller,
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        // Check NFT ownership transferred
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // Check payment transferred
        uint256 expectedSellerBalance = TOKEN_MINT_AMOUNT - 2 * INITIAL_TOKEN_SUPPLY + LISTING_PRICE;
        assertEq(paymentToken.balanceOf(buyer), INITIAL_TOKEN_SUPPLY - LISTING_PRICE);
        assertEq(paymentToken.balanceOf(seller), expectedSellerBalance);
        
        // Check listing deactivated
        NFTMarket.Listing memory listing = market.getListing(listingId);
        assertFalse(listing.isActive);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_BuyerIsSeller() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        paymentToken.approve(address(market), LISTING_PRICE);
        
        vm.expectRevert(NFTMarket.BuyerIsSeller.selector);
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_DuplicatePurchase() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        
        // First purchase
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        // Second purchase should fail
        vm.expectRevert(NFTMarket.ListingNotActive.selector);
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_InsufficientPayment() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE - 1);
        
        vm.expectRevert(NFTMarket.InsufficientPayment.selector);
        market.purchaseNFT(listingId, LISTING_PRICE - 1);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_Overpayment() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        uint256 overpayment = LISTING_PRICE + 50 * 1e18;
        paymentToken.approve(address(market), overpayment);
        
        market.purchaseNFT(listingId, overpayment);
        
        // Check NFT ownership transferred
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // Check full payment transferred (including overpayment)
        assertEq(paymentToken.balanceOf(buyer), INITIAL_TOKEN_SUPPLY - overpayment);
        assertEq(paymentToken.balanceOf(seller), TOKEN_MINT_AMOUNT - 2 * INITIAL_TOKEN_SUPPLY + overpayment);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_InsufficientAllowance() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        // Don't approve payment token
        
        vm.expectRevert(NFTMarket.InsufficientPayment.selector);
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        vm.stopPrank();
    }

    function test_PurchaseNFT_ListingNotActive() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        // Cancel the listing
        market.cancelListing(listingId);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        
        vm.expectRevert(NFTMarket.ListingNotActive.selector);
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        vm.stopPrank();
    }

    function test_CancelListing_Success() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        
        vm.expectEmit(true, true, false, false);
        emit ListingCancelled(listingId, seller);
        
        market.cancelListing(listingId);
        
        NFTMarket.Listing memory listing = market.getListing(listingId);
        assertFalse(listing.isActive);
        
        // Seller still owns the NFT
        assertEq(nft.ownerOf(tokenId), seller);
        
        vm.stopPrank();
    }

    function test_CancelListing_NotOwner() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            tokenId,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        
        vm.expectRevert(NFTMarket.NotOwner.selector);
        market.cancelListing(listingId);
        
        vm.stopPrank();
    }

    // ==================== Fuzz Tests ====================

    function testFuzz_ListNFT_RandomPrice(uint256 price) public {
        vm.assume(price > 0 && price <= 10000 * 1e18);
        
        vm.startPrank(seller);
        
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            price
        );
        
        NFTMarket.Listing memory listing = market.getListing(listingId);
        assertEq(listing.price, price);
        assertTrue(listing.isActive);
        
        vm.stopPrank();
    }

    function testFuzz_PurchaseNFT_RandomPrice(uint256 price) public {
        vm.assume(price > 0 && price <= INITIAL_TOKEN_SUPPLY);
        
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            price
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), price);
        
        market.purchaseNFT(listingId, price);
        
        assertEq(nft.ownerOf(0), buyer);
        assertEq(paymentToken.balanceOf(seller), TOKEN_MINT_AMOUNT - 2 * INITIAL_TOKEN_SUPPLY + price);
        
        vm.stopPrank();
    }

    function testFuzz_PurchaseNFT_RandomBuyer(address randomBuyer) public {
        vm.assume(randomBuyer != seller && randomBuyer != buyer && randomBuyer != otherUser && randomBuyer != address(0) && randomBuyer != address(market));
        
        // Setup: Give tokens to random buyer
        vm.startPrank(seller);
        paymentToken.transfer(randomBuyer, INITIAL_TOKEN_SUPPLY);
        
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(randomBuyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        
        market.purchaseNFT(listingId, LISTING_PRICE);
        
        assertEq(nft.ownerOf(0), randomBuyer);
        assertEq(paymentToken.balanceOf(randomBuyer), INITIAL_TOKEN_SUPPLY - LISTING_PRICE);
        assertEq(paymentToken.balanceOf(seller), TOKEN_MINT_AMOUNT - 3 * INITIAL_TOKEN_SUPPLY + LISTING_PRICE);
        
        vm.stopPrank();
    }

    function testFuzz_ListAndPurchase_RandomPriceAndBuyer(uint256 price, address randomBuyer) public {
        vm.assume(price > 0 && price <= INITIAL_TOKEN_SUPPLY);
        vm.assume(randomBuyer != seller && randomBuyer != buyer && randomBuyer != otherUser && randomBuyer != address(0) && randomBuyer != address(market));
        vm.assume(uint160(randomBuyer) < uint160(0x7100000000000000000000000000000000000000)); // Avoid cheatcode addresses
        
        // Setup: Give tokens to random buyer
        vm.startPrank(seller);
        paymentToken.transfer(randomBuyer, INITIAL_TOKEN_SUPPLY);
        
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            price
        );
        vm.stopPrank();
        
        vm.startPrank(randomBuyer);
        paymentToken.approve(address(market), price);
        
        market.purchaseNFT(listingId, price);
        
        assertEq(nft.ownerOf(0), randomBuyer);
        assertEq(paymentToken.balanceOf(randomBuyer), INITIAL_TOKEN_SUPPLY - price);
        assertEq(paymentToken.balanceOf(seller), TOKEN_MINT_AMOUNT - 3 * INITIAL_TOKEN_SUPPLY + price);
        
        vm.stopPrank();
    }

    // ==================== Invariant Tests ====================

    function invariant_MarketNeverHoldsTokens() public view {
        // The market should never hold any payment tokens
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function test_Invariant_MarketNeverHoldsTokens_AfterListing() public {
        vm.startPrank(seller);
        market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function test_Invariant_MarketNeverHoldsTokens_AfterPurchase() public {
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE);
        market.purchaseNFT(listingId, LISTING_PRICE);
        vm.stopPrank();
        
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function test_Invariant_MarketNeverHoldsTokens_AfterMultipleTransactions() public {
        // Create multiple NFTs and listings
        vm.startPrank(seller);
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 tokenId = nft.mint(seller);
            nft.approve(address(market), tokenId);
            
            market.listNFT(
                address(nft),
                tokenId,
                address(paymentToken),
                LISTING_PRICE * (i + 1)
            );
        }
        vm.stopPrank();
        
        // Purchase some NFTs
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LISTING_PRICE * 15);
        
        market.purchaseNFT(0, LISTING_PRICE);
        market.purchaseNFT(2, LISTING_PRICE * 3);
        market.purchaseNFT(4, LISTING_PRICE * 5);
        vm.stopPrank();
        
        // Market should still have zero balance
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function test_Invariant_MarketNeverHoldsTokens_AfterFailedPurchase() public {
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        vm.stopPrank();
        
        vm.startPrank(buyer);
        // Try to purchase with insufficient payment
        paymentToken.approve(address(market), LISTING_PRICE - 1);
        
        try market.purchaseNFT(listingId, LISTING_PRICE - 1) {
            fail("Purchase should have failed");
        } catch {
            // Expected to fail
        }
        vm.stopPrank();
        
        // Market should still have zero balance
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }

    function test_Invariant_MarketNeverHoldsTokens_AfterCancellation() public {
        vm.startPrank(seller);
        uint256 listingId = market.listNFT(
            address(nft),
            0,
            address(paymentToken),
            LISTING_PRICE
        );
        
        market.cancelListing(listingId);
        vm.stopPrank();
        
        assertEq(paymentToken.balanceOf(address(market)), 0);
    }
}