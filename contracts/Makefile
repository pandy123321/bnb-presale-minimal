.PHONY: install solc-check build test test-verbose fmt fmt-check clean coverage snapshot local-node deploy-local integration

install:
	npm ci

solc-check:
	node tools/compile-all-solcjs.js

build:
	forge build

test:
	forge test

test-verbose:
	forge test -vvv

fmt:
	forge fmt

fmt-check:
	forge fmt --check

clean:
	forge clean

coverage:
	./tools/run-coverage-gate.sh

snapshot:
	forge snapshot

local-node:
	anvil --chain-id 31337

deploy-local:
	forge script script/DeployLocal.s.sol:DeployLocal --rpc-url local --broadcast -vvv

integration:
	./tools/run-anvil-integration.sh
