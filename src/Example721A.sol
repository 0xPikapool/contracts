// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
//import access control

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

contract Example721A is ERC721A {

    error IncorrectPricePaid();

    uint256 priceInGweth;

    constructor(uint256 _priceInGweth) ERC721A("PikaExample", "PIKA") {
        //owner = settlement;
        priceInGweth = _priceInGweth;
    }

    function mint(address to, uint256 amount) external /* onlyOwner */ {
        _mint(to, amount);
    }
}