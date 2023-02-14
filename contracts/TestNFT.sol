// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// create by Openzeppelinn Contracts Wizard
contract TestNFT is ERC721, ERC721URIStorage, Ownable {
    constructor() ERC721("TestNFT", "TNFT") {}

    uint256 public tokenId;

    function safeMint(address to, string memory _uri)
        public
        onlyOwner
    {
        tokenId++;
        uint256 tokenId_ = tokenId;
        _safeMint(to, tokenId_);
        _setTokenURI(tokenId_, _uri);
    }

    function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(_tokenId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public override {
      super.safeTransferFrom(_from, _to, _tokenId, _data);
    }
}