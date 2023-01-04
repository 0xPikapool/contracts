// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/BidSignatures.sol";

contract SettlementTest is Test {

    // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
    Settlement public settlement;
    Example721A public pikaExample;
    WETH public weth;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    uint256 public priceInGweth;
    uint256 internal bidderPrivateKey;
    address internal bidder;
    bytes public err;

    // initialize test environment
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        priceInGweth = 69;

        settlement = new Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30);
        pikaExample = new Example721A(priceInGweth);
        weth = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

        // prepare the cow carcass private key with which to sign
        bidderPrivateKey = 0xDEADBEEF;
        bidder = vm.addr(bidderPrivateKey);
        // seed cow carcass bidder with 1 eth and wrap it to weth
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        weth.deposit{ value: 1 ether }();
        assertEq(weth.balanceOf(bidder), 1 ether);
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
    }
}

//function to test single mint
//function to test full 30 mint
//function to test revert on 0 mint
//function to test revert on 31 mints