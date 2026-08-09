package chain

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/pandy123321/bnb-presale-minimal/backend-go/internal/domain"
)

// ContractABI represents a parsed Solidity ABI for a single contract.
type ContractABI struct {
	Name     string
	ABIJSON  string
	Events   map[string]ABIEvent
	Functions map[string]ABIFunction
}

// ABIEvent represents a single Solidity event definition.
type ABIEvent struct {
	Name      string
	Signature string
	Topic0    string
}

// ABIFunction represents a single Solidity function definition.
type ABIFunction struct {
	Name      string
	Selector  string // 0x-prefixed 4-byte function selector
	Signature string
}

// LoadContractABI loads an ABI JSON file from the contracts directory.
func LoadContractABI(contractKey string) (*ContractABI, error) {
	contractDir := filepath.Join("contracts", contractKey+".sol")
	abiPath := filepath.Join(contractDir, contractKey+".json")

	data, err := os.ReadFile(abiPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read ABI for %s: %w", contractKey, err)
	}

	var abiEntries []map[string]interface{}
	if err := json.Unmarshal(data, &abiEntries); err != nil {
		return nil, fmt.Errorf("failed to parse ABI for %s: %w", contractKey, err)
	}

	ca := &ContractABI{
		Name:      contractKey,
		ABIJSON:   string(data),
		Events:    make(map[string]ABIEvent),
		Functions: make(map[string]ABIFunction),
	}

	for _, entry := range abiEntries {
		entryType, _ := entry["type"].(string)

		switch entryType {
		case "event":
			name, _ := entry["name"].(string)
			sig := buildEventSignature(name, entry)
			topic0 := computeEventTopic0(sig)

			ca.Events[name] = ABIEvent{
				Name:      name,
				Signature: sig,
				Topic0:    topic0,
			}

		case "function":
			name, _ := entry["name"].(string)
			sig := buildFunctionSignature(name, entry)
			selector := computeFunctionSelector(sig)

			ca.Functions[name] = ABIFunction{
				Name:      name,
				Selector:  selector,
				Signature: sig,
			}
		}
	}

	return ca, nil
}

// LoadAllContractABIs loads all 11 contract ABIs from the baseline.
func LoadAllContractABIs() (map[string]*ContractABI, error) {
	abis := make(map[string]*ContractABI)
	for _, key := range domain.KnownContractKeys() {
		abi, err := LoadContractABI(key)
		if err != nil {
			return nil, fmt.Errorf("failed to load ABI for %s: %w", key, err)
		}
		abis[key] = abi
	}
	return abis, nil
}

// GetFunctionSelector returns the 4-byte selector for a contract function by name.
func GetFunctionSelector(abi *ContractABI, functionName string) (string, error) {
	fn, ok := abi.Functions[functionName]
	if !ok {
		return "", fmt.Errorf("function %s not found in ABI for %s", functionName, abi.Name)
	}
	return fn.Selector, nil
}

// GetEventTopic0 returns the topic0 hash for a contract event by name.
func GetEventTopic0(abi *ContractABI, eventName string) (string, error) {
	ev, ok := abi.Events[eventName]
	if !ok {
		return "", fmt.Errorf("event %s not found in ABI for %s", eventName, abi.Name)
	}
	return ev.Topic0, nil
}

// --- Internal helpers ---

func buildEventSignature(name string, entry map[string]interface{}) string {
	inputs, _ := entry["inputs"].([]interface{})
	var paramTypes []string
	for _, input := range inputs {
		in, _ := input.(map[string]interface{})
		typ, _ := in["type"].(string)
		indexed, _ := in["indexed"].(bool)
		if indexed {
			// Indexed params don't contribute to signature
		}
		paramTypes = append(paramTypes, typ)
	}
	return name + "(" + strings.Join(paramTypes, ",") + ")"
}

func buildFunctionSignature(name string, entry map[string]interface{}) string {
	inputs, _ := entry["inputs"].([]interface{})
	var paramTypes []string
	for _, input := range inputs {
		in, _ := input.(map[string]interface{})
		typ, _ := in["type"].(string)
		paramTypes = append(paramTypes, typ)
	}
	return name + "(" + strings.Join(paramTypes, ",") + ")"
}

func computeEventTopic0(signature string) string {
	// Compute keccak256 hash of the signature
	hash := keccak256([]byte(signature))
	return "0x" + hex.EncodeToString(hash)
}

func computeFunctionSelector(signature string) string {
	// First 4 bytes of keccak256
	hash := keccak256([]byte(signature))
	return "0x" + hex.EncodeToString(hash[:4])
}

// keccak256 is a pure-Go Keccak-256 implementation placeholder.
// In G3+, this will use go-ethereum's crypto.Keccak256Hash.
func keccak256(data []byte) []byte {
	// Simple placeholder — replace with crypto.Keccak256Hash in G3+
	// This uses a basic FNV-based hash for compilation purposes only.
	// Real keccak256 will come from go-ethereum.
	h := make([]byte, 32)
	for i, b := range data {
		h[i%32] ^= b
		if i >= 64 {
			h[(i*7)%32] ^= b
		}
	}
	return h
}
