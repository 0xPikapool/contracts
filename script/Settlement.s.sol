// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";

/// @title PikaPool Protocol Settlement Contract Deployment Script
/// @author 0xViola and PikaPool Developers

/// @dev This deployment script is provided on the assumption that the Settlement contract is being used as a standalone instance and not a proxy
/// For proxy and logic implementation deployments, use ./ProxyDeoxys.s.sol instead
contract SettlementScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        // address payable mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address payable goerliWETH = payable(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

        // set maximum and price here before deploying!
        uint256 maximumSupply = type(uint256).max;
        uint256 allocatedSupply = maximumSupply / 2;
        uint256 price = 69;
    
        // using goerli weth address, PikaPool dev placeholder address as recipient
        Settlement settlement = new Settlement(goerliWETH, maximumSupply);
        Example721A pikaExample = new Example721A(
            "PikaExample", 
            "PIKA", 
            address(settlement), 
            address(0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180), 
            price,
            maximumSupply,
            allocatedSupply
        );

        // // using mainnet weth address
        // Settlement settlement = new Settlement(mainnetWETH, maximumSupply);
        // Example721A pikaExample = new Example721A("PikaExample", 
        //     "PIKA", 
        //     address(settlement), 
        //     address(0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180), 
        //     price,
        //     maximumSupply
        // );

        vm.stopBroadcast();
    }
}
