// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
import "src/utils/Pikapatible.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xViola and PikaPool Developers

/// @dev This contract is an example 721A NFT demonstrating PikaPool's convenient Pikapatible plugin.
/// As shown, projects may enjoy the benefits of the PikaPool auction engine simply by adding three lines of code

contract Example721A is ERC721A, Pikapatible {

    /// @param _name The name of the creator's NFT project
    /// @param _symbol The token ticker symbol for the creator's NFT project
    /// @param _settlementContract The address of the PikaPool settlement contract
    /// @param _recipient The address of the recipient to which mint auction revenue will be sent
    /// @param _priceInWei The price of minting each NFT in the collection, to be paid in WETH and denominated in wei
    constructor(
        string memory _name,
        string memory _symbol,
        address _settlementContract,
        address _recipient,
        uint256 _priceInWei
    ) ERC721A(_name,_symbol) Pikapatible(_settlementContract, _recipient, _priceInWei) {}

    /// @dev The tokenURI function that returns the NFT metadata, providing it for marketplaces or frontends viewing the NFT itself
    /// @param tokenId The unique (non-fungible) identifier of a specific NFT
    /// @notice This is the only function that needs to be implemented by an NFT project wishing to mint using PikaPool's engine,
    /// metadata formats of all kinds are supported (IPFS, Arweave, on-chain etc)
    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        // placeholder Pikachu ASCII art hosted on Arweave, created and deployed by 0xViola
        return "ar://mOZLYUUSsy1V9U7qGETfN1eSU9Hv42eB7zGrxsCQbUk";
    }
}
