param(
    [int]$Port = 5080
)

$ErrorActionPreference = "Stop"

$connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $connections) {
    Write-Host "No backend process is listening on port $Port."
    exit 0
}

$processIds = $connections | Select-Object -ExpandProperty OwningProcess -Unique
foreach ($processId in $processIds) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if (-not $process) {
        continue
    }

    Write-Host "Stopping PID $processId ($($process.ProcessName)) on port $Port."
    Stop-Process -Id $processId -Force
}

Write-Host "Port $Port is free."
