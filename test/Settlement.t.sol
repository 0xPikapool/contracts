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

    uint256 public priceInGweth;
    uint256 internal bidderPrivateKey;
    uint256 internal bidder2PrivateKey;
    address internal bidder;
    address internal bidder2;
    bytes public err;

    // initialize test environment
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        priceInGweth = 69;

        settlement = new Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30);
        pikaExample = new Example721A(priceInGweth);

        // prepare the cow carcass private key with which to sign
        bidderPrivateKey = 0xDEADBEEF;
        bidder = vm.addr(bidderPrivateKey);
        // seed cow carcass bidder with 1 eth and wrap it to weth
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder), 1 ether);
        // create new beefy bidder for second signature
        bidder2PrivateKey = 0xBEEF;
        bidder2 = vm.addr(bidder2PrivateKey);
        // seed cow bidder with 1 eth and wrap it to weth
        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder2), 1 ether);
    }

function test_settleFromSignatureWithPayment() public {
        // bidder approves totalWeth amount to weth contract
        vm.prank(bidder);
        weth.approve(address(settlement), 2139);
        assertEq(weth.allowance(bidder, address(settlement)), 2139);

        BidSignatures.Bid memory bid = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder,
            amount: settlement.mintMax(),
            basePrice: priceInGweth,
            tip: 69,
            totalWeth: 2139
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
        // assert weth payment was made to settlement contract
        assertEq(weth.balanceOf(address(settlement)), 2139);
    }

    function test_finalizeAuction() public {
        // bidder approves totalWeth amount to weth contract
        vm.prank(bidder);
        weth.approve(address(settlement), 2139);
        assertEq(weth.allowance(bidder, address(settlement)), 2139);
        // repeat for bidder2
        vm.prank(bidder2);
        weth.approve(address(settlement), 2139);
        assertEq(weth.allowance(bidder2, address(settlement)), 2139);

        // formulate the signatures
        BidSignatures.Bid memory bid1 = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder,
            amount: settlement.mintMax(),
            basePrice: priceInGweth,
            tip: 69,
            totalWeth: 2139
        });
        bytes32 digest = settlement.hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });

        BidSignatures.Bid memory bid2 = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder2,
            amount: settlement.mintMax(),
            basePrice: priceInGweth,
            tip: 69,
            totalWeth: 2139
        });
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
        assertEq(pikaExample.balanceOf(bidder), bid1.amount);
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(weth.balanceOf(address(settlement)), bid1.totalWeth + bid2.totalWeth);
        
        //assert owners of nfts are correct

    }
}

//function to test revert due to missing approval
//function to test single mint
//function to test full 30 mint
//function to test revert on 0 mint
//function to test revert on 31 mints