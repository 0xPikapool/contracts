// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

contract BidSignaturesTest is Test {
    
    // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
    Settlement public settlement;
    Example721A public pikaExample;

    uint256 public price;
    uint256 internal bidderPrivateKey;
    address internal bidder;
    bytes public err;

    // initialize test environment
    function setUp() public {
        price = 69;

        settlement = new Settlement();
        pikaExample = new Example721A(price);

        // prepare the cow carcass private key with which to sign
        bidderPrivateKey = 0xDEADBEEF;
        bidder = vm.addr(bidderPrivateKey);
    }

    function test_settleFromSignature() public {
        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder,
            amount: settlement.mintMax(),
            basePrice: price,
            tip: 69,
            totalWeth: 14670
        });

        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s
        );

        uint256 balance = pikaExample.balanceOf(bidder);
        assertEq(balance, bid.amount);

        // ERC721A defaults to _startTokenId() == 0, causing _currentIndex to be 0
        // that is acceptable for this test, projects wishing to begin tokenIds at 1 should override that function
        for (uint i; i < bid.amount; ++i) {
            address recipient = pikaExample.ownerOf(i);
            assertEq(recipient, bid.bidder);
        }
    }

    function testRevert_InvalidSignature() public {
        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder,
            amount: settlement.mintMax(),
            basePrice: price,
            tip: 69,
            totalWeth: 14670
        });

        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        err = abi.encodeWithSignature("InvalidSignature()");
        vm.expectRevert(err);

        // provide signature data using wrong auctionName
        settlement.settleFromSignature(
            "Hello World",
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s ^ r
        );

        vm.expectRevert(err);

        // provide signature data using wrong NFT mint address (address(this) != bidder)
        settlement.settleFromSignature(
            bid.auctionName,
            address(0xbeef),
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,            
            v,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong bidder address (bidder != address(this))
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            address(this),
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong NFT mint amount (68 != 69)
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount -= 1,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong basePrice
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice -= 1,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong tip
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip -= 1,
            bid.totalWeth,
            v,
            r,
            s
        );

        vm.expectRevert(err);
        
        // provide signature data using wrong totalWeth
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth -= 1,
            v,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong v
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v -= 1,
            r,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong r (XOR against s)
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r ^ s,
            s
        );

        vm.expectRevert(err);

        // provide signature data using wrong s (XOR against r)
        settlement.settleFromSignature(
            bid.auctionName,
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.basePrice,
            bid.tip,
            bid.totalWeth,
            v,
            r,
            s ^ r
        );
    }
}
