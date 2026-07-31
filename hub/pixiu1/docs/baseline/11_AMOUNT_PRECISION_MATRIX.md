# BNB Presale Internal System
## 11 Amount Unit and Precision Matrix

Version: 1.1.1-FINAL  
Status: Normative

| Business value | Solidity | Database | API JSON | Vue | Unit / formula |
|---|---|---|---|---|---|
| payment BNB | `msg.value uint256` | `bnb_amount_wei numeric(78,0)` | decimal string | string/BigInt utility | wei |
| total BNB raised | `uint256` | `total_bnb_raised_wei numeric(78,0)` | decimal string | string | wei |
| contract BNB balance | `uint256 eth_getBalance` | snapshot/reconciliation `numeric(78,0)` | decimal string | string | wei |
| min purchase | `uint256` | config integer string / transaction evidence | decimal string | string | wei |
| max purchase | `uint256` | same | decimal string | string | wei |
| wallet BNB cap | `uint256` | same | decimal string | string | wei |
| collection threshold | not on-chain | config integer string | decimal string | string | wei |
| retained BNB | not on-chain | config integer string | decimal string | string | wei |
| collection amount | `uint256` | `numeric(78,0)` | decimal string | string | wei |
| token amount | `uint256` | `token_amount_raw numeric(78,0)` | decimal string | string | token smallest unit |
| total token sold | `uint256` | `total_tokens_sold_raw numeric(78,0)` | decimal string | string | token smallest unit |
| token inventory | ERC-20 balance `uint256` | transfer/ledger/reconciliation `numeric(78,0)` | decimal string | string | token smallest unit |
| max token sale | `uint256` | raw `numeric(78,0)` or confirmed event | decimal string | string | token smallest unit |
| token per BNB | `uint256` | `token_per_bnb_raw numeric(78,0)` | decimal string | string | token smallest units per `1 ether` wei |
| purchase output | `Math.mulDiv(bnbAmount, tokenPerBNB, 1 ether)` | stored event result | decimal string | display only | floor division |
| Pancake token reserve | pair `uint112` decoded to uint | `numeric(78,0)` | decimal string | string | token smallest unit |
| Pancake WBNB reserve | pair `uint112` decoded to uint | `numeric(78,0)` | decimal string | string | wei |
| market token/BNB | backend BCMath | `numeric(78,0)` | decimal string | string | `reserveTokenRaw × 10^18 ÷ reserveWBNBWei` |
| coefficient numerator | N/A | `numeric(78,0)` | decimal string | string | positive dimensionless integer |
| coefficient denominator | N/A | `numeric(78,0)` | decimal string | string | positive nonzero dimensionless integer |
| suggested token/BNB | backend BCMath | `numeric(78,0)` | decimal string | string | `market × numerator ÷ denominator` |
| price deviation | N/A | integer basis points | decimal integer string | string/integer-safe display | basis points, 10,000 = 100% |
| nonce | transaction uint | `numeric(78,0)` | decimal string | string | transaction count |
| gas limit | transaction uint | `numeric(78,0)` | decimal string | string | gas units |
| gas price / fee | transaction uint | `numeric(78,0)` | decimal string | string | wei per gas |
| block number | uint | `bigint` | decimal string or safe bounded integer by API policy | string preferred | block height |
| confirmations | calculated integer | integer | decimal integer | safe UI integer | count, not an asset |

## Formatting Rules

- Storage and API raw fields never contain decimal points.
- No exponent notation is accepted.
- PHP asset arithmetic uses BCMath with scale `0`.
- Vue formatting may insert a decimal separator according to token decimals but must retain raw strings.
- Display rounding never changes transaction input.
- Percentages affecting price use basis points or integer numerator/denominator, never floating point.
