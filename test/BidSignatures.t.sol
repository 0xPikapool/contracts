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
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder1,
            amount: mintMax,
            basePrice: priceInGweth,
            tip: 69
        });
    }

    function test_mail_example() public {
        bool success = BidSignatures.test();
        assert(success);
    }

    // function test_settleFromSignature() public {
    //     bytes32 digest = hashTypedData(bid);

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

    //     // extracted the settleFromSignature() logic without payment to isolate and verify signature functionality
    //     uint256 amount = bid.amount;

    //     if (amount <= mintMax) {
    //         bool settle = settleFromSignature(
    //             bid.auctionName,
    //             bid.auctionAddress,
    //             bid.bidder,
    //             bid.amount,
    //             bid.basePrice,
    //             bid.tip,
    //             v,
    //             r,
    //             s
    //         );
    //         assertTrue(settle);
    //     }
    // }

    // function test_invalidSignature() public {
    //     bytes32 digest = hashTypedData(bid);

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

    //     bool a;
    //     // provide signature data using wrong auctionName
    //     a = settleFromSignature(
    //         "Hello World",
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong NFT mint address (address(this) != bidder1)
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         address(0xbeef),
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong bidder address (bidder1 != address(this))
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         address(this),
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong NFT mint amount (68 != 69)
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount -= 1,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong basePrice
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice -= 1,
    //         bid.tip,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong tip
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip -= 1,
    //         v,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong v
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v -= 1,
    //         r,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong r (XOR against s)
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r ^ s,
    //         s
    //     );
    //     assertFalse(a);

    //     // provide signature data using wrong s (XOR against r)
    //     a = settleFromSignature(
    //         bid.auctionName,
    //         bid.auctionAddress,
    //         bid.bidder,
    //         bid.amount,
    //         bid.basePrice,
    //         bid.tip,
    //         v,
    //         r,
    //         s ^ r
    //     );
    //     assertFalse(a);
    // }
}
