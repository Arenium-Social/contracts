# Arenium Protocol Makefile
# ======================

# Network Configuration
BASE_SEPOLIA_RPC_URL ?= $(BASE_SEPOLIA_RPC_URL)
BASE_SEPOLIA_VERIFIER_URL = https://base-sepolia.blockscout.com/api/
AVALANCHE_RPC_URL ?= $(AVALANCHE_RPC_URL)
AVALANCHE_VERIFIER_URL = https://snowscan.xyz/api/
PRIVATE_KEY ?= $(PRIVATE_KEY)

# Common forge flags
FORGE_FLAGS = --private-key $(PRIVATE_KEY) -vvvv
VERIFY_FLAGS = --verify --verifier blockscout

# ======================
# Build Commands
# ======================

.PHONY: build
build:
	@echo "Building contracts..."
	forge build

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	forge clean

.PHONY: install
install:
	@echo "Installing dependencies..."
	forge install

.PHONY: update
update:
	@echo "Updating dependencies..."
	forge update

# ======================
# Test Commands
# ======================

.PHONY: test
test:
	@echo "Running all tests..."
	forge test

.PHONY: test-unit
test-unit:
	@echo "Running unit tests..."
	forge test --match-path "test/unit/*"

.PHONY: test-integration
test-integration:
	@echo "Running integration tests..."
	forge test --match-path "test/integration/*"

.PHONY: test-fork
test-fork:
	@echo "Running fork tests..."
	forge test --match-path "test/fork-uint/*"

.PHONY: test-gas
test-gas:
	@echo "Running gas report..."
	forge test --gas-report

.PHONY: test-coverage
test-coverage:
	@echo "Running coverage report..."
	forge coverage
# ==============================================================================
deploy all:
	forge script script/DeployAll.s.sol:DeployAll --rpc-url $(BASE_SEPLOIA_RPC_URL) --private-key $(PRIVATE_KEY) --verify --verifier blockscout --verifier-url https://base-sepolia.blockscout.com/api/ --broadcast -vvvv
interaction script:
	forge script script/interaction-scripts/AMMScript.s.sol:AMMScript --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
clear:
	clear



forge script script/DeployAll.s.sol:DeployAll --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify --verifier blockscout --broadcast --verifier-url BASE_SEPOLIA_VERIFIER_URL
