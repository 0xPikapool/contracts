// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Example721A.sol";

contract BidSignaturesTest is Test {

    Example721A public pikaExample;

    uint256 public priceInGweth;
    bytes public err;

    // initialize test environment
    function setUp() public {
        priceInGweth = 69;

        pikaExample = new Example721A(priceInGweth);
    }

// test correct mint
// test wrong price paid
}