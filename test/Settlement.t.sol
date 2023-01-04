// // SPDX-License-Identifier: None
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../src/Settlement.sol";
// import "../src/Example721A.sol";
// import "../src/utils/BidSignatures.sol";

// contract SettlementTest is Test {

//     // as BidSignatures utility contract is abstract, it suffices to instantiate the Settlement that inherits it
//     Settlement public settlement;
//     Example721A public pikaExample;

//     uint256 public price;
//     uint256 internal bidderPrivateKey;
//     address internal bidder;
//     bytes public err;

//     // initialize test environment
//     function setUp() public {
//         price = 69;

//         settlement = new Settlement();
//         pikaExample = new Example721A(price);

//         // prepare the cow carcass private key with which to sign
//         bidderPrivateKey = 0xDEADBEEF;
//         bidder = vm.addr(bidderPrivateKey);
//     }
// }

//function to test single mint
//function to test full 30 mint
//function to test revert on 0 mint
//function to test revert on 31 mints