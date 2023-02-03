// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../src/proxy/SettlementUUPS.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";
import "../src/proxy/ProxyDeoxys.sol";

address payable constant mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

contract ProxyDeoxysTest is Test, SettlementUUPS {

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
}
// function to test implementation contract is set properly
// function to test owner set properly
// function to test init can not be called again
// function to test upgrade logic
// function to prove storage layouts are equivalent