CONSULT with team on WETH approval workings. inquire what kind of smart contract logic is needed

add example nft contract for testing and to demonstrate:
    NFT creators will need to conform to orchestrator batch minting either via plugin or custom logic
      -ERC721A + access control to Settlement.sol address
      -consider pushing eip4494 to said plugin/custom logic for better UX. Nonce must however be incremented each transfer
add access control to nft contract so only Settlement.sol may mint

refactor tests to complete mints once example nft is ossified

gas optimizations:
    -replace keccak256 computation for EIP-712 variables
    -decide between for loop iteration of settlement within settleFromSignature() or separate finalizeAuction()