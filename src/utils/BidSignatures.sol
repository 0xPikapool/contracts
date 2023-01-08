// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

abstract contract BidSignatures is Test {
    /// @dev Struct of bid data to be hashed and signed for meta-transactions.
    /// @param auctionName The name of the creator's NFT collection being auctioned
    /// @param auctionAddress The address of the creator NFT being bid on. Becomes a string off-chain.
    /// @param bidder The address of the bid's originator, similar to tx.origin.
    /// @param amount The number of assets being bid on.
    /// @param basePrice The base price per NFT set by the collection's creator
    /// @param tip The tip per NFT offered by the bidder in order to win a mint in the auction
    struct Bid {
        string auctionName;
        address auctionAddress;
        address bidder;
        uint256 amount;
        uint256 basePrice;
        uint256 tip;
    }

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Mail {
        string auctionName;
        address auctionAddress;
        address bidder;
        uint256 amount;
        uint256 basePrice;
        uint256 tip;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 constant MAIL_TYPEHASH =
        keccak256(
            "Bid(string auctionName,address auctionAddress,address bidder,uint256 amount,uint256 basePrice,uint256 tip)"
        );

    bytes32 DOMAIN_SEPARATOR_MAIL;

    /// @dev The EIP-712 type hash for the Bid struct
    bytes32 internal constant BID_TYPE_HASH =
        keccak256(
            "Bid(string auctionName,address auctionAddress,uint256 amount,uint256 basePrice,uint256 tip)"
        );

    /// @dev The EIP-712 domain type hash, required to derive domain separator
    bytes32 internal constant DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /// @dev The EIP-712 domain name, required to derive domain separator
    bytes32 internal constant DOMAIN_NAME = keccak256("PikaPool Auction");

    /// @dev The EIP-712 domain version, required to derive domain separator
    bytes32 internal constant DOMAIN_VERSION = keccak256("1");

    /// @dev The EIP-712 domain separator, required to prevent replay attacks across networks
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @dev Event emitted when a bid is signed.
    //todo
    // event Signature(address indexed owner, bytes bidData, bool revoked);

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
        DOMAIN_SEPARATOR_MAIL = hash(
            EIP712Domain({
                name: "Ether Mail",
                version: "1",
                chainId: 1,
                verifyingContract: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC
            })
        );
    }

    function hash(EIP712Domain memory eip712Domain)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    function test() public view returns (bool) {
        // Example signed message
        Mail memory mail = Mail({
            auctionName: "TestNFT",
            auctionAddress: address(0xDD23B2f4cc41914a6BDa77310126251a2556B865),
            bidder: address(0x36bCaEE2F1f6C185f91608C7802f6Fc4E8bD9f1d),
            amount: 5,
            basePrice: 69,
            tip: 420
        });
        // uint8 v = 28;
        // bytes32 r = 0x4355c47d63924e8a72e509b65029052eb6c299d53a04e167c5775fd466751c9d;
        // bytes32 s = 0x07299936d304c153f6443dfa05f40ff007d72911b6f72307f996231605b91562;

        console.logString("maikkklhash");
        console.logBytes32(hash(mail));
        assert(
            DOMAIN_SEPARATOR_MAIL ==
                0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f
        );
        assert(
            hash(mail) ==
                0xa68720e40b22ac61392ad759e2bf5c266c18eb0b0af58b861a7f119a21dc6e53
        );
        // assert(verify(mail, v, r, s));
        return true;
    }

    function hash(Mail memory mail) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MAIL_TYPEHASH,
                    keccak256(bytes(mail.auctionName)),
                    mail.auctionAddress,
                    mail.bidder,
                    mail.amount,
                    mail.basePrice,
                    mail.tip
                )
            );
    }

    /// @dev Function to compute hash of a bid
    function hashBid(Bid memory bid) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    BID_TYPE_HASH,
                    bid.auctionName,
                    bid.auctionAddress,
                    bid.bidder,
                    bid.amount,
                    bid.basePrice,
                    bid.tip
                )
            );
    }

    /// @dev Function to compute hash of fully EIP-712 encoded message for the domain to be used with ecrecover()
    function hashTypedData(Bid memory bid) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashBid(bid))
            );
    }
}
