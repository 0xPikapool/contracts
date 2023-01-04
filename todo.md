currently operating under assumption that a WETH approval is made without a transfer to escrow/this contract. this will lead the settlement contract to call a transferFrom() to itself on behalf of the bidder as payment.
  -CONSULT with team on this style of WETH approval workings as it can lead to failed transactions, wasting gas
  -would prepayment/refunding be more gas efficient? too much hassle for off-chain validation?

add example nft contract for testing and to demonstrate:
    NFT creators will need to conform to orchestrator batch minting either via plugin or custom logic
      -ERC721A + access control to Settlement.sol address
      -consider pushing eip4494 to said plugin/custom logic for better UX. Nonce must however be incremented each transfer
add access control to nft contract so only Settlement.sol may mint

refactor domain separator logic to be chain agnostic via internal computer and public getter functions

gas optimizations:
    -replace keccak256 computation for EIP-712 variables
    -decide between for loop iteration of settlement within settleFromSignature() or separate finalizeAuction()