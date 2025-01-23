deploy all:
	forge script script/DeployAll.s.sol:DeployAll --rpc-url $(BASE_SEPLOIA_RPC_URL) --private-key $(PRIVATE_KEY) --verify --verifier blockscout --verifier-url https://base-sepolia.blockscout.com/api/ --broadcast -vvvv
interaction script:
	forge script script/interaction-scripts/AMMScript.s.sol:AMMScript --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
clear:
	clear



forge script script/DeployAll.s.sol:DeployAll --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify --verifier blockscout --broadcast --verifier-url BASE_SEPOLIA_VERIFIER_URL