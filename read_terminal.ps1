# Connect to main vessel CPU and read current terminal output
param([string]$KosHost = "127.0.0.1", [int]$Port = 5410, [int]$CPU = 1)

$client = New-Object System.Net.Sockets.TcpClient($KosHost, $Port)
$stream = $client.GetStream()
$stream.ReadTimeout = 3000
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

function Read-All {
    $all = ""
    Start-Sleep -Milliseconds 800
    while ($stream.DataAvailable) {
        $buf = New-Object byte[] 4096
        $n = $stream.Read($buf, 0, $buf.Length)
        $raw = [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
        $all += $raw
        Start-Sleep -Milliseconds 200
    }
    return ($all -replace '\x1b\[[0-9;]*[a-zA-Z]','') -replace '\r',''
}

Start-Sleep -Milliseconds 2500
$out = Read-All; Write-Host $out

$writer.WriteLine($CPU)
Start-Sleep -Milliseconds 2500
$out = Read-All; Write-Host $out

$client.Close()
