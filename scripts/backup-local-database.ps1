param(
    [string]$EnvFile = ".env",
    [string]$OutputDirectory = ".local\backups"
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

Import-EnvFile -Path $EnvFile

$database = $env:SQLSERVER_DATABASE
$saPassword = $env:SA_PASSWORD
if ([string]::IsNullOrWhiteSpace($database) -or $database -notmatch '^[A-Za-z0-9_]+$') {
    throw "SQLSERVER_DATABASE must contain only letters, digits, or underscores."
}
if ([string]::IsNullOrWhiteSpace($saPassword)) {
    throw "SA_PASSWORD is required."
}

$container = "hotel-marketplace-sqlserver"
$running = docker inspect -f "{{.State.Running}}" $container 2>$null
if ($running -ne "true") {
    throw "Container '$container' is not running. Start it with 'docker compose up -d sqlserver'."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fileName = "$database-$timestamp.bak"
$containerPath = "/var/opt/mssql/backup/$fileName"
$resolvedOutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
$hostPath = Join-Path $resolvedOutputDirectory $fileName
$escapedContainerPath = $containerPath.Replace("'", "''")
$query = "BACKUP DATABASE [$database] TO DISK = N'$escapedContainerPath' WITH COPY_ONLY, INIT, CHECKSUM, COMPRESSION;"

docker exec $container mkdir -p /var/opt/mssql/backup | Out-Null
docker exec -e "SQLCMDPASSWORD=$saPassword" $container /opt/mssql-tools18/bin/sqlcmd `
    -S localhost -U sa -C -b -Q $query | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Database backup failed with exit code $LASTEXITCODE."
}

docker cp "${container}:$containerPath" $hostPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Copying the database backup failed with exit code $LASTEXITCODE."
}

Write-Host "Backup completed: $hostPath"
