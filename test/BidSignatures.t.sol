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

    // function testRevert_AuctionConcluded() public {}
    // function testRevert_InvalidSignature() public {}
}
