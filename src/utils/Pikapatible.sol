// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "ERC721A/ERC721A.sol";
import "solmate/auth/Owned.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xViola and PikaPool Developers

/// @dev This abstract contract plugin attaches to any ERC721A contract via inheritance, rendering it 
/// PikaPool-Compatible 'Pikapatible' by implementing its mint function and declaring the PikaPool Settlement contract its owner.
/// This ensures all payments are reliably received on mint from PikaPool in accordance with its robust auction engine
abstract contract Pikapatible is ERC721A, Owned {

    /// @dev The recipient address where revenue is to be forwarded. For example, an NFT creator's multisig
    address public recipient;

    /// @dev The price to mint each individual NFT
    uint256 public price;
    /// @dev The collection's total maximum supply
    uint256 public maxSupply;
    /// @dev The collection's total allocation to Pikapool's auction engine
    uint256 public allocatedSupply;
    /// @dev The collection's count of Pikapool's allocated mints
    uint256 public allocatedMintsCounter;

    /// @dev Event emitted upon any failure to mint 
    /// used instead of reverts to ensure finality for successful mints even in the case of failures interspersed within the batch
    /// @param to The address of the winning bid's originator, in this case comparable to tx.origin
    /// @param reason The reason for the mint's failure.
    event MintFailure(address indexed to, bytes reason);

    /// @dev All Pikapatible 721A NFTs restrict batch minting solely to the PikaPool settlement contract by granting it ownership
    constructor(
        address _settlementContract, 
        address _recipient, 
        uint256 _priceInWei,
        uint256 _maxSupply,
        uint256 _allocatedSupply
    ) Owned(_settlementContract)
    {
        recipient = _recipient;
        price = _priceInWei;
        maxSupply = _maxSupply;
        allocatedSupply = _allocatedSupply;
    }

    /// @notice May only be called by the Pikapool Settlement contract
    /// @dev This mint function can be attached to any ERC721A via inheritance to enjoy the benefits of the PikaPool auction engine
    /// @dev Will not mint if sent insufficient funds, avoiding reverts to facilitate PikaPool's settlement contract batch minting functionality
    /// @dev ERC721A's _safeMint() function is shirked here in favor of _mint, as all PikaPool mints 
    /// utilize meta-transactions which ensures no smart contracts can bid as they do not possess private keys with which to sign
    /// @param to The bidder address to mint to, provided a sufficient bid was offered
    /// @param amount The number of NFTs to mint to the bidder
    function mint(address to, uint256 amount) external payable onlyOwner {
        if (_nextTokenId() + amount > maxSupply || allocatedMintsCounter + amount > allocatedSupply) { 
            emit MintFailure(to, bytes('Exceeds Max'));
            return;
        }
        if (amount != 0 && msg.value >= price * amount) {
            allocatedMintsCounter += amount;
            _mint(to, amount);
        }
    }

    /// @notice For cases where NFT creators wish to allocate only part of their token supply to a Pikapool auction, we provide
    /// this public-facing mint function which can be implemented with custom logic to enable a public mint alongside a Pikapool auction
    /// @dev This public mint function should be overridden to reflect the NFT creator's liking regarding their ideal minting process
    /// @dev This function provides flexibility to accomodate all types of public mints, auctions, or airdrops. This includes stealth mints, 
    /// public sales, retroactive airdrop, Dutch auctions, Blind-Dutch auctions, VRGDAs, etc.
    /// @param to The recipient address to be minted to
    /// @param amount The number of NFTs to mint to recipient address 'to'
    function publicMint(address to, uint256 amount) public payable virtual;

    /// @dev Function for creators to claim the ETH earned from their PikaPool auction mint
    function claimRevenue() external {
        (bool r,) = payable(recipient).call{ value: address(this).balance }('');
        require(r);
    }

    receive() external payable {}
}