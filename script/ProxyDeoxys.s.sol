// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/proxy/ProxyDeoxys.sol";
import "../src/Settlement.sol";
import "../src/Example721A.sol";

/// @title PikaPool Protocol Upgradeable Proxy Deployment Script
/// @author 0xViola and PikaPool Developers

/// @dev This deployment script is provided on the assumption that the Settlement contract is being used as an UUPS logic implementation behind a proxy
/// For immutable, non-upgradeable deployments, use ./Settlement.s.sol instead
contract ProxyDeoxysScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("pk");
        vm.startBroadcast(deployerPrivateKey);

        // choose network here before deploying
        // address payable mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address payable goerliWETH = payable(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

        // set maximum and price here before deploying
        uint256 maximumSettleAmt = type(uint256).max;
        uint256 maximumNftSupply = type(uint256).max;
        uint256 price = 69;
    
        // using goerli weth address, PikaPool dev placeholder address as recipient
        bytes memory initData = abi.encodeWithSelector(Settlement.init.selector, goerliWETH, maximumSettleAmt);
        Settlement settlement = new Settlement();
        ProxyDeoxys proxyDeoxys = new ProxyDeoxys(address(settlement), initData);
        Example721A pikaExample = new Example721A(
            "PikaExample", 
            "PIKA", 
            address(settlement), 
            address(0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180), 
            price,
            maximumNftSupply
        );

        // // using mainnet weth address
        // Settlement settlement = new Settlement(mainnetWETH, maximum);
        // Example721A pikaExample = new Example721A("PikaExample", 
        //     "PIKA", 
        //     address(settlement), 
        //     address(0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180), 
        //     price,
        //     maximum
        // );

        vm.stopBroadcast();
    }
}