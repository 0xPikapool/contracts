// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
import "src/utils/Pikapatible.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

contract Example721A is ERC721A, Pikapatible {

    constructor(
        string memory _name,
        string memory _symbol,
        address _settlementContract, 
        uint256 _priceInGweth
    ) ERC721A(_name,_symbol) Pikapatible(_settlementContract,_priceInGweth) {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return "ar://mOZLYUUSsy1V9U7qGETfN1eSU9Hv42eB7zGrxsCQbUk";
    }
}
