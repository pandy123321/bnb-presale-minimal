# ABI generation

ABI files are deliberately not fabricated without compiler output.

V1.1 source-level ABI delta is documented in:

```text
reports/ABI_EVENT_SCHEMA_CHANGELOG_V1.1.md
```

Generate the complete ABI set from the pinned final Head SHA:

```bash
forge build
mkdir -p abi
for contract in Pangu2Token Pangu2TradeRouter CostBasisManager FeeVault SupportPool BuybackLocker DividendDistributor GovernanceAdapter PancakeV3Adapter PancakeV3TwapOracle Pangu2LiquidityGateway; do
  forge inspect "$contract" abi > "abi/${contract}.json"
  forge inspect "$contract" methods > "abi/${contract}.methods.json"
  forge inspect "$contract" storage-layout > "abi/${contract}.storage-layout.json"
done
```

Bind generated files and event-topic evidence to the same reviewed PR Head SHA before Closeout.
