# V7.1 Migration Map

## Old → New Page Mapping

| Old Page | New Page | Notes |
|----------|----------|-------|
| HomeView.vue | HomePage.vue | Hero + Wallet + Protocol + Ranking |
| TradeView.vue | TradePage.vue | Market + Order + Activity |
| DividendView.vue | PortfolioPage.vue | Team + Referral sections |
| StakingView.vue | PortfolioPage.vue | Staking section |
| SupportView.vue | PortfolioPage.vue | Buyback batches section |
| MeView.vue | PortfolioPage.vue | Asset overview section |

## Deleted Components (root-level, replaced by packages/ui or common/)

| Deleted | Replacement |
|---------|-------------|
| BottomNav.vue | @ui/components/BottomNav.vue |
| DataStatusBanner.vue | @/components/common/DataStatusBanner.vue |
| ErrorState.vue | @/components/common/ErrorState.vue |
| EmptyState.vue | @/components/common/EmptyState.vue |
| LoadingSpinner.vue | @/components/common/LoadingSpinner.vue |

## Preserved Components

- ConnectSheet.vue (business component, no @ui equivalent)
- NetworkBanner.vue (no @ui equivalent)
- TransactionProgress.vue (still used by TradePage)

## Deleted Features

- features/dividend/useDividend.ts (no references after cleanup)
- features/support/useSupport.ts (no references after cleanup)
- features/profile/useProfile.ts (no references after cleanup)
