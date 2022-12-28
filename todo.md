    OZ needs iterative loop or _safeMint override for multiple mints to an addr
    solmate needs iterative loop or _safeMint override
add example nft contract for testing and to demonstrate:
    NFT creators will need to conform to orchestrator batch minting either via plugin or custom logic
      -consider pushing eip4494 to said plugin/custom logic for better UX. Nonce must however be incremented each transfer

add access control to nft contract so only Settlement.sol may mint

refactor tests to complete mints once example nft is ossified

gas optimizations:
    -replace keccak256 computation for EIP-712 variables
    -decide between for loop iteration of settlement within settleFromSignature() or separate finalizeAuction()