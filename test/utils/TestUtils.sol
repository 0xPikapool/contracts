// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;
pragma abicoder v2;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";
import "../../src/Settlement.sol";
import "../../src/Example721A.sol";
import "../../src/utils/BidSignatures.sol";

address payable constant mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

abstract contract TestUtils is Test, Settlement(mainnetWETH, 200) {

    Example721A public auctionA;
    Example721A public auctionB;
    Example721A public auctionC;

    uint256 public mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    string name;
    string symbol;
    uint256 public auctionPriceA;
    uint256 public auctionPriceB;
    uint256 public auctionPriceC;
    uint256 public maxSupplyA;
    uint256 public maxSupplyB;
    uint256 public maxSupplyC;
    uint256 public allocatedSupplyA;
    uint256 public allocatedSupplyB;
    uint256 public allocatedSupplyC;
    uint256 public bidder1PrivateKey;
    uint256 public bidder2PrivateKey;
    uint256 public bidder3PrivateKey;
    address public bidder1;
    address public bidder2;
    address public bidder3;
    address public settlementAddress;
    BidSignatures.Bid public bid1;
    BidSignatures.Bid public bid2;
    BidSignatures.Bid public bid3;
    BidSignatures.Bid public allocatedMinus10;
    BidSignatures.Bid public overFlow;
    BidSignatures.Bid public justRight;
    bytes public err;

    // ERC721A transfer
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    constructor() {
        // initialize test fork from mainnet
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        settlementAddress = address(this);
        
        // utilize various values including free mints as well as partial and entire Pikapool allocations
        auctionPriceA = 69;
        auctionPriceB = 10;
        auctionPriceC = 0;
        maxSupplyA = type(uint256).max;
        maxSupplyB = 100;
        maxSupplyC = 150;
        allocatedSupplyA = 100;
        allocatedSupplyB = 50;
        allocatedSupplyC = 150;

        // address(0x0) is used as a placeholder address for the _recipient that receives auction revenue
        auctionA = _generateAuction(
            "TestNFT", 
            "A", 
            settlementAddress, 
            address(0x0), 
            auctionPriceA,
            maxSupplyA,
            allocatedSupplyA
        );

        auctionB = _generateAuction(
            'TestNFTB', 
            'B', 
            settlementAddress, 
            address(0x0), 
            auctionPriceB,
            maxSupplyB,
            allocatedSupplyB
        );

        auctionC = _generateAuction(
            'TestNFTC', 
            'C', 
            settlementAddress, 
            address(0x0), 
            auctionPriceC,
            maxSupplyC,
            allocatedSupplyC
        );

        // prepare the cow carcass private key with which to sign
        bidder1PrivateKey = 0xDEADBEEF;
        bidder1 = vm.addr(bidder1PrivateKey);
        // seed cow carcass bidder1 with 1 eth and wrap it to weth
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        weth.deposit{ value: 1 ether }();

        // create new beefy bidder for second signature
        bidder2PrivateKey = 0xBEEF;
        bidder2 = vm.addr(bidder2PrivateKey);
        // seed cow bidder with 1 eth and wrap it to weth
        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        weth.deposit{ value: 1 ether }();

        // create new beefy bidder for third signature
        bidder3PrivateKey = 0xBABE;
        bidder3 = vm.addr(bidder3PrivateKey);
        // seed cow bidder with 1 eth and wrap it to weth
        vm.deal(bidder3, 1 ether);
        vm.prank(bidder3);
        weth.deposit{ value: 1 ether }();

        // prepare bids
        bid1 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder1,
            30,
            auctionPriceA,
            69
        );

        bid2 = _generateBid(
            "TestNFTB",
            address(auctionA),
            bidder2,
            42,
            auctionPriceA,
            42
        );

        bid3 = _generateBid(
            "TestNFTC",
            address(auctionA),
            bidder3,
            12,
            auctionPriceA,
            420
        );

        // bids for test_allocatedSupply
        allocatedMinus10 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder1,
            allocatedSupplyA - 10,
            auctionPriceA,
            0
        );

        overFlow = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder2,
            11, // set to result in overflow, allocatedMints += amount > allocatedSupply
            auctionPriceA,
            1
        );

        justRight = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder3,
            10,
            auctionPriceA,
            2
        );
    }

    /// Utility Functions

    /// @dev Public function provided to facilitate access to bid structs stored in this contract from tests across the repo
    function getBids() public view returns (Bid[6] memory) {
        return [bid1, bid2, bid3, allocatedMinus10, overFlow, justRight];
    }

    /// @dev Public function provided to facilitate testing of proxy contracts which possess shadowed storage variables and a different DOMAIN_SEPARATOR
    function regenerateAuctionsAndBids(address _newSettlementAddress) public {
        settlementAddress = _newSettlementAddress;

        // address(0x0) is used as a placeholder address for the _recipient that receives auction revenue
        auctionA = _generateAuction(
            "TestNFT", 
            "A", 
            settlementAddress, 
            address(0x0), 
            auctionPriceA,
            type(uint256).max,
            allocatedSupplyA
        );

        auctionB = _generateAuction(
            'TestNFTB', 
            'B', 
            settlementAddress, 
            address(0x0), 
            auctionPriceB,
            maxSupplyB,
            allocatedSupplyB
        );

        auctionC = _generateAuction(
            'TestNFTC', 
            'C', 
            settlementAddress, 
            address(0x0), 
            auctionPriceC,
            maxSupplyC,
            allocatedSupplyC
        );

        bid1 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder1,
            30,
            auctionPriceA,
            69
        );

        bid2 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder2,
            42,
            auctionPriceA,
            42
        );

        bid3 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder3,
            12,
            auctionPriceA,
            420
        );

        // bids for test_allocatedSupply
        allocatedMinus10 = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder1,
            allocatedSupplyA - 10,
            auctionPriceA,
            0
        );

        overFlow = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder2,
            11, // set to result in overflow, allocatedMints += amount > allocatedSupply
            auctionPriceA,
            1
        );

        justRight = _generateBid(
            "TestNFT",
            address(auctionA),
            bidder3,
            10,
            auctionPriceA,
            2
        );
    }

    /// @dev Internal helper functions to alleviate the occurrance of the dreaded 'sTaCk tOo DeEp' error
    function _generateAuction(
        string memory _name,
        string memory _symbol,
        address _settlementContract,
        address _recipient,
        uint256 _priceInWei,
        uint256 _maxSupply,
        uint256 _allocatedSupply
    ) internal returns (Example721A) {
        return (new Example721A(
            _name, 
            _symbol, 
            _settlementContract, 
            _recipient, 
            _priceInWei,
            _maxSupply,
            _allocatedSupply
        ));
    }

    function _generateBid(
        string memory _auctionName,
        address _auctionAddress,
        address _bidder,
        uint256 _amount,
        uint256 _basePrice,
        uint256 _tip
    ) internal pure returns (BidSignatures.Bid memory) {
        return (BidSignatures.Bid({
            auctionName: _auctionName,
            auctionAddress: _auctionAddress,
            bidder: _bidder,
            amount: _amount,
            basePrice: _basePrice,
            tip: _tip
        }));
    }

    function _generateSig(
        BidSignatures.Bid memory _bid,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public pure returns (Signature memory) {
        return (Signature({
            bid: _bid,
            v: _v,
            r: _r,
            s: _s
        }));
    }

    function _prepareAndSignDigest(Bid memory _bid, uint256 _privateKey) public view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        // prepare digest
        bytes32 digest = hashTypedData(_bid);
        (_v, _r, _s) = vm.sign(_privateKey, digest);
    }

    function _calculateTotal(Signature memory _sig) public pure returns (uint256) {
        return _sig.bid.amount * _sig.bid.basePrice + _sig.bid.tip;
    }
}