# Example721A
[Git Source](https://github.com-khepri/0xPikapool/pikapool-contracts/blob/46c3d29612fee963c31205560a2c2694af75ef33/src/Example721A.sol)

**Inherits:**
ERC721A, [Pikapatible](/src/utils/Pikapatible.sol/contract.Pikapatible.md)

**Author:**
0xKhepri and PikaPool Developers


## Functions
### constructor


```solidity
constructor(string memory _name, string memory _symbol, address _settlementContract, uint256 _priceInGweth)
    ERC721A(_name, _symbol)
    Pikapatible(_settlementContract, _priceInGweth);
```

### tokenURI


```solidity
function tokenURI(uint256) public pure override returns (string memory);
```

