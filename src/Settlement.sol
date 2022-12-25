// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "./utils/BidSignatures.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

contract Settlement is BidSignatures {

    /// @dev Auction registry enumerated by index; could be deprecated in favor of token addresses if offchain recordkeeping is sufficient
    mapping(uint => address) public auctionIds;
    
    /// @dev Function to settle each winning bid via EIP-712 signature
    function settleFromSignature(
        address auctionAddress,
        address bidder,
        uint256 amount,
        uint32 blockDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external /* internal ? */ {
        if (block.number > blockDeadline) revert AuctionDeadlineConcluded();

        address recovered = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    // gas optimization of BidSignatures.hashBid(): calldata < mstore/mload !
                    keccak256(
                        abi.encode(
                            BID_TYPE_HASH,
                            auctionAddress,
                            bidder,
                            amount,
                            blockDeadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        // handle signature error cases
        if (recovered == address(0) || recovered != bidder) revert InvalidSignature();

        _settle(auctionAddress, bidder, amount, blockDeadline);
    }
    
    /// @dev Internal function that finalizes the settlements upon verification of signatures
    function _settle(address auctionAddress, address bidder, uint256 amount, uint32 blockDeadline) internal {
        
        //todo ie. auctionAddress.mint()

        // placeholder for tests while I make sure signatures are working as intended
        auctionIds[amount] = auctionAddress;
    }

    /// @dev Function to be called by the Orchestrator following the conclusion of each auction
    // todo
    // function finalizeAuction(Bid[] memory bids) { for (uint256 i; i < bids.length; i++) settleFromSignature() }
}
