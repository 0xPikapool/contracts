// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;
pragma abicoder v2;

import "../src/proxy/SettlementUUPS.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";
import "../src/proxy/ProxyDeoxys.sol";
import "./utils/TestUtils.sol";
import "./Settlement.t.sol";

contract SettlementUUPSTest is Test, SettlementUUPS {

    SettlementTest public testUtils;
    Example721A public auctionA;
    Example721A public auctionB;
    Example721A public auctionC;

    SettlementUUPS public settlement;
    ProxyDeoxys public proxyDeoxys;

    uint256 public typeMax;
    uint256 internal bidder1PrivateKey;
    uint256 internal bidder2PrivateKey;
    uint256 internal bidder3PrivateKey;
    address public bidder1;
    address public bidder2;
    address public bidder3;
    BidSignatures.Bid bid1;
    BidSignatures.Bid bid2;
    BidSignatures.Bid bid3;
    bytes public data;

    // ERC721A transfer
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    // initialize test environment
    function setUp() public {        
        testUtils = new SettlementTest();
        data = abi.encodeWithSelector(this.init.selector, mainnetWETH, 200);
        settlement = new SettlementUUPS();
        proxyDeoxys = new ProxyDeoxys(address(settlement), data);
        weth = proxyDeoxys.weth();

        // reset TestUtils settlementAddress and regenerate auctions + bids for proxy-aligned access
        testUtils.regenerateAuctionsAndBids(address(proxyDeoxys));

        bidder1PrivateKey = testUtils.bidder1PrivateKey();
        bidder2PrivateKey = testUtils.bidder2PrivateKey();
        bidder3PrivateKey = testUtils.bidder3PrivateKey();
        bidder1 = testUtils.bidder1();
        bidder2 = testUtils.bidder2();
        bidder3 = testUtils.bidder3();
        bid1 = testUtils.getBids()[0];
        bid2 = testUtils.getBids()[1];
        bid3 = testUtils.getBids()[2];
        auctionA = testUtils.auctionA();
        auctionB = testUtils.auctionB();
        auctionC = testUtils.auctionC();
    }

    function test_setUp() public {
        assertEq(vm.activeFork(), testUtils.mainnetFork());
        assertEq(address(proxyDeoxys.weth()), mainnetWETH);
        assertEq(proxyDeoxys.mintMax(), 200);
        assertEq(settlement.owner(), address(this));
        assertEq(weth.balanceOf(bidder1), 1 ether);
        assertEq(weth.balanceOf(bidder2), 1 ether);
        assertEq(weth.balanceOf(bidder3), 1 ether);
    }

function test_settle() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(proxyDeoxys), totalWeth);
        assertEq(weth.allowance(bidder1, address(proxyDeoxys)), totalWeth);

        bytes32 digest = settlement.hashTypedData(bid1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);

        bool settle;
        address recovered = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    settlement.DOMAIN_SEPARATOR(),
                    // gas optimization of BidSignatures.hashBid(): calldata < mstore/mload !
                    keccak256(
                        abi.encode(
                            BID_TYPE_HASH,
                            keccak256(bytes(bid1.auctionName)),
                            bid1.auctionAddress,
                            bid1.bidder,
                            bid1.amount,
                            bid1.basePrice,
                            bid1.tip
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        // handle signature error cases
        recovered == address(0) || recovered != bid1.bidder ? settle = false : settle = true;

        // assert mint events are emitted as Solmate Transfers
        for (uint256 i; i < bid1.amount; ++i) {
            vm.expectEmit(true, true, false, true);
            emit Transfer(address(0x0), bid1.bidder, i);
        }

        if (settle) {
            uint256 totalWETH = bid1.amount * bid1.basePrice + bid1.tip;
            vm.startPrank(address(proxyDeoxys));
            try weth.transferFrom(bid1.bidder, address(proxyDeoxys), totalWETH) returns (bool) {
                weth.withdraw(totalWETH);
                Pikapatible(payable(bid1.auctionAddress)).mint{
                    value: totalWETH
                }(bid1.bidder, bid1.amount);
            } catch {
                emit SettlementFailure(
                    bid1.bidder,
                    "Payment Failed"
                );
            }
            vm.stopPrank();
        }

        // assert weth payments were made
        assertEq(weth.balanceOf(address(proxyDeoxys)), 0);
        assertEq(address(auctionA).balance, totalWeth);

        // assert NFT balances are correct
        uint minted = auctionA.balanceOf(bid1.bidder);
        assertEq(minted, bid1.amount);

        // assert owner of minted NFTs is correct
        for (uint i; i < bid1.amount; ++i) {
            address recipient = auctionA.ownerOf(i);
            assertEq(recipient, bid1.bidder);
        }
    }

    function test_finalizeAuction() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        weth.approve(address(proxyDeoxys), totalWeth);
        assertEq(weth.allowance(bidder1, address(proxyDeoxys)), totalWeth);

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
        weth.approve(address(proxyDeoxys), totalWeth2);
        assertEq(weth.allowance(bidder2, address(proxyDeoxys)), totalWeth2);

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
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(f);

        // assert payments were processed correctly
        assertEq(auctionA.balanceOf(bidder1), bid1.amount);
        assertEq(auctionA.balanceOf(bidder2), bid2.amount);
        assertEq(weth.balanceOf(address(settlement)), 0);
        
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
            basePrice: testUtils.auctionPriceA(),
            tip: 69
        });

        // make approval
        vm.prank(bidder1);
        weth.approve(address(settlement), bid0.tip);
        assertEq(weth.allowance(bidder1, address(settlement)), bid0.tip);

        bytes32 digest = settlement.hashTypedData(bid0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
        Signature memory signature0 = Signature({
            bid: bid0,
            v: v,
            r: r,
            s: s
        });

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature0;

        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(f);

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
        bytes32 digest = settlement.hashTypedData(bid1);
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
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signature));
        assertTrue(f);
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(settlement)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);

        // bid and finalize with nonzero but insufficient approval
        vm.prank(bidder2);
        weth.approve(address(settlement), 5);
        assertEq(weth.allowance(bidder2, address(settlement)), 5);

        digest = settlement.hashTypedData(bid2);
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
        (bool g,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signature));
        assertTrue(g);
        
        // assert WETH transfer was not completed
        assertEq(weth.balanceOf(address(settlement)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
    }

    function test_skipInsufficientApprovals() public {
        // bid and finalize multiple signatures with second bid missing approval
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approval
        vm.prank(bidder1);
        weth.approve(address(proxyDeoxys), totalWeth);
        assertEq(weth.allowance(bidder1, address(proxyDeoxys)), totalWeth);

        bytes32 digest = settlement.hashTypedData(bid1);
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
        weth.approve(address(proxyDeoxys), notEnough);
        assertEq(weth.allowance(bidder2, address(proxyDeoxys)), notEnough);

        bytes32 digest2 = settlement.hashTypedData(bid2);
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
        weth.approve(address(proxyDeoxys), totalWeth3);
        assertEq(weth.allowance(bidder3, address(proxyDeoxys)), totalWeth3);

        // compute final total of payment that should succeed upon settlement
        uint256 finalPayment = totalWeth + totalWeth3;

        bytes32 digest3 = settlement.hashTypedData(bid3);
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
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(f);

        // assert WETH transfers were completed by bidder1, bidder3
        assertEq(address(auctionA).balance, finalPayment);
        assertEq(weth.balanceOf(address(settlement)), 0);

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
        weth.approve(address(proxyDeoxys), totalWeth);
        assertEq(weth.allowance(bidder1, address(proxyDeoxys)), totalWeth);

        // bidder1 spends all WETH, leaving none for the settlement
        weth.transfer(address(0x0), weth.balanceOf(bidder1));
        vm.stopPrank();
        assertEq(weth.balanceOf(bidder1), 0);
        
        bytes32 digest = settlement.hashTypedData(bid1);
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
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signature));
        assertTrue(f);
        
        // assert WETH transfer was not completed due to insufficient balamnce
        assertEq(weth.balanceOf(address(proxyDeoxys)), 0);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
        // assert auctionA did not receive any eth
        assertEq(address(auctionA).balance, 0);
    }

        // test skipping insufficient balances within multiple signatures
        function test_skipInsufficientWETHBalances() public {
            // bidders make approvals
            vm.prank(bidder1);
            weth.approve(address(proxyDeoxys), 1 ether);
            assertEq(weth.allowance(bidder1, address(proxyDeoxys)), 1 ether);
            vm.prank(bidder2);
            weth.approve(address(proxyDeoxys), 1 ether);
            assertEq(weth.allowance(bidder2, address(proxyDeoxys)), 1 ether);
            vm.startPrank(bidder3);
            weth.approve(address(proxyDeoxys), 1 ether);
            assertEq(weth.allowance(bidder3, address(proxyDeoxys)), 1 ether);

            // bidder3 spends their WETH before auction settlement
            weth.transfer(address(0x0), 1 ether);
            vm.stopPrank();
            assertEq(weth.balanceOf(bidder3), 0);

            // prepare digests
            bytes32 digest = settlement.hashTypedData(bid1);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digest);
            Signature memory signature1 = Signature({
                bid: bid1,
                v: v,
                r: r,
                s: s
            });
            bytes32 digest2 = settlement.hashTypedData(bid2);
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bidder2PrivateKey, digest2);
            Signature memory signature2 = Signature({
                bid: bid2,
                v: v2,
                r: r2,
                s: s2
            });
            bytes32 digest3 = settlement.hashTypedData(bid3);
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
            (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
            assertTrue(f);

            // assert payments were completed
            assertEq(weth.balanceOf(bidder1), 1 ether - (bid1.amount * bid1.basePrice + bid1.tip));
            assertEq(weth.balanceOf(bidder2), 1 ether - (bid2.amount * bid2.basePrice + bid2.tip));
            assertEq(weth.balanceOf(address(settlement)), 0);
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
        weth.approve(address(proxyDeoxys), 1 ether);
        assertEq(weth.allowance(bidder2, address(proxyDeoxys)), 1 ether);
        vm.prank(bidder3);
        weth.approve(address(proxyDeoxys), 1 ether);
        assertEq(weth.allowance(bidder3, address(proxyDeoxys)), 1 ether);

        (uint8 v, bytes32 r, bytes32 s) = _prepareAndSignDigest(bid1, bidder1PrivateKey);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });

        // create signature array with empty members, first intentionally failing a signature submission via allowance to attempt replay attack
        Signature[] memory signatures = new Signature[](3);
        signatures[1] = signature1;

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Payment Failed");
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(f);

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
        bool spentSig = proxyDeoxys.spentSigNonces(sigHash);
        assertTrue(spentSig);

        (uint8 v2, bytes32 r2, bytes32 s2) = _prepareAndSignDigest(bid2, bidder2PrivateKey);
        Signature memory signature2 = Signature({
            bid: bid2,
            v: v2,
            r: r2,
            s: s2
        });
        (uint8 v3, bytes32 r3, bytes32 s3) = _prepareAndSignDigest(bid3, bidder3PrivateKey);
        Signature memory signature3 = Signature({
            bid: bid3,
            v: v3,
            r: r3,
            s: s3
        });

        signatures[0] = signature3;
        signatures[2] = signature2;

        // calculate expected payment amount
        uint256 finalPayment = _calculateTotal(signature2) + _calculateTotal(signature3);

        // bidder1 belatedly makes approval
        vm.prank(bidder1);
        weth.approve(address(settlement), 1 ether);
        assertEq(weth.allowance(bidder1, address(settlement)), 1 ether);

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Spent Sig");
        // attempt signature replay attack
        (bool g,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(g);

        // assert payment completed only for signature2 and signature3
        assertEq(address(auctionA).balance, finalPayment);
        // assert NFT was not minted to bidder1
        assertEq(auctionA.balanceOf(bidder1), 0);
        // assert NFTs were minted to bidder2 and bidder3
        assertEq(auctionA.balanceOf(bidder2), bid2.amount);
        assertEq(auctionA.balanceOf(bidder3), bid3.amount);
        // assert signature still marked spent
        bool stillSpent = proxyDeoxys.spentSigNonces(sigHash);
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
        weth.approve(address(settlement), type(uint256).max);

        bytes32 digest = settlement.hashTypedData(overflowBid);
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
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, cannotOverflow));
        assertTrue(f);
    }

    // ensure mints that exceed maximum are skipped and emit MintFailure
    function test_finalizeAuctionExceedsMaxSupply() public {
        // set up new example721A with lower max supply
        Example721A tenMax = new Example721A(
            'Only10', 
            'TEN', 
            address(proxyDeoxys), 
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
        weth.approve(address(proxyDeoxys), type(uint256).max);
        vm.prank(bidder2);
        weth.approve(address(proxyDeoxys), type(uint256).max);

        bytes32 digestFive = settlement.hashTypedData(five);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidder1PrivateKey, digestFive);
        Signature memory fiveSig = Signature({
            bid: five,
            v: v,
            r: r,
            s: s
        });

        bytes32 digestSix = settlement.hashTypedData(six);
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

        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, excess));
        assertTrue(f);

        // assert only the first bid successfully minted as the second exceeded maxSupply
        assertEq(tenMax.totalSupply(), five.amount);
        assertEq(tenMax.balanceOf(bidder1), five.amount);
        assertEq(tenMax.balanceOf(bidder2), 0);
    }

    /// @dev Internal helper function to calculate total weth cost
    /// @dev Included here as Solidity disallows structs from being natively passed between contracts (ie TestUtils.sol)
    function _calculateTotal(Signature memory _sig) internal pure returns (uint256) {
        return _sig.bid.amount * _sig.bid.basePrice + _sig.bid.tip;
    }

    /// @dev Internal helper function to generate EIP-712 compliant signatures
    /// @dev Included here as the DOMAIN_SEPARATOR of the TestUtils contract is distinct from this contract's due to inheritance of SettlementUUPS
    function _prepareAndSignDigest(Bid memory _bid, uint256 _privateKey) public view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        // prepare digest
        bytes32 digest = settlement.hashTypedData(_bid);
        (_v, _r, _s) = vm.sign(_privateKey, digest);
    }
}
