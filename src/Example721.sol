// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

contract Example721 is ERC721A {

    constructor() ERC721A("Creator", "CREATOR") {}

    function mint(address to, uint256 amount) external payable {
        _mint(to, quantity);
    }
}