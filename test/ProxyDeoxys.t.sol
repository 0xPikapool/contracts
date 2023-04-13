// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "../src/proxy/SettlementUUPS.sol";
import "../src/proxy/ProxyDeoxys.sol";
import "./utils/TestUtils.sol";

contract ProxyDeoxysTest is TestUtils {

    SettlementUUPS public settlement;
    ProxyDeoxys public proxyDeoxys;

    uint256 public _mintMax;
    bytes public data;

    // initialize test environment
    function setUp() public {
        _mintMax = 30;
        data = abi.encodeWithSelector(settlement.init.selector, mainnetWETH, _mintMax);
        settlement = new SettlementUUPS();
        proxyDeoxys = new ProxyDeoxys(address(settlement), data);
    }

    function test_setUp() public {
        assertEq(vm.activeFork(), mainnetFork);

        assertEq(address(proxyDeoxys.weth()), mainnetWETH);
        assertEq(proxyDeoxys.mintMax(), _mintMax);
        // check owner on impl
        assertEq(settlement.owner(), address(this));
        // check owner on 1967
        bytes memory _owner = abi.encodeWithSelector(settlement.owner.selector);
        (bool r, bytes memory owner) = address(proxyDeoxys).call(_owner);
        assertTrue(r);
        assertEq(address(uint160(uint256(bytes32(owner)))), tx.origin);

        assertEq(weth.balanceOf(bidder1), 1 ether);
        assertEq(weth.balanceOf(bidder2), 1 ether);
        assertEq(weth.balanceOf(bidder3), 1 ether);
    }

    function test_Upgrade() public {
        SettlementUUPS newSettlement = new SettlementUUPS();
        // prank the address used by Foundry to deploy, thereby assuming owner role
        vm.prank(address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38));
        bytes memory upgrade = abi.encodeWithSelector(settlement.upgradeTo.selector, address(newSettlement));
        (bool r,) = address(proxyDeoxys).call(upgrade);
        assertTrue(r);

        vm.prank(address(proxyDeoxys));
        address newImpl = proxyDeoxys.getImpl();
        assertEq(newImpl, address(newSettlement));
    }
}
