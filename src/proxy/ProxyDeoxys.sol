// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "solmate/tokens/WETH.sol";

contract ProxyDeoxys is ERC1967Proxy {

    address private owner;
    uint8 private _initialized;
    bool private _initializing;

    /// @dev WETH contract for this chain
    WETH public weth;

    /// @dev Maximum mint threshold amount to prevent excessive first-time token transfer costs
    /// @dev Stored in storage for gas optimization (as opposed to repeated mstores)
    uint256 public mintMax;

    /// @dev Mapping that stores keccak256 hashes of spent signatures to protect against replay attacks
    mapping (bytes32 => bool) public spentSigNonces;

    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) payable {}

    receive() external payable override {}
}