# Pikapatible
[Git Source](https://github.com-khepri/0xPikapool/pikapool-contracts/blob/46c3d29612fee963c31205560a2c2694af75ef33/src/utils/Pikapatible.sol)

**Inherits:**
ERC721A, Owned

**Author:**
0xKhepri and PikaPool Developers

*This plugin attaches to any ERC721A contract and renders it Pika-Compatible 'Pikapatible'
by implementing its mint function and declaring the PikaPool Settlement contract its owner.
This ensures all payments and tips are reliably received on mint from PikaPool in accordance with its robust auction engine*


## State Variables
### price

```solidity
uint256 public price;
```


## Functions
### constructor


```solidity
constructor(address _settlementContract, uint256 _priceInGweth) Owned(_settlementContract);
```

### mint

ERC721A's _safeMint() functionality is shirked in favor of _mint, as all PikaPool mints
utilize meta-transactions. This ensures no smart contracts can bid as they do not possess private keys.

May only be called by the Settlement contract

*This mint function can be attached to any ERC721A to enjoy the benefits of the PikaPool auction engine
It will not mint if insufficient funds are paid, avoiding a revert() in order to facilitate the
Settlement contract's batch minting functionality*


```solidity
function mint(address to, uint256 amount) external payable onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The bidder address to mint to, provided a sufficient bid was offered|
|`amount`|`uint256`|The number of NFTs to mint to the bidder|


### claimRevenue

Populated with a placeholder address for PikaPool team to reclaim their Goerli testnet eth

*Function for creators to claim the ETH earned from their PikaPool auction mint*


```solidity
function claimRevenue() external;
```

### receive


```solidity
receive() external payable;
```

