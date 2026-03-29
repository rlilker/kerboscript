# Connects to a specific CPU and shows what's happening
param([int]$CPU = 2, [string]$KosHost = "127.0.0.1", [int]$Port = 5410)

$client = New-Object System.Net.Sockets.TcpClient($KosHost, $Port)
$stream = $client.GetStream()
$stream.ReadTimeout = 2000
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

function Read-Available {
    $buf = New-Object byte[] 8192
    Start-Sleep -Milliseconds 500
    if ($stream.DataAvailable) {
        $n = $stream.Read($buf, 0, $buf.Length)
        $raw = [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
        return ($raw -replace '\x1b\[[0-9;]*[a-zA-Z]','') -replace '\r',''
    }
    return ""
}

Write-Host "=== Connecting ===" -ForegroundColor Cyan
Start-Sleep -Milliseconds 2500
$out = Read-Available; if ($out) { Write-Host $out }

Write-Host "=== Selecting CPU $CPU ===" -ForegroundColor Cyan
$writer.WriteLine($CPU)
Start-Sleep -Milliseconds 2500
$out = Read-Available; if ($out) { Write-Host $out }

Write-Host "=== Sending SWITCH TO 0. ===" -ForegroundColor Cyan
$writer.WriteLine("SWITCH TO 0.")
Start-Sleep -Milliseconds 2000
$out = Read-Available; if ($out) { Write-Host $out }

Write-Host "=== Sending LOG test ===" -ForegroundColor Cyan
$writer.WriteLine('LOG "cpu' + $CPU + '_alive" TO "0:/cpu' + $CPU + '_test.log".')
Start-Sleep -Milliseconds 2000
$out = Read-Available; if ($out) { Write-Host $out }

Write-Host "=== Sending PRINT SHIP:NAME ===" -ForegroundColor Cyan
$writer.WriteLine('PRINT SHIP:NAME.')
Start-Sleep -Milliseconds 2000
$out = Read-Available; if ($out) { Write-Host $out }

$client.Close()
Write-Host "=== Done. Check for cpu${CPU}_test.log ===" -ForegroundColor Green
