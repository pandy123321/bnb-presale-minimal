package domain

import "time"

// ContractInstance represents a deployed smart contract.
type ContractInstance struct {
	Key             string
	Address         Address
	DeployBlock     BlockNumber
	DeployTx        TxHash
	DeployBlockHash TxHash
	RuntimeCodeHash string
}

// DeploymentSet represents a versioned set of contract deployments.
type DeploymentSet struct {
	ID           string
	SourceCommit string
	ABIHash      string
	Status       string
	ActivatedAt  *time.Time
}

// Status constants for deployment sets (matches DB CHECK constraint).
const (
	DeploymentStatusDiscovered     = "DISCOVERED"
	DeploymentStatusStaticVerified = "STATIC_VERIFIED"
	DeploymentStatusLiveVerified   = "LIVE_VERIFIED"
	DeploymentStatusActive         = "ACTIVE"
	DeploymentStatusSuperseded     = "SUPERSEDED"
	DeploymentStatusDeactivated    = "DEACTIVATED"
	DeploymentStatusRejected       = "REJECTED"
)

// Contract key constants — MUST match contract_key in contract_instances table.
const (
	ContractKeyPangu2Token         = "Pangu2Token"
	ContractKeyCostBasisManager    = "CostBasisManager"
	ContractKeyPancakeV2Pair       = "PancakeV2Pair"
	ContractKeyPancakeV2Adapter    = "PancakeV2Adapter"
	ContractKeyPancakeV2TwapOracle = "PancakeV2TwapOracle"
	ContractKeySupportPool         = "SupportPool"
	ContractKeyFeeVault            = "FeeVault"
	ContractKeyBuybackLocker       = "BuybackLocker"
	ContractKeyDividendDistributor = "DividendDistributor"
	ContractKeyPangu2TradeRouter   = "Pangu2TradeRouter"
	ContractKeyPangu2Staking       = "Pangu2Staking"
)

// BSCTestnetDeploymentBaseline holds the BSC Testnet (chainId=97) contract addresses
// from BSC_TESTNET_DEPLOYMENT_BASELINE.md — deployment set 3ef50b6.
var BSCTestnetDeploymentBaseline = map[string]ContractInstance{
	ContractKeyPangu2Token: {
		Key:             ContractKeyPangu2Token,
		Address:         "0x49a4a6ecaacc5d9ae60df7717f62e0605f591bc3",
		DeployBlock:     123502176,
		DeployTx:        "0x8f6ddf160a6d010d78748095a0bfa0a576e8ca7cd93dbdcc671806b43805398f",
		DeployBlockHash: "0x4525982663b89b10751223f2eb461c2daf58dba5905dc2b80f7ebadfa1aae6a4",
	},
	ContractKeyCostBasisManager: {
		Key:             ContractKeyCostBasisManager,
		Address:         "0x695660310afb747589d415d24f20a3eef05693d0",
		DeployBlock:     123502181,
		DeployTx:        "0x00dff4728b02e46d4aab34de4864ca8f260d9c3691070f8b589e039b107c489e",
		DeployBlockHash: "0x65d5aef0c487e83b47a61ae42f67931f2754f7130984de37421ce010103011f2",
	},
	ContractKeyPancakeV2Pair: {
		Key:             ContractKeyPancakeV2Pair,
		Address:         "0x07d481b52c27941f6daaeb53aaa879c588408f32",
		DeployBlock:     123502187,
		DeployTx:        "0x0126544f883371b8cccb5df4e8c1b5368765a27b9162186febf55a08fda8770b",
		DeployBlockHash: "0x06a66c470fe8cc5196a398723be1aeae11b12a341a312f970e246e1d42be125d",
	},
	ContractKeyPancakeV2Adapter: {
		Key:             ContractKeyPancakeV2Adapter,
		Address:         "0xc3bb2129cb362b82cc15ec63a8355e80d4198e3a",
		DeployBlock:     123502195,
		DeployTx:        "0xcc6de4cd4a191d9e16c64a73999ef7bdff3eac2748b25c511749b3214b7ebe16",
		DeployBlockHash: "0x971f3175daaaf9e9864adb7b4691d980148de747e854923eb6f775205e80de81",
	},
	ContractKeyPancakeV2TwapOracle: {
		Key:             ContractKeyPancakeV2TwapOracle,
		Address:         "0x11c39db60a95b232c6c303c1869aa81886694d9c",
		DeployBlock:     123502202,
		DeployTx:        "0xbd85ea70b006874a7a995ed047d1c8c83401335f61ede206de890da43e724382",
		DeployBlockHash: "0x6442518ec15d6cf17a36e93cc2843a458f87976a2cbf1ba294deeeda9825144b",
	},
	ContractKeySupportPool: {
		Key:             ContractKeySupportPool,
		Address:         "0xe6d37841b13d78e9ae759b77ecfaebeddb90589b",
		DeployBlock:     123502210,
		DeployTx:        "0x5e5c58303fa25fd937fc5d099478886c0d85a677d9d8603308b57f1feaf12b63",
		DeployBlockHash: "0xa2cab5fe4566bb5730d00bee6807a429a950d15e906e6aa43c21255a2d241ce4",
	},
	ContractKeyFeeVault: {
		Key:             ContractKeyFeeVault,
		Address:         "0xf82313eb70d24250d541c26796fe1615beb15d29",
		DeployBlock:     123502218,
		DeployTx:        "0x418e592e4f56eabff5773b93f9053ac3a13372319c71ee64dbf13130f9659312",
		DeployBlockHash: "0x7314d98104b6e0062e13fd3c3175fc5a8591e217cd1f43310d2e03f4335db648",
	},
	ContractKeyBuybackLocker: {
		Key:             ContractKeyBuybackLocker,
		Address:         "0x0a2283cd52523889fcb333596c3f0a14741b1cce",
		DeployBlock:     123502225,
		DeployTx:        "0x7f299e80f5017b94d1db8c6c0783c1c397afbe03ebafd7235d6e368ce8271d1a",
		DeployBlockHash: "0x4cb0a505722cb87fcf245afc1f5e76a8035c189248addfedbf48d8f0b065b774",
	},
	ContractKeyDividendDistributor: {
		Key:             ContractKeyDividendDistributor,
		Address:         "0x917705d794ec31144f7b2c4d62bfaab4fe327385",
		DeployBlock:     123502234,
		DeployTx:        "0xb749c44f0e31ec21df27b386061da518bc321dbaa9d048a33e30dc57865d5591",
		DeployBlockHash: "0x02bb3dde095a05f31f299c431ce8ee536e318411922bb5f2667874321b8da9ff",
	},
	ContractKeyPangu2TradeRouter: {
		Key:             ContractKeyPangu2TradeRouter,
		Address:         "0xb0b5b52cb99ee7ea055669ba49afd02cf69c71b5",
		DeployBlock:     123502248,
		DeployTx:        "0x36d1b0662777c539732e726e47a0a5bc48471431f31ea0916a992a95510966bb",
		DeployBlockHash: "0x87ef6a1b935446026a4fa908842e81852a79cab05dd32ec9bf1a0561f8b4d719",
	},
	ContractKeyPangu2Staking: {
		Key:             ContractKeyPangu2Staking,
		Address:         "0xf1d27ef1037c38b6752bae449fd3a460b49775a8",
		DeployBlock:     123502253,
		DeployTx:        "0xd503e6c381fa6fe8326ab3d6299e6263e038db3d94faf6155a4a79d85f80c1bf",
		DeployBlockHash: "0xa5dc8ab64f77697bff1a85a6cc4bf5b5dbba1674eed3d0983b5fdd372a0c7692",
	},
}

// BSCMainnetChainID is permanently rejected.
const BSCMainnetChainID ChainID = 56

// BSCTestnetChainID is the only allowed chain for this API.
const BSCTestnetChainID ChainID = 97

// KnownContractKeys returns the ordered list of public-facing contract keys.
func KnownContractKeys() []string {
	return []string{
		ContractKeyPangu2Token,
		ContractKeyCostBasisManager,
		ContractKeyPancakeV2Pair,
		ContractKeyPancakeV2Adapter,
		ContractKeyPancakeV2TwapOracle,
		ContractKeySupportPool,
		ContractKeyFeeVault,
		ContractKeyBuybackLocker,
		ContractKeyDividendDistributor,
		ContractKeyPangu2TradeRouter,
		ContractKeyPangu2Staking,
	}
}
