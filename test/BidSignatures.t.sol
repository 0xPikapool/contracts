// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

address payable constant mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

/// This contract inherits Settlement so that it may test internal function logic
/// BidSignatures utility contract is instantianted by this test contract's inheritance
/// It does not need to be instantiated directly since it is abstract and parent to Settlement
contract BidSignaturesTest is
    Test,
    Settlement(mainnetWETH, 30)
{
    /// @dev Error to revert execution if ecrecover returns invalid signature originator
    error InvalidSignature();

    Example721A public pikaExample;

    BidSignatures.Bid bid;
    uint256 public priceInGweth;
    string name;
    string symbol;
    uint256 internal bidder1PrivateKey;
    address internal bidder1;
    bytes public err;

    // initialize test environment
    function setUp() public {
        name = "PikaExample";
        symbol = "PIKA";
        priceInGweth = 69;

        // zero address used as placeholder for revenue recipient
        pikaExample = new Example721A(
            name,
            symbol,
            address(this),
            address(0x0),
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

    function test__verifySignature() public {
        bytes32 digest = hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        // test _verifySignature() logic without payment to isolate and verify signature functionality
        uint256 amount = bid.amount;

        if (amount <= mintMax) {
            bool settle = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
        a = _verifySignature(
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
