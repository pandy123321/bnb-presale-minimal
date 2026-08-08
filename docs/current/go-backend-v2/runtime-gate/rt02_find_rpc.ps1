$rpcs = @(
    "https://bsc-testnet-rpc.publicnode.com",
    "https://bsc-testnet.public.blastapi.io",
    "https://bsc-testnet.blockpi.network/v1/rpc/public",
    "https://data-seed-prebsc-1-s1.binance.org:8545",
    "https://data-seed-prebsc-2-s1.binance.org:8545"
)

foreach ($rpc in $rpcs) {
    Write-Host "Trying: $rpc"
    try {
        $body = '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
        $result = Invoke-RestMethod -Uri $rpc -Method Post -ContentType "application/json" -Body $body -TimeoutSec 10
        if ($result.result) {
            $chainId = [Convert]::ToInt64($result.result, 16)
            Write-Host "  SUCCESS! chainId = $chainId"
        } else {
            Write-Host "  ERROR: $($result.error | ConvertTo-Json)"
        }
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length)))"
    }
}
