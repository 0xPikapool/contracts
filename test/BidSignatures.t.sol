// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

/// This contract inherits Settlement so that it can isolate settleFromSignature() logic from payment mechanics
contract BidSignaturesTest is Test, Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30) {
    
    // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
    Settlement public settlement;
    Example721A public pikaExample;

    BidSignatures.Bid bid;
    uint256 public priceInGweth;
    uint256 internal bidderPrivateKey;
    address internal bidder;
    bytes public err;

    // initialize test environment
    function setUp() public {
        priceInGweth = 69;

        settlement = new Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30);
        pikaExample = new Example721A(priceInGweth);

        // prepare the cow carcass private key with which to sign
        bidderPrivateKey = 0xDEADBEEF;
        bidder = vm.addr(bidderPrivateKey);

        // prepare the bid to be used
        bid = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder,
            amount: settlement.mintMax(),
            basePrice: priceInGweth,
            tip: 69,
            totalWeth: 2139
        });
    }

    function test_settleFromSignature() public {
        bytes32 digest = settlement.hashTypedData(bid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        // extracted the settleFromSignature() logic without payment to isolate and verify signature functionality
        uint256 amount = bid.amount;
        if (amount > settlement.mintMax()) revert ExcessAmount();

        address recovered = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    settlement.DOMAIN_SEPARATOR(),
                    // gas optimization of BidSignatures.hashBid(): calldata < mstore/mload !
                    keccak256(
                        abi.encode(
                            BID_TYPE_HASH,
                            // keccak256("Bid(string auctionName,address auctionAddress,uint256 amount,uint256 basePrice,uint256 tip,uint256 totalWeth)"),
                            bid.auctionName,
                            bid.auctionAddress,
                            bid.bidder,
                            bid.amount,
                            bid.basePrice,
                            bid.tip,
                            bid.totalWeth
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        // handle signature error cases
        if (recovered == address(0) || recovered != bidder) revert InvalidSignature();

        // _settle() without payment mechanics
        (bool m,) = bid.auctionAddress.call(abi.encodeWithSignature("mint(address,uint256)", bid.bidder, bid.amount));
        if (!m) revert MintFailure();

        // check settlement was successful
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
