// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "ERC721A/IERC721A.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/Pikapatible.sol";

contract PikapatibleTest is Test {

    Settlement public settlement;
    Example721A public pikaExample;

    address payable mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    string name;
    string symbol;
    uint256 priceInGweth;
    uint256 maxSupply;
    uint256 allocatedSupply;
    bytes public err;

    // initialize test environment
    function setUp() public {
        name = "PikaExample";
        symbol = "PIKA";
        settlement = new Settlement(mainnetWETH, type(uint256).max);
        priceInGweth = 69;
        maxSupply = 10;
        allocatedSupply = 5;
        // zero address used as placeholder for revenue recipient
        pikaExample = new Example721A(
            name, 
            symbol, 
            address(settlement), 
            address(0x0), 
            priceInGweth,
            maxSupply,
            allocatedSupply
        );
        
        string memory name_ = pikaExample.name();
        assertEq(name_, "PikaExample");
        string memory symbol_ = pikaExample.symbol();
        assertEq(symbol_, "PIKA");
        address owner_ = pikaExample.owner();
        assertEq(owner_, address(settlement));
        uint256 price_ = pikaExample.price();
        assertEq(price_, 69);
    }

    // ensure mint functionality works as intended separate from Settlement.sol logic
    function test_mint() public {
        vm.deal(address(settlement), priceInGweth);
        vm.prank(address(settlement));
        pikaExample.mint{ value: priceInGweth }(address(settlement), 1);

        uint256 one = pikaExample.balanceOf(address(settlement));
        assertEq(one, 1);

        // ERC721A defaults to beginning with tokenId 0
        address mintOwner = pikaExample.ownerOf(0);
        assertEq(mintOwner, address(settlement));
    }

    // ensure mint fails when called from non-owner address
    function testRevert_mintWrongOwner() public {
        vm.deal(address(this), priceInGweth);
        err = bytes("UNAUTHORIZED");
        vm.expectRevert(err);
        pikaExample.mint{ value: priceInGweth }(address(this), 1);

        uint256 zero = pikaExample.balanceOf(address(this));
        assertEq(zero, 0);

        bytes4 e = IERC721A.OwnerQueryForNonexistentToken.selector;
        vm.expectRevert(e);
        pikaExample.ownerOf(1);
    }

    // ensure skipping mints when called with amount parameter == 0
    function test_mintWrongAmount() public {
        vm.deal(address(settlement), priceInGweth);

        vm.prank(address(settlement));
        pikaExample.mint{ value: priceInGweth }(address(this), 0);

        uint256 none = pikaExample.totalSupply();
        assertEq(none, 0);
        uint256 zero = pikaExample.balanceOf(address(this));
        assertEq(zero, 0);
        vm.expectRevert();
        pikaExample.ownerOf(0);
    }

    // ensure mint fails when insufficient funds are provided
    function testRevert_mintWrongPrice() public {
        vm.deal(address(settlement), priceInGweth - 1);

        vm.prank(address(settlement));
        pikaExample.mint{ value: address(settlement).balance }(address(this), 1);

        uint256 zero = pikaExample.balanceOf(address(settlement));
        assertEq(zero, 0);

        bytes4 e = IERC721A.OwnerQueryForNonexistentToken.selector;
        vm.expectRevert(e);
        pikaExample.ownerOf(1);
    }

    // ensure mint fails when provided amount exceeds maxSupply
    function test_mintExceedsMaxSupply() public {
        uint256 excess = maxSupply += 1;
        vm.deal(address(settlement), priceInGweth * excess);
        
        vm.prank(address(settlement));
        pikaExample.mint{ value: address(settlement).balance }(address(this), excess);

        uint256 zero = pikaExample.balanceOf(address(settlement));
        assertEq(zero, 0);

        uint zeroSupply = pikaExample.totalSupply();
        assertEq(zeroSupply, 0);

        bytes4 e = IERC721A.OwnerQueryForNonexistentToken.selector;
        vm.expectRevert(e);
        pikaExample.ownerOf(1);
        vm.expectRevert(e);
        pikaExample.ownerOf(excess);
    }

    // ensure mint fails when provided amount exceeds allocatedSupply
    function test_mintExceedsAllocatedSupply() public {
        uint256 allocationExcess = allocatedSupply += 1;
        vm.deal(address(settlement), priceInGweth * allocationExcess);

        vm.prank(address(settlement));
        pikaExample.mint{ value: address(settlement).balance }(address(this), allocationExcess);

        uint256 zero = pikaExample.balanceOf(address(settlement));
        assertEq(zero, 0);

        uint256 zeroMints = pikaExample.allocatedMints();
        assertEq(zeroMints, 0);

        bytes4 e = IERC721A.OwnerQueryForNonexistentToken.selector;
        vm.expectRevert(e);
        pikaExample.ownerOf(1);
        vm.expectRevert(e);
        pikaExample.ownerOf(allocationExcess);
    }
}
