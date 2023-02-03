// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../src/proxy/SettlementUUPS.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";
import "../src/proxy/ProxyDeoxys.sol";

address payable constant mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

contract SettlementUUPSTest is Test, SettlementUUPS {

    SettlementUUPS public settlement;
    ProxyDeoxys public proxyDeoxys;
    WETH public proxysWETH;
    Example721A public pikaExample;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    string name;
    string symbol;
    uint256 public priceInGweth;
    uint256 public maxSupply;
    uint256 public typeMax;
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
    bytes public data;

    // ERC721A transfer
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    // initialize test environment
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        typeMax = type(uint256).max;
        data = abi.encodeWithSelector(this.init.selector, mainnetWETH, typeMax);
        settlement = new SettlementUUPS();
        proxyDeoxys = new ProxyDeoxys(address(settlement), data);
        proxysWETH = WETH(proxyDeoxys.weth());

        name = "PikaExample";
        symbol = "PIKA";
        priceInGweth = 69;
        maxSupply = type(uint256).max;
        // zero address used as placeholder for revenue recipient
        pikaExample = new Example721A(
            name, 
            symbol, 
            address(proxyDeoxys), 
            address(0x0), 
            priceInGweth,
            maxSupply
        );

        // prepare the cow carcass beefy baby private keys with which to sign
        bidder1PrivateKey = 0xDEADBEEF;
        bidder2PrivateKey = 0xBEEF;
        bidder3PrivateKey = 0xBABE;

        bidder1 = vm.addr(bidder1PrivateKey);
        // seed cow carcass bidder1 with 1 eth and wrap it to weth
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        proxysWETH.deposit{ value: 1 ether }();

        bidder2 = vm.addr(bidder2PrivateKey);
        // seed beef bidder with 1 eth and wrap it to weth
        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        proxysWETH.deposit{ value: 1 ether }();

 
        bidder3 = vm.addr(bidder3PrivateKey);
        // seed babe bidder with 1 eth and wrap it to weth
        vm.deal(bidder3, 1 ether);
        vm.prank(bidder3);
        proxysWETH.deposit{ value: 1 ether }();

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

    function test_setUp() public {
        assertEq(vm.activeFork(), mainnetFork);
        assertEq(address(proxyDeoxys.weth()), mainnetWETH);
        assertEq(proxyDeoxys.mintMax(), typeMax);
        assertEq(settlement.owner(), address(this));
        assertEq(proxysWETH.balanceOf(bidder1), 1 ether);
        assertEq(proxysWETH.balanceOf(bidder2), 1 ether);
        assertEq(proxysWETH.balanceOf(bidder3), 1 ether);
    }

function test_settle() public {
        // calculate totalWeth to pay
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approves totalWeth amount to weth contract
        vm.prank(bidder1);
        proxysWETH.approve(address(proxyDeoxys), totalWeth);
        assertEq(proxysWETH.allowance(bidder1, address(proxyDeoxys)), totalWeth);

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
            vm.prank(address(proxyDeoxys));
            try proxysWETH.transferFrom(bid1.bidder, address(proxyDeoxys), totalWETH) returns (bool) {
                vm.prank(address(proxyDeoxys));
                proxysWETH.withdraw(totalWETH);
                vm.prank(address(proxyDeoxys));
                Pikapatible(payable(bid1.auctionAddress)).mint{
                    value: totalWETH
                }(bid1.bidder, bid1.amount);
            } catch {
                emit SettlementFailure(
                    bid1.bidder,
                    "Payment Failed"
                );
            }
        }

        // assert weth payments were made
        assertEq(proxysWETH.balanceOf(address(proxyDeoxys)), 0);
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
        proxysWETH.approve(address(settlement), totalWeth);
        assertEq(proxysWETH.allowance(bidder1, address(settlement)), totalWeth);

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
        proxysWETH.approve(address(settlement), totalWeth2);
        assertEq(proxysWETH.allowance(bidder2, address(settlement)), totalWeth2);

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
        assertEq(pikaExample.balanceOf(bidder1), bid1.amount);
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(proxysWETH.balanceOf(address(settlement)), 0);
        
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

    function test_skipZeroAmountMints() public {
        // create bid with 0 as amount
        BidSignatures.Bid memory bid0 = Bid({
            auctionName: "TestNFT",
            auctionAddress: address(pikaExample),
            bidder: bidder1,
            amount: 0,
            basePrice: priceInGweth,
            tip: 69
        });

        // make approval
        vm.prank(bidder1);
        proxysWETH.approve(address(settlement), bid0.tip);
        assertEq(proxysWETH.allowance(bidder1, address(settlement)), bid0.tip);

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
        uint256 zero = pikaExample.totalSupply();
        assertEq(zero, 0);
        uint256 none = pikaExample.balanceOf(bid0.bidder);
        assertEq(none, 0);
        vm.expectRevert();
        pikaExample.ownerOf(0);
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
        assertEq(proxysWETH.balanceOf(address(settlement)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);

        // bid and finalize with nonzero but insufficient approval
        vm.prank(bidder2);
        proxysWETH.approve(address(settlement), 5);
        assertEq(proxysWETH.allowance(bidder2, address(settlement)), 5);

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
        assertEq(proxysWETH.balanceOf(address(settlement)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
    }

    function test_skipInsufficientApprovals() public {
        // bid and finalize multiple signatures with second bid missing approval
        uint256 totalWeth = bid1.amount * bid1.basePrice + bid1.tip;
        // bidder1 approval
        vm.prank(bidder1);
        proxysWETH.approve(address(proxyDeoxys), totalWeth);
        assertEq(proxysWETH.allowance(bidder1, address(proxyDeoxys)), totalWeth);

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
        proxysWETH.approve(address(proxyDeoxys), notEnough);
        assertEq(proxysWETH.allowance(bidder2, address(proxyDeoxys)), notEnough);

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
        proxysWETH.approve(address(proxyDeoxys), totalWeth3);
        assertEq(proxysWETH.allowance(bidder3, address(proxyDeoxys)), totalWeth3);

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
        assertEq(address(pikaExample).balance, finalPayment);
        assertEq(proxysWETH.balanceOf(address(settlement)), 0);

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
        proxysWETH.approve(address(proxyDeoxys), totalWeth);
        assertEq(proxysWETH.allowance(bidder1, address(proxyDeoxys)), totalWeth);

        // bidder1 spends all WETH, leaving none for the settlement
        proxysWETH.transfer(address(0x0), proxysWETH.balanceOf(bidder1));
        vm.stopPrank();
        assertEq(proxysWETH.balanceOf(bidder1), 0);
        
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
        assertEq(proxysWETH.balanceOf(address(proxyDeoxys)), 0);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
        // assert pikaExample did not receive any eth
        assertEq(address(pikaExample).balance, 0);
    }

        // test skipping insufficient balances within multiple signatures
        function test_skipInsufficientWETHBalances() public {
            // bidders make approvals
            vm.prank(bidder1);
            proxysWETH.approve(address(proxyDeoxys), 1 ether);
            assertEq(proxysWETH.allowance(bidder1, address(proxyDeoxys)), 1 ether);
            vm.prank(bidder2);
            proxysWETH.approve(address(proxyDeoxys), 1 ether);
            assertEq(proxysWETH.allowance(bidder2, address(proxyDeoxys)), 1 ether);
            vm.startPrank(bidder3);
            proxysWETH.approve(address(proxyDeoxys), 1 ether);
            assertEq(proxysWETH.allowance(bidder3, address(proxyDeoxys)), 1 ether);

            // bidder3 spends their WETH before auction settlement
            proxysWETH.transfer(address(0x0), 1 ether);
            vm.stopPrank();
            assertEq(proxysWETH.balanceOf(bidder3), 0);

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
            assertEq(proxysWETH.balanceOf(bidder1), 1 ether - (bid1.amount * bid1.basePrice + bid1.tip));
            assertEq(proxysWETH.balanceOf(bidder2), 1 ether - (bid2.amount * bid2.basePrice + bid2.tip));
            assertEq(proxysWETH.balanceOf(address(settlement)), 0);
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
        proxysWETH.approve(address(proxyDeoxys), 1 ether);
        assertEq(proxysWETH.allowance(bidder2, address(proxyDeoxys)), 1 ether);
        vm.prank(bidder3);
        proxysWETH.approve(address(proxyDeoxys), 1 ether);
        assertEq(proxysWETH.allowance(bidder3, address(proxyDeoxys)), 1 ether);

        (uint8 v, bytes32 r, bytes32 s) = _prepareAndSignDigest(bid1, bidder1PrivateKey);
        Signature memory signature1 = Signature({
            bid: bid1,
            v: v,
            r: r,
            s: s
        });

        // create signature array, first intentionally failing a signature submission via allowance to attempt replay attack
        Signature[] memory signatures = new Signature[](3);
        signatures[1] = signature1;

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Payment Failed");
        (bool f,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(f);

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
        proxysWETH.approve(address(settlement), 1 ether);
        assertEq(proxysWETH.allowance(bidder1, address(settlement)), 1 ether);

        // assert SettlementFailure event is emitted with "Payment Failed" reason
        vm.expectEmit(true, true, false, true);
        emit SettlementFailure(signature1.bid.bidder, "Spent Sig");
        // attempt signature replay attack
        (bool g,) = address(proxyDeoxys).call(abi.encodeWithSelector(this.finalizeAuction.selector, signatures));
        assertTrue(g);

        // assert payment completed only for signature2 and signature3
        assertEq(address(pikaExample).balance, finalPayment);
        // assert NFT was not minted to bidder1
        assertEq(pikaExample.balanceOf(bidder1), 0);
        // assert NFTs were minted to bidder2 and bidder3
        assertEq(pikaExample.balanceOf(bidder2), bid2.amount);
        assertEq(pikaExample.balanceOf(bidder3), bid3.amount);
        // assert signature still marked spent
        bool stillSpent = proxyDeoxys.spentSigNonces(sigHash);
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
        proxysWETH.approve(address(settlement), type(uint256).max);

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
            10
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
        proxysWETH.approve(address(proxyDeoxys), type(uint256).max);
        vm.prank(bidder2);
        proxysWETH.approve(address(proxyDeoxys), type(uint256).max);

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

    /// @dev Internal helper functions to alleviate the occurrance of the dreaded 'sTaCk tOo DeEp' error
    function _prepareAndSignDigest(Bid memory _bid, uint256 _privateKey) internal view returns (uint8 _v, bytes32 _r, bytes32 _s) {
            // prepare digest
            bytes32 digest = settlement.hashTypedData(_bid);
            (_v, _r, _s) = vm.sign(_privateKey, digest);
        }

    function _calculateTotal(Signature memory _sig) internal pure returns (uint256) {
        return _sig.bid.amount * _sig.bid.basePrice + _sig.bid.tip;
    }
}
