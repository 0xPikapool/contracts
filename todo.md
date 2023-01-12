consider pushing eip4494 to said plugin/custom logic for better UX. Nonce must however be incremented each transfer

refactor domain separator logic to be chain agnostic via internal computer and public getter functions

!!!
convert memory parameters to calldata (auctionName, Signature[] struct)
test for signature malleability
sort out spentsignatures and foundry bugging due to continue 

!! send batched tips once all mints have succeeded

gas optimizations:
    -replace keccak256 computation for EIP-712 variables
develop gas table to show why unwrapping weth to pay for creator mint() function is much more gas intensive than staying in weth

add Owned to Settlement.sol so that finalizeAuction may only be called by the owner (once orchestrator is finalized and address set)
