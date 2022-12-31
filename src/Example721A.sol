// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
//import access control

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

contract Example721A is ERC721A {

    error IncorrectPricePaid();

    // uint256 price;

    constructor(uint256 _price) ERC721A("PikaExample", "PIKA") {
        //owner = settlement;
        // price = _price;
    }

    function mint(address to, uint256 amount) external payable /* onlyOwner */ {
        // if (msg.value != price) revert IncorrectPricePaid();
        _mint(to, amount);
    }
}