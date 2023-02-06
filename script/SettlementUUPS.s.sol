// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/proxy/SettlementUUPS.sol";

/// @title PikaPool Protocol Upgradeable Settlement Contract Deployment Script
/// @author 0xViola and PikaPool Developers

/// @dev This deployment script is provided on the assumption that the Settlement contract is being used as an UUPS logic implementation behind an existing proxy
/// Be absolutely sure that the proxy contract is _ALREADY INITIALIZED_ otherwise use ProxyDeoxys.s.sol to properly perform the init call
/// For immutable, non-upgradeable deployments, use ./Settlement.s.sol instead
contract SettlementUUPSScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        // choose network here before deploying
        // address payable mainnetWETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address payable goerliWETH = payable(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

        // set maximum and price here before deploying
        uint256 maximumSettleAmt = type(uint256).max;
        
        SettlementUUPS settlement = new SettlementUUPS();

        vm.stopBroadcast();
    }
}
