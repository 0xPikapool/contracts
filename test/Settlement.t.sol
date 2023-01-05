// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

contract SettlementTest is Test, Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30) {

    Settlement public settlement;
    Example721A public pikaExample;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    string name;
    string symbol;
    uint256 public priceInGweth;
    uint256 internal bidder1PrivateKey;
    uint256 internal bidder2PrivateKey;
    address internal bidder1;
    address internal bidder2;
    BidSignatures.Bid bid1;
    BidSignatures.Bid bid2;
    BidSignatures.Bid bid3;
    bytes public err;

    // initialize test environment
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        name = "PikaExample";
        symbol = "PIKA";
        priceInGweth = 69;

        settlement = new Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30);
        pikaExample = new Example721A(name, symbol, address(settlement), priceInGweth);

        // prepare the cow carcass private key with which to sign
        bidder1PrivateKey = 0xDEADBEEF;
        bidder1 = vm.addr(bidder1PrivateKey);
        // seed cow carcass bidder1 with 1 eth and wrap it to weth
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder1), 1 ether);

        // create new beefy bidder for second signature
        bidder2PrivateKey = 0xBEEF;
        bidder2 = vm.addr(bidder2PrivateKey);
        // seed cow bidder with 1 eth and wrap it to weth
        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder2), 1 ether);

        // prepare bids
        bid1 = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder1,
            amount: mintMax,
            basePrice: priceInGweth,
            tip: 69
        });

        bid2 = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder2,
            amount: mintMax,
            basePrice: priceInGweth,
            tip: 42
        });
    }

function test_settle() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(settlement), totalWeth);
        assertEq(weth.allowance(bidder1, address(settlement)), totalWeth);

        bytes32 digest = hashTypedData(bid1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        bool settle = settleFromSignature(
            bid1.auctionName,
            bid1.auctionAddress,
            bid1.bidder,
            bid1.amount,
            bid1.basePrice,
            bid1.tip,
            v,
            r,
            s
        );

        if (settle) {
            // extracted internal _settle() function logic (due to Foundry address(this) context)
            vm.prank(address(settlement));
            bool p = weth.transferFrom(bidder1, address(this), bid1.amount * bid1.basePrice + bid1.tip);

            // if weth transfer succeeds, unwrap weth to eth and pay for creator's NFT mint
            // create a gas table for these steps as they add more gas overhead than they're worth
        if (p) {
            weth.withdraw(bid1.amount * bid1.basePrice);
            // auctionAddress.mint{ value: ethAmt=basePrice }()
        }

        // (bool r,) = auctionAddress.call(abi.encodeWithSignature("mint(address,uint256)", bidder, amount));
        // if (!r) revert MintFailure();
        }

        // assert weth payment was made to _this_ contract (due to inherited address(this) logic)
        assertEq(weth.balanceOf(address(this)), bid1.tip);
    }

    function test_finalizeAuction() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(settlement), totalWeth);
        assertEq(weth.allowance(bidder1, address(settlement)), totalWeth);

        bytes32 digest = settlement.hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });
        
        // repeat for bidder2
        uint256 totalWeth2 = bid2.amount * bid2.basePrice + bid2.tip;
        vm.prank(bidder2);
        weth.approve(address(settlement), totalWeth2);
        assertEq(weth.allowance(bidder2, address(settlement)), totalWeth2);

        bytes32 digest2 = settlement.hashTypedData(bid2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder2PrivateKey, digest2);
        Signature memory signature2 = Signature({
            bid: bid2,
            v: v2,
            r: r2,
            s: s2
        });

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        // feed the signatures into Settlement.sol
        settlement.finalizeAuction(signatures);
        assertEq(pikaExample.balanceOf(bidder1), bid1.amount);
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(weth.balanceOf(address(settlement)), bid1.tip + bid2.tip);
        
        // assert owners of nfts are correct
        // ERC721A defaults to _startTokenId() == 0, causing _currentIndex to be 0
        // that is acceptable for this test, projects wishing to begin tokenIds at 1 should override that function
        for (uint i; i < bid1.amount + bid2.amount; ++i) {
            address recipient = pikaExample.ownerOf(i);
            if (i < bid1.amount) {
                assertEq(recipient, bidder1);
            } else {
                assertEq(recipient, bidder2);
            }
        }
    }
}

//function to test revert due to missing approval
//function to test single mint
//function to test full 30 mint
//function to test revert on 0 mint
//function to test revert on 31 mints
