// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "solmate/tokens/WETH.sol";
import "./utils/BidSignatures.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

/// @dev Error thrown at a preset threshold to prevent excessive first-time token transfer costs
error ExcessAmount();
/// @dev Error thrown if WETH transferFrom() call fails, implying the bidder's payment failed
error PaymentFailure();
/// @dev Error thrown if a mint fails
error MintFailure();

contract Settlement is BidSignatures {

    /// @dev Struct of signature data for winning bids to be deconstructed and validated to mint NFTs
    /// @param bid The winning bid fed to this Settlement contract by the Orchestrator
    /// @param v ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    /// @param r ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    /// @param s ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    struct Signature {
        Bid bid;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    WETH public weth;

    /// @dev Maximum mint threshold amount to prevent excessive first-time token transfer costs
    /// @dev Stored in storage for gas optimization (as opposed to repeated mstores)
    uint256 public mintMax;

    /// @dev Auction registry enumerated by index; could be deprecated in favor of token addresses if offchain recordkeeping is sufficient
    mapping(uint => address) public auctionIds;

    constructor(address _wethAddress, uint256 _mintMax) {
        weth = WETH(payable(_wethAddress));
        mintMax = _mintMax;
    }
    
    /// @dev Function to settle each winning bid via EIP-712 signature
    /// @param auctionName The name of the creator's NFT collection being auctioned
    /// @param auctionAddress The address of the creator NFT being bid on. Becomes a string off-chain.
    /// @param bidder The address of the bid's originator, similar to tx.origin.
    /// @param amount The number of assets being bid on.
    /// @param basePrice The base price per NFT set by the collection's creator
    /// @param tip The tip per NFT offered by the bidder in order to win a mint in the auction
    /// @param totalWeth The total amount of WETH covered by this individual bid. Ie amount * (basePrice + tip)
    function settleFromSignature(
        string memory auctionName,
        address auctionAddress,
        address bidder,
        uint256 amount,
        uint256 basePrice,
        uint256 tip,
        uint256 totalWeth,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {

        if (amount > mintMax) revert ExcessAmount();

        address recovered = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    // gas optimization of BidSignatures.hashBid(): calldata < mstore/mload !
                    keccak256(
                        abi.encode(
                            BID_TYPE_HASH,
                            auctionName,
                            auctionAddress,
                            bidder,
                            amount,
                            basePrice,
                            tip,
                            totalWeth
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

        _settle(auctionAddress, bidder, amount, totalWeth);
    }
    
    /// @dev Internal function that finalizes the settlements upon verification of signatures
    function _settle(address auctionAddress, address bidder, uint256 amount, uint256 totalWeth) internal {
        bool p = weth.transferFrom(bidder, address(this), totalWeth);
        if (!p) revert PaymentFailure();

        // if (p) {} // do the below if weth transfer succeeds, without reverting on failures
        (bool r,) = auctionAddress.call(abi.encodeWithSignature("mint(address,uint256)", bidder, amount));
        if (!r) revert MintFailure();
    }

    /// @dev Function to be called by the Orchestrator following the conclusion of each auction
    // mark settleFromSignature as internal once this function is implemented
    function finalizeAuction(Signature[] memory signatures) external /* onlyOwner */{ 
        for (uint256 i; i < signatures.length; i++) {
            settleFromSignature(
                signatures[i].bid.auctionName,
                signatures[i].bid.auctionAddress,
                signatures[i].bid.bidder,
                signatures[i].bid.amount,
                signatures[i].bid.basePrice,
                signatures[i].bid.tip,
                signatures[i].bid.totalWeth,
                signatures[i].v,
                signatures[i].r,
                signatures[i].s
            );
        }
    }
}
