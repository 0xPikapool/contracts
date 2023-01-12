// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";

address payable constant goerliWETH = payable(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

contract UserGen is Script, Test {

    string GOERLI_RPC_URL = vm.envString("GOERLI_RPC_URL");

    uint256 public priceInGweth;
    mapping(address => uint256) internal privKeys;

    BidSignatures.Bid sampleBid;

    // initialize bids and users
    function run() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
    }
}