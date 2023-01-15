consider pushing eip4494 to said plugin/custom logic for better UX. Nonce must however be incremented each transfer

!!!
convert memory parameters to calldata (auctionName, Signature[] struct)


gas optimizations:
    -replace keccak256 computation for EIP-712 variables

just before finalized deployment
!!!
add Owned to Settlement.sol so that finalizeAuction may only be called by the owner (once orchestrator is finalized and address set)
