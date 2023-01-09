// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";

contract SettlementScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("pk");
        vm.startBroadcast(deployerPrivateKey);

        uint price = 69;
        // using goerli weth address
        Settlement settlement = new Settlement(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6, 30);
        Example721A pikaExample = new Example721A("PikaExample", "PIKA", address(settlement), price);

        vm.stopBroadcast();
    }
}
