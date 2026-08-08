$rpcs = @(
    "https://bsc-testnet-rpc.publicnode.com",
    "https://rpc.ankr.com/bsc_testnet_chapel",
    "https://bsc-testnet.drpc.org",
    "https://1rpc.io/bnb-testnet",
    "https://bsc-testnet.nodereal.io/v1/1659dfb40aa24bbb8153a677b98064d7"
)

foreach ($rpc in $rpcs) {
    Write-Host "Trying: $rpc"
    try {
        $body = '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
        $result = Invoke-RestMethod -Uri $rpc -Method Post -ContentType "application/json" -Body $body -TimeoutSec 10
        if ($result.result) {
            $chainId = [Convert]::ToInt64($result.result, 16)
            Write-Host "  OK ($chainId)"
        } else {
            Write-Host "  ERR: $($result.error)"
        }
    } catch {
        Write-Host "  FAIL: $($_.Exception.Message.Substring(0, [Math]::Min(60, $_.Exception.Message.Length)))"
    }
}
