// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

/*
................................................................................................................................... 
................................................................................................................................... 
...................................................................................................................................
..................................................................................... .............................................
..................................................................................      ........................................... 
................................................................................  :2BB: ........................................... 
..............................................................................  SQBBBBi ...........................................
............................................................................  XBPBBBB1ii7 .........................................
..................................         ................................ :BQOBiQBBrr27 .........................................
................................. QBBDq2Ui.   ...........................  XBlg . gBX:vs ..........................................
................................. .BBBBq1MQMXi   .......................  QB  ..  dB:rLL ..........................................
..................................  QBB7BBL7PQBP:  ....................  BQ  ... vB7i71 ...........................................
...................................  PBEBE.   :PBBj  .....         ...  BE ...  vBj:7ui ...........................................
....................................  sBP  ....  YBB5    .rj5SK5IJr.   Bd .... sBu:7jr ............................................
...................................... .gBI  ....  7BBLKMQEP2IU5XPZRMbQR .... 5BJ:7jr .............................................
.......................................  :RBq   ...  SBI.           .7bi  .. ZB7i7jr .....     ....................................
.........................................  :PBgj.        ............  ..s:7Bgir7ji ..   .uERB  ...................................
...........................................   2MBguS: ...................:QBu:7LJ:    :5RQEY:BL ...................................
..............................................  .jBB ................. .. iBrrv7   :SQQbi    BKvr .................................
................................................  B.  .................    Md::  UQQP:   ..  PBiu .................................
................................................ :B  ;PSB;......... ;PSB;  PM:UZQZr   ...... jQ7L .................................
................................................ .B  iE gj......... Bq BB  jBDDs   ......... iBY7 .................................
........................................   .     .B  ;BBB;....:v... ;BBB;  vB.       .......  QPi7 ................................
....................................... .DBQgqqL 2R:j7. . ... r5  .  ..  :rvB. .:r2XX. ...... PQi7 ................................
....................................... BB..rYIddB1IXdbi ..   jg:  ..  vSKSPQr.:ii..5B. ..    7BrY ................................
...................................... 1B        bZoooZP  .DBBBBBBB1. 7goooqB        SB   :LXPDQvvi ...............................
...................................... iBv .....  Qo.oi7 . PB.. ..BP ..Do.oQ5 .....  XMJqRRMPUvrv1v ...............................
....................................... iBI ..... :g.j: ... Pv...KI .. .J.D:  ....  XQZPXs7r77L7ri ................................
........................................ .QM  .... .ji...... PS.PK ....  iY. ....  RBviirLv7i .. ..................................
.........................................  DB2  ...  :i.....  .V. .....:i: ....  rBgiivsr .........................................
..........................................  iBBI   .. .......:...:............  PB1:7YY  ..........................................
............................................  7RBPiUu .......:i::..........  .2Bgri7J7  ...........................................
..............................................  :KRB. .:.................. :UZKBYivsi .............................................
................................................  gQ .:.................. :I7 .QEi7  ..............................................
................................................ 7B  ..................... X.5B1:Lv ...............................................
............................................  . :Br ...................... qBZr:vss ...............................................
........................................... iJ iQY ....................... 1Bg:vvi ................................................
.......................................... rB  B: ........................ .BZiv  .................................................
.......................................... sB   I ........................ .dD:Y ..................................................
.......................................... Bi   .J ........................ JBrv ..................................................
........................................... bB   .S ....................... :Bj7 ..................................................
............................................ Bq   .L ...................... :Rdi7 .................................................
.............................................. Bd  .: ...................... EgiY .................................................
.............................................. QBi gZ1Jr:  ................. Eg:j .................................................
............................................... 1BDBRPZRRQRRZP27.    ...... iBYrJ .................................................
................................................. irir7ir7sjSPMQBRbui  .:: UB2:71 .................................................
...................................................  iii       :iUPQQBR i QQ7i7u7 .................................................
..................................................... .........     .7Bv  Dg:7Yi ..................................................
....................................................................  sB   Bv7: ...................................................
...................................................................... PB  B5r. ...................................................
....................................................................... qBXB5r. ...................................................
........................................................................ igPYL. ...................................................
.......................................................................... VVJ  ...................................................
............................................................................  :....................................................
...................................................................................................................................
...................................................................................................................................
...................................................................................................................................
*/


import "solmate/tokens/WETH.sol";
import "./utils/BidSignatures.sol";
import "./utils/Pikapatible.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xKhepri and PikaPool Developers

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

    /// @dev WETH contract for this chain, set in constructor
    WETH public weth;

    /// @dev Maximum mint threshold amount to prevent excessive first-time token transfer costs
    /// @dev Stored in storage for gas optimization (as opposed to repeated mstores)
    uint256 public mintMax;

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
    function settleFromSignature(
        string memory auctionName,
        address auctionAddress,
        address bidder,
        uint256 amount,
        uint256 basePrice,
        uint256 tip,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {

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
                            tip
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        // handle signature error cases
        if (recovered == address(0) || recovered != bidder) return false;
        else return true;
    }
    
    /// @dev Internal function that finalizes the settlements upon verification of signatures
    function _settle(
        address auctionAddress, 
        address bidder, 
        uint256 amount, 
        uint256 basePrice,
        uint256 tip
    ) internal {
        uint256 totalWithoutTip = amount * basePrice;
        // check allowance before weth transfer to prevent reverts during batch settling
        if (weth.allowance(bidder, address(this)) >= totalWithoutTip) {
            bool p = weth.transferFrom(bidder, address(this), totalWithoutTip + tip);

            // if weth transfer succeeds, unwrap weth to eth and pay for creator's NFT mint
            // create a gas table for these steps as they add more gas overhead than they're worth
            if (p) {
                weth.withdraw(totalWithoutTip);
                Pikapatible(payable(auctionAddress)).mint{ value: totalWithoutTip }(bidder, amount);
            }
        }
    }

    /// @dev Function to be called by the Orchestrator following the conclusion of each auction
    /// @notice Once testnet deployments are complete and testing has been completed by the team's various addresses, restrict this function to Orchestrator only via access control
    function finalizeAuction(Signature[] memory signatures) external /* onlyOwner(=orchestrator) */ { 
        // uint256 length = signatures.length; // for when signatures is moved to calldata
        for (uint256 i; i < signatures.length; ) {
            if (signatures[i].bid.amount <= mintMax) {
                bool settle = settleFromSignature(
                    signatures[i].bid.auctionName,
                    payable(signatures[i].bid.auctionAddress),
                    signatures[i].bid.bidder,
                    signatures[i].bid.amount,
                    signatures[i].bid.basePrice,
                    signatures[i].bid.tip,
                    signatures[i].v,
                    signatures[i].r,
                    signatures[i].s
                );
                if (settle) { 
                    _settle(
                        signatures[i].bid.auctionAddress, 
                        signatures[i].bid.bidder, 
                        signatures[i].bid.amount, 
                        signatures[i].bid.basePrice,
                        signatures[i].bid.tip
                    );
                }
            }
            
            unchecked {
                ++i;
            }
        }
    }

    receive() external payable {}
}
