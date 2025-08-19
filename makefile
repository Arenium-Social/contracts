# Arenium Protocol Makefile
# ======================

# Network Configuration
BASE_SEPOLIA_RPC_URL ?= $(BASE_SEPOLIA_RPC_URL)
BASE_SEPOLIA_VERIFIER_URL = https://base-sepolia.blockscout.com/api/
AVALANCHE_RPC_URL ?= $(AVALANCHE_RPC_URL)
AVALANCHE_VERIFIER_URL = https://snowscan.xyz/api/
PRIVATE_KEY ?= $(PRIVATE_KEY)

deploy all:
	forge script script/DeployAll.s.sol:DeployAll --rpc-url $(BASE_SEPLOIA_RPC_URL) --private-key $(PRIVATE_KEY) --verify --verifier blockscout --verifier-url https://base-sepolia.blockscout.com/api/ --broadcast -vvvv
interaction script:
	forge script script/interaction-scripts/AMMScript.s.sol:AMMScript --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
clear:
	clear



forge script script/DeployAll.s.sol:DeployAll --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify --verifier blockscout --broadcast --verifier-url BASE_SEPOLIA_VERIFIER_URL