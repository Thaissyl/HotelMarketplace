param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    [string]$EnvFile = ".env",
    [switch]$Force
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

if (-not $Force) {
    throw "Restore replaces the local database. Rerun with -Force after stopping the API."
}
if (-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) {
    throw "Backup file '$BackupFile' was not found."
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

$resolvedBackupFile = (Resolve-Path -LiteralPath $BackupFile).Path
$containerPath = "/var/opt/mssql/backup/restore-local.bak"
docker exec $container mkdir -p /var/opt/mssql/backup | Out-Null
docker cp $resolvedBackupFile "${container}:$containerPath" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Copying the database backup failed with exit code $LASTEXITCODE."
}

$escapedContainerPath = $containerPath.Replace("'", "''")
$query = @"
BEGIN TRY
    IF DB_ID(N'$database') IS NOT NULL
        ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    RESTORE DATABASE [$database] FROM DISK = N'$escapedContainerPath' WITH REPLACE;
    ALTER DATABASE [$database] SET MULTI_USER;
END TRY
BEGIN CATCH
    IF DB_ID(N'$database') IS NOT NULL
        ALTER DATABASE [$database] SET MULTI_USER;
    THROW;
END CATCH;
"@

docker exec -e "SQLCMDPASSWORD=$saPassword" $container /opt/mssql-tools18/bin/sqlcmd `
    -S localhost -U sa -C -b -d master -Q $query | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Database restore failed with exit code $LASTEXITCODE."
}

Write-Host "Restore completed for database '$database'."
