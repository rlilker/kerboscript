# Connects to each CPU in the kOS menu and prints its tag/name so we know which is which
param(
    [string]$KosHost  = "127.0.0.1",
    [int]   $Port     = 5410,
    [int]   $MaxCPUs  = 4
)

for ($i = 1; $i -le $MaxCPUs; $i++) {
    Write-Host "CPU $i..." -NoNewline
    try {
        $client = New-Object System.Net.Sockets.TcpClient($KosHost, $Port)
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        Start-Sleep -Milliseconds 2000
        $writer.WriteLine($i)
        Start-Sleep -Milliseconds 2000
        $writer.WriteLine('PRINT "CPU:' + $i + ' TAG:" + CORE:TAG + " PART:" + CORE:PART:NAME.')
        Start-Sleep -Milliseconds 2000

        $buf = New-Object char[] 4096
        $n = $stream.Read($buf, 0, 4096)
        $raw = New-Object string($buf, 0, $n)
        $clean = $raw -replace '\x1b\[[0-9;]*[a-zA-Z]','' -replace '\r',''
        $lines = $clean -split "`n" | Where-Object { $_ -match "CPU:$i" }
        if ($lines) { Write-Host " $($lines[0].Trim())" -ForegroundColor Green }
        else        { Write-Host " (no output captured)" -ForegroundColor Yellow }

        $client.Close()
    } catch {
        Write-Host " not found" -ForegroundColor Red
        break
    }
}
