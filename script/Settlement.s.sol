// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";

contract SettlementScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("pk");
        vm.startBroadcast(deployerPrivateKey);

        // address payable mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address payable goerliWETH = payable(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

        uint256 maximum = type(uint256).max;
        uint256 price = 69;
    
        // using goerli weth address
        Settlement settlement = new Settlement(goerliWETH, maximum);
        Example721A pikaExample = new Example721A("PikaExample", "PIKA", address(settlement), price);

        // // using mainnet weth address
        // Settlement settlement = new Settlement(mainnetWETH, maximum);
        // Example721A pikaExample = new Example721A("PikaExample", "PIKA", address(settlement), price);

        vm.stopBroadcast();
    }
}
