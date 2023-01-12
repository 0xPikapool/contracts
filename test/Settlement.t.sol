// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

address payable constant mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

contract SettlementTest is Test, Settlement(mainnetWETH, 30) {

    Example721A public pikaExample;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    string name;
    string symbol;
    uint256 public priceInGweth;
    uint256 internal bidder1PrivateKey;
    uint256 internal bidder2PrivateKey;
    uint256 internal bidder3PrivateKey;
    address internal bidder1;
    address internal bidder2;
    address internal bidder3;
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

        pikaExample = new Example721A(name, symbol, address(this), priceInGweth);

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

        // create new beefy bidder for third signature
        bidder3PrivateKey = 0xBABE;
        bidder3 = vm.addr(bidder3PrivateKey);
        // seed cow bidder with 1 eth and wrap it to weth
        vm.deal(bidder3, 1 ether);
        vm.prank(bidder3);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder3), 1 ether);

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

        bid3 = BidSignatures.Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder3,
            amount: 12,
            basePrice: priceInGweth,
            tip: 420
        });
    }

function test_settle() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(this), totalWeth);
        assertEq(weth.allowance(bidder1, address(this)), totalWeth);

        bytes32 digest = hashTypedData(bid1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        bool settle = _verifySignature(
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
            _settle(
                bid1.auctionAddress,
                bid1.bidder,
                bid1.amount,
                bid1.basePrice,
                bid1.tip
            );
        }

        // assert weth payments were made
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(address(pikaExample).balance, totalWeth);

        // assert NFT balances are correct
        uint minted = pikaExample.balanceOf(bid1.bidder);
        assertEq(minted, bid1.amount);

        // assert owner of minted NFTs is correct
        for (uint i; i < bid1.amount; ++i) {
            address recipient = pikaExample.ownerOf(i);
            assertEq(recipient, bid1.bidder);
        }
    }

    function test_finalizeAuction() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(this), totalWeth);
        assertEq(weth.allowance(bidder1, address(this)), totalWeth);

        bytes32 digest = hashTypedData(bid1);
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
        weth.approve(address(this), totalWeth2);
        assertEq(weth.allowance(bidder2, address(this)), totalWeth2);

        bytes32 digest2 = hashTypedData(bid2);
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

        // feed the signatures externally into this contract hat inherits Settlement
        this.finalizeAuction(signatures);

        // assert payments were processed correctly
        assertEq(pikaExample.balanceOf(bidder1), bid1.amount);
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(weth.balanceOf(address(this)), 0);
        
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

    function test_skipSingleInsufficientApproval() public {
        // bid and finalize with no approval
        bytes32 digest = hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });

        Signature[] memory signature = new Signature[](1);
        signature[0] = signature1;

        this.finalizeAuction(signature);
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);

        // bid and finalize with nonzero but insufficient approval
        vm.prank(bidder1);
        weth.approve(address(this), 5);
        assertEq(weth.allowance(bidder1, address(this)), 5);

        this.finalizeAuction(signature);
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
    }

    function test_skipInsufficientApprovals() public {
        // bid and finalize multiple signatures with one bid missing approval
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approval
        vm.prank(bidder1);
        weth.approve(address(this), totalWeth);
        assertEq(weth.allowance(bidder1, address(this)), totalWeth);

        bytes32 digest = hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });
        
        // bidder2 does NOT provide sufficient approval
        uint256 notEnough = 10;
        vm.prank(bidder2);
        weth.approve(address(this), notEnough);
        assertEq(weth.allowance(bidder2, address(this)), notEnough);

        bytes32 digest2 = hashTypedData(bid2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder2PrivateKey, digest2);
        Signature memory signature2 = Signature({
            bid: bid2,
            v: v2,
            r: r2,
            s: s2
        });

        // bidder3 provides correct approval
        uint256 totalWeth3 = bid3.amount * bid3.basePrice + bid3.tip;
        vm.prank(bidder3);
        weth.approve(address(this), totalWeth3);
        assertEq(weth.allowance(bidder3, address(this)), totalWeth3);

        // compute final total of payment that should succeed upon settlement
        uint256 finalPayment = totalWeth + totalWeth3;

        bytes32 digest3 = hashTypedData(bid3);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(bidder3PrivateKey, digest3);
        Signature memory signature3 = Signature({
            bid: bid3,
            v: v3,
            r: r3,
            s: s3
        });

        Signature[] memory signatures = new Signature[](3);
        signatures[0] = signature1;
        signatures[1] = signature2;
        signatures[2] = signature3;
        this.finalizeAuction(signatures);

        // assert WETH transfers were completed by bidder1, bidder3
        assertEq(address(pikaExample).balance, finalPayment);
        assertEq(weth.balanceOf(address(this)), 0);

        // assert NFTs were minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), bid1.amount);
        // assert NFTs were NOT minted to bidder2
        assertEq(pikaExample.balanceOf(bidder2), 0);
        // assert NFTs were minted to bidder3
        assertEq(pikaExample.balanceOf(bidder3), bid3.amount);

        // assert correct NFT ownership
        for (uint i; i < pikaExample.totalSupply(); ++i) {
            address recipient = pikaExample.ownerOf(i);
            if (i < bid1.amount) {
                assertEq(recipient, bidder1);
            } else {
                assertEq(recipient, bidder3);
            }
        }
    }

    // test skipping a single bidder with insufficient balance
    function test_skipSingleInsufficientWETHBalance() public {
        // test skip single insufficient WETH balance
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approval
        vm.startPrank(bidder1);
        weth.approve(address(this), totalWeth);
        assertEq(weth.allowance(bidder1, address(this)), totalWeth);

        // bidder1 spends all WETH, leaving none for the settlement
        weth.transfer(address(0x0), weth.balanceOf(bidder1));
        vm.stopPrank();
        assertEq(weth.balanceOf(bidder1), 0);
        
        bytes32 digest = hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });

        Signature[] memory signature = new Signature[](1);
        signature[0] = signature1;

        this.finalizeAuction(signature);
        // assert WETH transfer was not completed due to insufficient balamnce
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
        // assert pikaExample did not receive any eth
        assertEq(address(pikaExample).balance, 0);
    }

        // test skipping insufficient balances within multiple signatures
        function test_skipInsufficientWETHBalances() public {
            // bidders make approvals
            vm.prank(bidder1);
            weth.approve(address(this), 1 ether);
            assertEq(weth.allowance(bidder1, address(this)), 1 ether);
            vm.prank(bidder2);
            weth.approve(address(this), 1 ether);
            assertEq(weth.allowance(bidder2, address(this)), 1 ether);
            vm.startPrank(bidder3);
            weth.approve(address(this), 1 ether);
            assertEq(weth.allowance(bidder3, address(this)), 1 ether);

            // bidder3 spends their WETH before auction settlement
            weth.transfer(address(0x0), 1 ether);
            vm.stopPrank();
            assertEq(weth.balanceOf(bidder3), 0);

            // prepare digests
            bytes32 digest = hashTypedData(bid1);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
            Signature memory signature1 = Signature({
                bid: bid1,
                v: v,
                r: r,
                s: s
            });
            bytes32 digest2 = hashTypedData(bid2);
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder2PrivateKey, digest2);
            Signature memory signature2 = Signature({
                bid: bid2,
                v: v2,
                r: r2,
                s: s2
            });
            bytes32 digest3 = hashTypedData(bid3);
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(bidder3PrivateKey, digest3);
            Signature memory signature3 = Signature({
                bid: bid3,
                v: v3,
                r: r3,
                s: s3
            });

            // compute final total of payment that should succeed upon settlement
            uint256 finalPayment = (bid1.amount * bid1.basePrice + bid1.tip) + (bid2.amount * bid2.basePrice + bid2.tip);

            // create signature array
            Signature[] memory signatures = new Signature[](3);
            signatures[0] = signature1;
            signatures[1] = signature2;
            signatures[2] = signature3;

            // feed signatures externally to this contract's Settlement inheritance
            this.finalizeAuction(signatures);

            // assert payments were completed
            assertEq(weth.balanceOf(bidder1), 1 ether - (bid1.amount * bid1.basePrice + bid1.tip));
            assertEq(weth.balanceOf(bidder2), 1 ether - (bid2.amount * bid2.basePrice + bid2.tip));
            assertEq(weth.balanceOf(address(this)), 0);
            assertEq(address(pikaExample).balance, finalPayment);

            // assert NFTs were minted to bidder1, bidder3
            assertEq(pikaExample.balanceOf(bidder1), bid1.amount);
            assertEq(pikaExample.balanceOf(bidder2), bid2.amount);

            // assert NFT was not minted to bidder3
            assertEq(pikaExample.balanceOf(bidder3), 0);
    }

    function test_skipSpentSigNonces() public {
        // bidder2 and bidder3 make approvals
        vm.prank(bidder2);
        weth.approve(address(this), 1 ether);
        assertEq(weth.allowance(bidder2, address(this)), 1 ether);
        vm.prank(bidder3);
        weth.approve(address(this), 1 ether);
        assertEq(weth.allowance(bidder3, address(this)), 1 ether);

        // prepare digests
        bytes32 digest = hashTypedData(bid1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });
        bytes32 digest2 = hashTypedData(bid2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder2PrivateKey, digest2);
        Signature memory signature2 = Signature({
            bid: bid2,
            v: v2,
            r: r2,
            s: s2
        });
        bytes32 digest3 = hashTypedData(bid3);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(bidder3PrivateKey, digest3);
        Signature memory signature3 = Signature({
            bid: bid3,
            v: v3,
            r: r3,
            s: s3
        });

        // intentionally fail a signature submission via allowance to attempt replay attack
        Signature[] memory signature = new Signature[](1);
        signature[0] = signature1;

        this.finalizeAuction(signature);
        // assert payment was not completed
        assertEq(address(pikaExample).balance, 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
        // assert signature was marked spent
        bytes32 sigHash = 
            keccak256(
                abi.encodePacked(
                    signature1.v, 
                    signature1.r, 
                    signature1.s
                )
            );
        bool spentSig = spentSigNonces[sigHash];
        assertTrue(spentSig);

        // bidder1 belatedly makes approval
        vm.prank(bidder1);
        weth.approve(address(this), 1 ether);
        assertEq(weth.allowance(bidder1, address(this)), 1 ether);

        // calculate expected payment amount
        uint256 finalPayment = (bid2.amount * bid2.basePrice + bid2.tip) + (bid3.amount * bid3.basePrice + bid3.tip);

        // create signature array
        Signature[] memory signatures = new Signature[](3);
        signatures[0] = signature3;
        signatures[1] = signature1;
        signatures[2] = signature2;

        // attempt signature replay attack
        this.finalizeAuction(signatures);
        // assert payment completed only for signature2 and signature3
        assertEq(address(pikaExample).balance, finalPayment);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
        // assert NFTs were minted to bidder2 and bidder3
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(pikaExample.balanceOf(bidder3), bid3.amount);
        // assert signature still marked spent
        bool stillSpent = spentSigNonces[sigHash];
        assertTrue(stillSpent);
    }

    // prove that internal _settle call within unchecked block does not inherit unchecked property
    function test_settleUncheckedCannotOverflow() public {
        Bid memory overflowBid = Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder1,
            amount: 30,
            basePrice: type(uint256).max,
            tip: type(uint256).max
        });

        vm.prank(bidder1);
        weth.approve(address(this), type(uint256).max);

        bytes32 digest = hashTypedData(overflowBid);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory overflowSig = Signature({
            bid: overflowBid,
            v: v,
            r: r,
            s: s
        });

        Signature[] memory cannotOverflow = new Signature[](1);
        cannotOverflow[0] = overflowSig;

        vm.expectRevert();
        this.finalizeAuction(cannotOverflow);
    }


    //function to test no mint on 0 amount
    //function to test no mint on >mintMax mints

    //function to test event emission correctness
}
