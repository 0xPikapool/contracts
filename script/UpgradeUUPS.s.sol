// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/proxy/ProxyDeoxys.sol";
import "../src/proxy/SettlementUUPS.sol";
import "../src/Example721A.sol";

/// @title PikaPool Protocol Upgradeable Proxy Deployment Script
/// @author 0xViola and PikaPool Developers

/// @dev This deployment script is provided on the assumption that the Settlement contract is being used as an UUPS logic implementation behind a proxy
/// For immutable, non-upgradeable deployments, use ./Settlement.s.sol instead
contract ProxyDeoxysScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);
    }
}
