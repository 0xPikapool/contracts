// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
import "solmate/auth/Owned.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

/// @dev This plugin attaches to any ERC721A contract and renders it Pika-Compatible 'Pikapatible'
/// by implementing its mint function and declaring the PikaPool Settlement contract its owner.
/// This ensures all payments and tips are reliably received on mint from PikaPool in accordance with its robust auction engine
abstract contract Pikapatible is ERC721A, Owned {

    uint256 public price;

    constructor(address _settlementContract, uint256 _priceInGweth) Owned(_settlementContract) {
        price = _priceInGweth;
    }

    /// @dev This mint function can be attached to any ERC721A to enjoy the benefits of the PikaPool auction engine
    /// It will not mint if insufficient funds are paid, avoiding a revert() in order to facilitate the
    /// Settlement contract's batch minting functionality
    /// @notice ERC721A's _safeMint() functionality is shirked in favor of _mint, as all PikaPool mints 
    /// utilize meta-transactions. This ensures no smart contracts can bid as they do not possess private keys.
    /// @notice May only be called by the Settlement contract
    /// @param to The bidder address to mint to, provided a sufficient bid was offered
    /// @param amount The number of NFTs to mint to the bidder
    function mint(address to, uint256 amount) external payable onlyOwner {
        if (msg.value >= price * amount) {
            _mint(to, amount);
        }
    }

    receive() external payable {}
}