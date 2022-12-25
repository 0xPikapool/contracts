// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

abstract contract BidSignatures {

    /// @dev Error to revert execution if auction has concluded
    error AuctionDeadlineConcluded();
    /// @dev Error to revert execution if ecrecover returns invalid signature originator
    error InvalidSignature();

    /// @dev Struct of bid data to be hashed and signed for meta-transactions. 
    /// @param auctionAddress The address of the creator NFT being bid on. Becomes a string off-chain.
    /// @param bidder The address of the bid's originator, similar to tx.origin.
    /// @param amount The number of assets being bid on.
    /// @param blockDeadline The block height at which the auction concludes
    struct Bid {
        address auctionAddress;
        address bidder;
        uint256 amount;
        uint32 blockDeadline;
    }

    /// @dev The EIP-712 type hash for the Bid struct
    bytes32 internal constant BID_TYPE_HASH = 
        keccak256("Bid(address auctionAddress,address bidder,uint256 amount,uint32 blockDeadline)"
    );
    
    /// @dev The EIP-712 domain type hash, required to derive domain separator
    bytes32 internal constant DOMAIN_TYPE_HASH = 
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev The EIP-712 domain name, required to derive domain separator
    bytes32 internal constant DOMAIN_NAME = keccak256("PikaPool");

    /// @dev The EIP-712 domain version, required to derive domain separator
    bytes32 internal constant DOMAIN_VERSION = keccak256("v0");

    /// @dev The EIP-712 domain separator, required to prevent replay attacks across networks
    bytes32 internal immutable DOMAIN_SEPARATOR;

    /// @dev Event emitted when a bid is signed.
    //todo
    // event Signature(address indexed owner, bytes bidData)
    // event revokeSignature()

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                DOMAIN_NAME,
                DOMAIN_VERSION,
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev Function to compute hash of a bid
    function hashBid(Bid memory bid) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                BID_TYPE_HASH,
                bid.auctionAddress,
                bid.bidder,
                bid.amount,
                bid.blockDeadline
            )
        );
    }

    /// @dev Function to compute hash of fully EIP-712 encoded message for the domain to be used with ecrecover()
    function hashTypedData(Bid memory bid) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                hashBid(bid)
            )
        );
    }
}