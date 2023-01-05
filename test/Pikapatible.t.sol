// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";
import "../src/utils/Pikapatible.sol";

contract PikapatibleTest is Test {

    Settlement public settlement;
    Example721A public pikaExample;

    string name;
    string symbol;
    uint256 priceInGweth;
    bytes public err;

    // initialize test environment
    function setUp() public {
        name = "PikaExample";
        symbol = "PIKA";
        settlement = new Settlement(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 30);
        priceInGweth = 69;
        pikaExample = new Example721A(name, symbol, address(settlement), priceInGweth);
    }

// test correct mint
// test wrong price paid
}