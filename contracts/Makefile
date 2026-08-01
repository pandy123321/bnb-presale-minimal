.PHONY: install fmt build test fuzz invariant fork snapshot validate

install:
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
	forge install foundry-rs/forge-std@v1.16.2 --no-commit

fmt:
	forge fmt --check

build:
	forge clean
	forge build --sizes

test:
	forge test -vvv

fuzz:
	forge test --fuzz-runs 50000 -vvv

invariant:
	forge test --match-path 'test/invariant/**' -vvv

fork:
	@test -n "$$BSC_TESTNET_RPC_URL"
	@test -n "$$BSC_TESTNET_FORK_BLOCK"
	forge test --match-path 'test/fork/**' -vvv

snapshot:
	forge snapshot

validate: fmt build test fuzz invariant fork snapshot
