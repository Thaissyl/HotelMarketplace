param(
    [int]$Port = 5080,
    [string]$EnvFile = ".env",
    [switch]$ForceRestart
)

$ErrorActionPreference = "Stop"

function Import-EnvFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Environment file '$Path' was not found. Copy .env.example to .env first."
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) {
            return
        }

        $name, $value = $line -split "=", 2
        if ($name -and $value) {
            [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim().Trim('"'), "Process")
        }
    }
}

function Get-PortOwner {
    param([int]$LocalPort)

    return Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Test-ApiHealth {
    param([int]$LocalPort)

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$LocalPort/health" -Method Get -TimeoutSec 3
        return $response.status -eq "Healthy"
    }
    catch {
        return $false
    }
}

Import-EnvFile -Path $EnvFile
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ASPNETCORE_URLS = "http://localhost:$Port"

$portOwner = Get-PortOwner -LocalPort $Port
if ($portOwner) {
    $process = Get-Process -Id $portOwner.OwningProcess -ErrorAction SilentlyContinue
    if (Test-ApiHealth -LocalPort $Port) {
        Write-Host "Backend API is already running on http://localhost:$Port (PID $($portOwner.OwningProcess))."
        Write-Host "Swagger: http://localhost:$Port/swagger"
        exit 0
    }

    if (-not $ForceRestart) {
        Write-Host "Port $Port is already in use by PID $($portOwner.OwningProcess) ($($process.ProcessName))."
        Write-Host "Run scripts\stop-local-backend.ps1, or rerun this script with -ForceRestart."
        exit 1
    }

    Stop-Process -Id $portOwner.OwningProcess -Force
    Start-Sleep -Seconds 2
}

docker compose up -d sqlserver | Out-Host

for ($attempt = 1; $attempt -le 60; $attempt += 1) {
    $health = docker inspect -f "{{.State.Health.Status}}" hotel-marketplace-sqlserver 2>$null
    if ($health -eq "healthy") {
        break
    }

    Start-Sleep -Seconds 2
}

$finalHealth = docker inspect -f "{{.State.Health.Status}}" hotel-marketplace-sqlserver 2>$null
if ($finalHealth -ne "healthy") {
    throw "SQL Server container did not become healthy. Current health: $finalHealth"
}

Write-Host "Starting backend API on http://localhost:$Port"
Write-Host "Swagger will be available at http://localhost:$Port/swagger"
dotnet run --project .\backend\src\Presentation.Api\Presentation.Api.csproj
