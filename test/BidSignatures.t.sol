// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

/// This contract inherits Settlement so that it can isolate settleFromSignature() logic from payment mechanics
contract BidSignaturesTest is
    Test,
    Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30)
{
    /// @dev Error to revert execution if ecrecover returns invalid signature originator
    error InvalidSignature();

    // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
    Settlement public settlement;
    Example721A public pikaExample;

    BidSignatures.Bid bid;
    uint256 public priceInGweth;
    string name;
    string symbol;
    uint256 internal bidder1PrivateKey;
    address internal bidder1;
    address internal mainnetWETH;
    bytes public err;

    // initialize test environment
    function setUp() public {
        name = "PikaExample";
        symbol = "PIKA";
        priceInGweth = 69;
        mainnetWETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        settlement = new Settlement(mainnetWETH, 30);
        pikaExample = new Example721A(
            name,
            symbol,
            address(settlement),
            priceInGweth
        );

        // prepare the cow carcass private key with which to sign
        bidder1PrivateKey = 0xDEADBEEF;
        bidder1 = vm.addr(bidder1PrivateKey);

        // prepare the bid to be used
        bid = BidSignatures.Bid({
            auctionName: name,
            auctionAddress: address(pikaExample),
            bidder: bidder1,
            amount: mintMax,
            basePrice: priceInGweth,
            tip: 69
        });
    }

    function test_exampleBid() public {
        // Settlement Address and chainId are from the DOMAIN_SEPARATOR
        // and are used in determining the hash, so make sure they match the
        // expected values here
        assertEq(
            address(settlement),
                address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f)
        );
        assertEq(block.chainid, 31337);

        Bid memory bid = Bid({
            auctionName: "TestNFT",
            auctionAddress: address(0xDD23B2f4cc41914a6BDa77310126251a2556B865),
            bidder: address(0x36bCaEE2F1f6C185f91608C7802f6Fc4E8bD9f1d),
            amount: 5,
            basePrice: 69,
            tip: 420
        });

        bytes32 ds = settlement.DOMAIN_SEPARATOR();
        assertEq(
            ds,
                0x18306b2971eca0ce9ff1e0da35bba87fd0039f43ab55f13399c9511bb2deb8bc
        );
        assertEq(
            settlement.hashBid(bid),
                0xa68720e40b22ac61392ad759e2bf5c266c18eb0b0af58b861a7f119a21dc6e53
        );
        assertEq(
            settlement.hashTypedData(bid),
                0x2a7503ca8eb3ae96c121dd7c847663564727b6b0e49b49a97c4a3476ddb3ede1
        );
    }

    function test_settleFromSignature() public {
        bytes32 digest = hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        // extracted the settleFromSignature() logic without payment to isolate and verify signature functionality
        uint256 amount = bid.amount;

        if (amount <= mintMax) {
            bool settle = settleFromSignature(
                bid.auctionName,
                bid.auctionAddress,
                bid.bidder,
                bid.amount,
                bid.basePrice,
                bid.tip,
                v,
                r,
                s
            );
            assertTrue(settle);
        }
    }

    function test_invalidSignature() public {
        bytes32 digest = hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        bool a;
        // provide signature data using wrong auctionName
        a = settleFromSignature(
            "Hello World",
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong NFT mint address (address(this) != bidder1)
        a = settleFromSignature(
            bid.auctionName,
            address(0xbeef),
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong bidder address (bidder1 != address(this))
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            address(this),
            bid.amount,
            bid.basePrice,
            bid.tip,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong NFT mint amount (68 != 69)
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount -= 1,
            bid.basePrice,
            bid.tip,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong basePrice
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice -= 1,
            bid.tip,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong tip
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip -= 1,
            v,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong v
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            v -= 1,
            r,
            s
        );
        assertFalse(a);

        // provide signature data using wrong r (XOR against s)
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            v,
            r ^ s,
            s
        );
        assertFalse(a);

        // provide signature data using wrong s (XOR against r)
        a = settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            v,
            r,
            s ^ r
        );
        assertFalse(a);
    }
}
