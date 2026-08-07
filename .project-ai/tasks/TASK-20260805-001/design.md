# TASK-20260805-001 — Design

## Architecture

```
apps/dapp/
├── src/
│   ├── App.vue                   ← <AppShell> + <router-view>
│   ├── router/index.ts           ← 3 routes (home/trade/portfolio)
│   ├── views/
│   │   ├── HomePage.vue          ← Hero + WalletPosition + Protocol + Ranking
│   │   ├── TradePage.vue         ← Market + OrderPanel + Activity
│   │   └── PortfolioPage.vue     ← AssetCard + LockSection + Team + Referral
│   ├── composables/
│   │   ├── useQuote.ts           ← Reused from features/trade/
│   │   ├── useTransaction.ts      ← Reused from features/transactions/
│   │   ├── useStaking.ts          ← Reused from features/staking/
│   │   ├── usePortfolio.ts        ← New: wallet summary + lock + distribution
│   │   ├── useMarket.ts           ← New: price + chart + trading_enabled polling
│   │   ├── useRanking.ts          ← New: ranking data
│   │   └── useReferral.ts         ← New: referral link + invite list
│   ├── stores/                    ← 3 Pinia stores (keep existing)
│   └── styles/
│       └── tokens.css             ← Prototype CSS tokens
├── packages/ui/                   ← New shared package
│   ├── tokens.css                 ← CSS variables
│   ├── global.css                 ← Reset + base layout
│   └── components/
│       ├── AppShell.vue           ← 430px container + header + nav
│       ├── BottomNav.vue          ← 3-tab nav
│       ├── HeaderBar.vue          ← Brand + lang + wallet
│       ├── Card.vue               ← Standard + soft variants
│       ├── Button.vue             ← Primary/secondary/text
│       ├── ButtonGroup.vue        ← Segmented control
│       ├── Tag.vue                ← demo/locked/open
│       ├── SectionHead.vue        ← Gradient accent bar + title
│       ├── Sheet.vue              ← Half-screen overlay container
│       ├── Toast.vue              ← Global notification
│       ├── MetricBlock.vue        ← Label + value
│       ├── DetailList.vue         ← Key-value list
│       ├── ProgressBar.vue        ← Transaction step indicator
│       ├── WalletConnectSheet.vue ← Wallet selection
│       └── DonutChart.vue         ← Distribution ring
└── ...
```

## Key Design Decisions

### Price Chart State Machine
```
trading_enabled === false → show "Trading not yet activated" placeholder
trading_enabled === true  → create lightweight-charts instance, render real chart
```

### Component Tree
```
App.vue
├── HeaderBar
├── <router-view />
├── BottomNav (3 tabs)
├── WalletConnectSheet (overlay)
├── Sheet (generic overlay)
└── Toast
```

### Data Classification
| Category | Source | Example |
|----------|--------|---------|
| Chain read | viem readContract | balance, positions, oracle |
| Chain write | wagmi writeContract | buy, sell, stake, unstake |
| API read | Pangu2ApiClient | ranking, activity, wallet summary |
| Static | hardcoded + i18n | hero text, Why BGP |

### Dependency Graph
```
TradePage → useQuote → Pangu2ApiClient (API)
          → useTransaction → wagmi/viem (on-chain)
          → useMarket → lightweight-charts (render) + API (trading_enabled)

PortfolioPage → usePortfolio → Pangu2ApiClient (API)
              → useStaking → wagmi/viem (on-chain)
              → useReferral → Pangu2ApiClient (API)

HomePage → useRanking → Pangu2ApiClient (API)
         → usePortfolio → Pangu2ApiClient (API)
```
