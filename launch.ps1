# =============================================================================
# Ike I Launch Script
# Prepares booster processors and launches the main autopilot.
# =============================================================================

param(
    [string]$KosHost   = "127.0.0.1",
    [int]   $Port      = 5410,
    [int]   $MainCPU   = 1,          # kOS menu index for main vessel CPU
    [int[]] $BoosterCPUs = @(2, 3),  # kOS menu indices for booster CPUs
    [switch]$MonitorLog,             # Stream flight.log to console after launch
    [switch]$TestOnly                # Run pre-flight test only, do not launch
)

$LogFile = "$PSScriptRoot\flight.log"

# -----------------------------------------------------------------------------
# Core telnet helper
# -----------------------------------------------------------------------------
function Invoke-KOS {
    param(
        [int]      $CPU,
        [string[]] $Commands,
        [int]      $ConnectWait  = 2000,   # ms to wait for menu
        [int]      $CommandDelay = 1500    # ms between commands
    )

    $client = New-Object System.Net.Sockets.TcpClient($KosHost, $Port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    Start-Sleep -Milliseconds $ConnectWait
    $writer.WriteLine($CPU)
    Start-Sleep -Milliseconds 2000

    foreach ($cmd in $Commands) {
        Write-Verbose "  >> $cmd"
        $writer.WriteLine($cmd)
        Start-Sleep -Milliseconds $CommandDelay
    }

    $client.Close()
}

# -----------------------------------------------------------------------------
# Launch (or test-only)
# launch.ks auto-runs test.ks first, so -TestOnly just runs the test script
# directly without proceeding to the countdown.
# -----------------------------------------------------------------------------
if ($TestOnly) {
    Write-Host "`nRunning pre-flight test only..." -ForegroundColor Cyan
    Invoke-KOS -CPU $MainCPU -Commands @(
        'SWITCH TO 0.',
        'RUN test.'
    ) -CommandDelay 1500
    Write-Host "  Test running - check test_results.txt for results.`n" -ForegroundColor Green
} else {
    Write-Host "`nLaunching..." -ForegroundColor Cyan
    Invoke-KOS -CPU $MainCPU -Commands @(
        'SWITCH TO 0.',
        'RUN launch.'
    ) -CommandDelay 1500
    Write-Host "  Launch script running.`n" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# Step 3: Optionally tail flight.log
# -----------------------------------------------------------------------------
if ($MonitorLog) {
    Write-Host "Monitoring flight.log (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ("-" * 60)

    $lastSize = 0
    while ($true) {
        Start-Sleep -Seconds 2
        if (Test-Path $LogFile) {
            $content = Get-Content $LogFile -Raw
            if ($content.Length -gt $lastSize) {
                Write-Host $content.Substring($lastSize) -NoNewline
                $lastSize = $content.Length
            }
        }
    }
}
