// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/utils/BidSignatures.sol";

contract BidSignaturesTest is Test {
    
    // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
    Settlement public settlement;

    uint256 internal bidderPrivateKey;
    address internal bidder;
    bytes public err;

    // initialize test environment
    function setUp() public {
        settlement = new Settlement();

        // prepare the cow carcass private key with which to sign
        bidderPrivateKey = 0xDEADBEEF;
        bidder = vm.addr(bidderPrivateKey);
    }

    function test_settleFromSignature() public {
        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionAddress: address(this),
            bidder: bidder,
            amount: 69,
            blockDeadline: 16969696
        });

        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        settlement.settleFromSignature(
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.blockDeadline,
            v,
            r,
            s
        );

        address placeholder = settlement.auctionIds(bid.amount);
        assertEq(placeholder, bid.auctionAddress);
    }

    function testRevert_AuctionConcluded() public {
        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionAddress: address(this),
            bidder: bidder,
            amount: 69,
            blockDeadline: 16969696
        });

        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        // fast forward to one block past blockDeadline
        vm.roll(16969697);

        err = abi.encodeWithSignature("AuctionDeadlineConcluded()");
        vm.expectRevert(err);

        settlement.settleFromSignature(
            bid.auctionAddress,
            bid.bidder,
            bid.amount,
            bid.blockDeadline,
            v,
            r,
            s
        );
    }

    function testRevert_InvalidSignature() public {
        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionAddress: address(this),
            bidder: bidder,
            amount: 69,
            blockDeadline: 16969696
        });

        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        err = abi.encodeWithSignature("InvalidSignature()");
        vm.expectRevert(err);

        // provide signature data using wrong NFT mint amount (68 != 69)
        settlement.settleFromSignature(
            bid.auctionAddress,
            bid.bidder,
            bid.amount -= 1,
            bid.blockDeadline,
            v,
            r,
            s
        );
    }
}
