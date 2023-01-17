# BidSignatures
[Git Source](https://github.com-khepri/0xPikapool/pikapool-contracts/blob/46c3d29612fee963c31205560a2c2694af75ef33/src/utils/BidSignatures.sol)

**Author:**
0xKhepri + 0xBraixen, and PikaPool Developers


## State Variables
### EIP712DOMAIN_TYPEHASH

```solidity
bytes32 constant EIP712DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
```


### BID_TYPE_HASH

```solidity
bytes32 constant BID_TYPE_HASH = keccak256(
    "Bid(string auctionName,address auctionAddress,address bidder,uint256 amount,uint256 basePrice,uint256 tip)"
);
```


### DOMAIN_TYPE_HASH
*The EIP-712 domain type hash, required to derive domain separator*


```solidity
bytes32 internal constant DOMAIN_TYPE_HASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
```


### DOMAIN_NAME
*The EIP-712 domain name, required to derive domain separator*


```solidity
bytes32 internal constant DOMAIN_NAME = keccak256("Pikapool Auction");
```


### DOMAIN_VERSION
*The EIP-712 domain version, required to derive domain separator*


```solidity
bytes32 internal constant DOMAIN_VERSION = keccak256("1");
```


### DOMAIN_SEPARATOR
*The EIP-712 domain separator, required to prevent replay attacks across networks*


```solidity
bytes32 public immutable DOMAIN_SEPARATOR;
```


## Functions
### constructor


```solidity
constructor();
```

### hashBid

*Function to compute hash of a bid*


```solidity
function hashBid(Bid memory bid) public pure returns (bytes32);
```

### hashTypedData

*Function to compute hash of fully EIP-712 encoded message for the domain to be used with ecrecover()*


```solidity
function hashTypedData(Bid memory bid) public view returns (bytes32);
```

## Structs
### Bid
*Struct of bid data to be hashed and signed for meta-transactions.*


```solidity
struct Bid {
    string auctionName;
    address auctionAddress;
    address bidder;
    uint256 amount;
    uint256 basePrice;
    uint256 tip;
}
```

