// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    uint256 private _tokenIdCounter;
    
    constructor() ERC721("Test NFT", "TNFT") {}
    
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    function tokenURI(uint256) public pure override returns (string memory) {
        return "ipfs://test";
    }
}