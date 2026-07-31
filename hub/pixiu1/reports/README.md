# WP-01 Evidence

The workflow `.github/workflows/wp01-baseline-revalidation.yml` executes the frozen contract and environment revalidation and uploads the generated evidence as a GitHub Actions artifact.

Expected generated files:

- `WP01_BASELINE_REVALIDATION_REPORT_CN.md`
- `WP01_RAW_COMMAND_LOG.txt`
- `WP01_ENVIRONMENT_REPORT.txt`
- `WP01_ABI_SHA256.txt`
- `WP01_FILE_SHA256SUMS.txt`
- `generated/BNBPresale.abi.json`

The workflow does not commit generated files back to the repository and does not develop Laravel functionality.
