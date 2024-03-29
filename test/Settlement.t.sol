// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "./utils/TestUtils.sol";

contract SettlementTest is TestUtils { 

    // ensure test environment was properly initialized
    function test_setUp() public {
        assertEq(vm.activeFork(), mainnetFork);
        assertEq(weth.balanceOf(bidder1), 1 ether);
        assertEq(weth.balanceOf(bidder2), 1 ether);
        assertEq(weth.balanceOf(bidder3), 1 ether);
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

        bool testSettle;
        if (settle) {
            testSettle = _settle(bid1);
        }

        // assert both calls returned true
        assertTrue(settle);
        assertTrue(testSettle);
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

        // assert mint events are emitted as Solmate Transfers
        for (uint256 i; i < bid1.amount + bid2.amount; ++i) {
            vm.expectEmit(true, true, false, true);
            if (i < 30) {
                emit Transfer(address(0x0), bid1.bidder, i);
            } else {
                emit Transfer(address(0x0), bid2.bidder, i);
            }
        }
        // feed the signatures externally into this contract hat inherits Settlement
        this.finalizeAuction(signatures);

        // assert payments were processed correctly
        assertEq(auctionA.balanceOf(bidder1), bid1.amount);
        assertEq(auctionA.balanceOf(bidder2), bid2.amount);
        assertEq(weth.balanceOf(address(this)), 0);
        
        // assert owners of nfts are correct
        // ERC721A defaults to _startTokenId() == 0, causing _currentIndex to be 0
        // that is acceptable for this test, projects wishing to begin tokenIds at 1 should override that function
        for (uint i; i < bid1.amount + bid2.amount; ++i) {
            address recipient = auctionA.ownerOf(i);
            if (i < bid1.amount) {
                assertEq(recipient, bidder1);
            } else {
                assertEq(recipient, bidder2);
            }
        }
    }

    function test_skipZeroAmountMints() public {
        // create bid with 0 as amount
        BidSignatures.Bid memory bid0 = Bid({
            auctionName: "TestNFT",
            auctionAddress: address(auctionA),
            bidder: bidder1,
            amount: 0,
            basePrice: auctionPriceA,
            tip: 69
        });

        // make approval
        vm.prank(bidder1);
        weth.approve(address(this), bid0.tip);
        assertEq(weth.allowance(bidder1, address(this)), bid0.tip);

        bytes32 digest = hashTypedData(bid0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature0 = Signature({
            bid: bid0,
            v: v,
            r: r,
            s: s
        });

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature0;

        this.finalizeAuction(signatures);

        // check that no mints occurred without reverts
        uint256 zero = auctionA.totalSupply();
        assertEq(zero, 0);
        uint256 none = auctionA.balanceOf(bid0.bidder);
        assertEq(none, 0);
        vm.expectRevert();
        auctionA.ownerOf(0);
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

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Payment Failed");
        this.finalizeAuction(signature);
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);

        // bid and finalize with nonzero but insufficient approval
        vm.prank(bidder2);
        weth.approve(address(this), 5);
        assertEq(weth.allowance(bidder2, address(this)), 5);

        digest = hashTypedData(bid2);
        (v, r, s) = vm.sign(bidder2PrivateKey, digest);
        Signature memory signature2 = Signature({
            bid: bid2,
            v: v,
            r: r,
            s: s
        });

        signature[0] = signature2;

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature2.bid.bidder, "Payment Failed");
        this.finalizeAuction(signature);
        
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
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

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature2.bid.bidder, "Payment Failed");
        this.finalizeAuction(signatures);

        // assert WETH transfers were completed by bidder1, bidder3
        assertEq(address(auctionA).balance, finalPayment);
        assertEq(weth.balanceOf(address(this)), 0);

        // assert NFTs were minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), bid1.amount);
        // assert NFTs were NOT minted to bidder2
        assertEq(auctionA.balanceOf(bidder2), 0);
        // assert NFTs were minted to bidder3
        assertEq(auctionA.balanceOf(bidder3), bid3.amount);

        // assert correct NFT ownership
        for (uint i; i < auctionA.totalSupply(); ++i) {
            address recipient = auctionA.ownerOf(i);
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

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Payment Failed");
        this.finalizeAuction(signature);
        
        // assert WETH transfer was not completed due to insufficient balamnce
        assertEq(weth.balanceOf(address(this)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
        // assert auctionA did not receive any eth
        assertEq(address(auctionA).balance, 0);
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

            // assert SettlementFailure event is emitted with "Payment Failed" reason
            vm.expectEmit(true, true, false, true);
            emit SettlementFailure(signature3.bid.bidder, "Payment Failed");
            // feed signatures externally to this contract's Settlement inheritance
            this.finalizeAuction(signatures);

            // assert payments were completed
            assertEq(weth.balanceOf(bidder1), 1 ether - (bid1.amount * bid1.basePrice + bid1.tip));
            assertEq(weth.balanceOf(bidder2), 1 ether - (bid2.amount * bid2.basePrice + bid2.tip));
            assertEq(weth.balanceOf(address(this)), 0);
            assertEq(address(auctionA).balance, finalPayment);

            // assert NFTs were minted to bidder1, bidder3
            assertEq(auctionA.balanceOf(bidder1), bid1.amount);
            assertEq(auctionA.balanceOf(bidder2), bid2.amount);

            // assert NFT was not minted to bidder3
            assertEq(auctionA.balanceOf(bidder3), 0);
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

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Payment Failed");
        this.finalizeAuction(signature);
        // assert payment was not completed
        assertEq(address(auctionA).balance, 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
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

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Spent Sig");
        // attempt signature replay attack
        this.finalizeAuction(signatures);

        // assert payment completed only for signature2 and signature3
        assertEq(address(auctionA).balance, finalPayment);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
        // assert NFTs were minted to bidder2 and bidder3
        assertEq(auctionA.balanceOf(bidder2), bid2.amount);
        assertEq(auctionA.balanceOf(bidder3), bid3.amount);
        // assert signature still marked spent
        bool stillSpent = spentSigNonces[sigHash];
        assertTrue(stillSpent);
    }

    // prove that internal _settle call within unchecked block does not inherit unchecked property
    function test_settleUncheckedCannotOverflow() public {
        Bid memory overflowBid = Bid({
            auctionName: "TestNFT",
            auctionAddress: address(auctionA),
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

    // ensure mints that exceed maximum supply within batches are skipped and emit MintFailure
    function test_finalizeAuctionExceedsMaxSupply() public {
        // set up new example721A with lower max supply
        Example721A tenMax = new Example721A(
            'Only10', 
            'TEN', 
            address(this), 
            address(0x0), 
            10,
            10,
            5
        );

        BidSignatures.Bid memory five = Bid({
            auctionName: "Only10",
            auctionAddress: address(tenMax),
            bidder: bidder1,
            amount: 5,
            basePrice: 10,
            tip: 0
        });

        BidSignatures.Bid memory six = Bid({
            auctionName: "Only10",
            auctionAddress: address(tenMax),
            bidder: bidder2,
            amount: 6,
            basePrice: 10,
            tip: 0
        });

        vm.prank(bidder1);
        weth.approve(address(this), type(uint256).max);
        vm.prank(bidder2);
        weth.approve(address(this), type(uint256).max);

        bytes32 digestFive = hashTypedData(five);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digestFive);
        Signature memory fiveSig = Signature({
            bid: five,
            v: v,
            r: r,
            s: s
        });

        bytes32 digestSix = hashTypedData(six);
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(bidder2PrivateKey, digestSix);
        Signature memory sixSig = Signature({
            bid: six,
            v: v_,
            r: r_,
            s: s_
        });

        Signature[] memory excess = new Signature[](2);
        excess[0] = fiveSig;
        excess[1] = sixSig;

        this.finalizeAuction(excess);

        // assert only the first bid successfully minted as the second exceeded maxSupply
        assertEq(tenMax.totalSupply(), five.amount);
        assertEq(tenMax.balanceOf(bidder1), five.amount);
        assertEq(tenMax.balanceOf(bidder2), 0);
    }

    // ensure mints that exceed allocated supply within batches are skipped and emit MintFailure
    function test_finalizeAuctionExceedsAllocatedSupply() public {
        uint256 wethTotal1 = allocatedMinus10.amount * (allocatedMinus10.basePrice + allocatedMinus10.tip);
        vm.prank(bidder1);
        weth.approve(address(this), wethTotal1);
        uint256 wethTotal2 = overFlow.amount * (overFlow.basePrice + overFlow.tip);
        vm.prank(bidder2);
        weth.approve(address(this), wethTotal2);
        uint256 wethTotal3 = justRight.amount * (justRight.basePrice + justRight.tip);
        vm.prank(bidder3);
        weth.approve(address(this), wethTotal3);

        bytes32 digestAllocatedMinus10 = hashTypedData(allocatedMinus10);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digestAllocatedMinus10);
        Signature memory allocatedMinus10Sig = Signature({
            bid: allocatedMinus10,
            v: v,
            r: r,
            s: s
        });

        bytes32 digestOverFlow = hashTypedData(overFlow);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(bidder2PrivateKey, digestOverFlow);
        Signature memory overFlowSig = Signature({
            bid: overFlow,
            v: v1,
            r: r1,
            s: s1
        });

        bytes32 digestJustRight = hashTypedData(justRight);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder3PrivateKey, digestJustRight);
        Signature memory justRightSig = Signature({
            bid: justRight,
            v: v2,
            r: r2,
            s: s2
        });

        Signature[] memory allocationOverflow = new Signature[](3);
        allocationOverflow[0] = allocatedMinus10Sig;
        allocationOverflow[1] = overFlowSig;
        allocationOverflow[2] = justRightSig;

        this.finalizeAuction(allocationOverflow);

        // assert only the first bid successfully minted as the second exceeded maxSupply
        uint256 amountToMint = allocatedMinus10.amount + justRight.amount;
        assertEq(auctionA.totalSupply(), amountToMint);
        assertEq(auctionA.balanceOf(bidder1), allocatedMinus10.amount);
        assertEq(auctionA.balanceOf(bidder2), 0); // overflow failure
        assertEq(auctionA.balanceOf(bidder3), justRight.amount);
    }
}
