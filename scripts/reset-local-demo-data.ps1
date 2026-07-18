param(
    [string]$EnvFile = ".env",
    [string]$ContainerName = "hotel-marketplace-sqlserver"
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Environment file '$Path' was not found."
    }

    $values = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) {
            return
        }

        $name, $value = $line -split "=", 2
        if ($name -and $value) {
            $values[$name.Trim()] = $value.Trim().Trim('"')
        }
    }

    return $values
}

function Require-EnvValue {
    param(
        [hashtable]$Values,
        [string]$Name
    )

    if (-not $Values.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Values[$Name])) {
        throw "Required environment value '$Name' is missing from the env file."
    }

    return $Values[$Name]
}

$envValues = Read-EnvFile -Path $EnvFile
$saPassword = Require-EnvValue -Values $envValues -Name "SA_PASSWORD"
$database = Require-EnvValue -Values $envValues -Name "SQLSERVER_DATABASE"

$containerId = docker ps --filter "name=$ContainerName" --format "{{.ID}}" | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($containerId)) {
    throw "SQL Server container '$ContainerName' is not running."
}

$sql = @"
WITH TechnicalDemoNames AS (
    SELECT
        Id,
        ROW_NUMBER() OVER (ORDER BY CreatedAtUtc, Id) AS RowNumber
    FROM HotelProperties
    WHERE Name LIKE 'Smoke Hotel%'
       OR Name LIKE 'Bookable Hotel%'
       OR Name LIKE 'Reject Smoke Hotel%'
       OR Name LIKE 'QA%'
)
UPDATE hp
SET
    Name = CONCAT('Vietnam Boutique Hotel ', RIGHT(CONCAT('00', t.RowNumber), 2)),
    City = CASE ((t.RowNumber - 1) % 8)
        WHEN 0 THEN 'Ho Chi Minh City'
        WHEN 1 THEN 'Hanoi'
        WHEN 2 THEN 'Da Nang'
        WHEN 3 THEN 'Hoi An'
        WHEN 4 THEN 'Nha Trang'
        WHEN 5 THEN 'Da Lat'
        WHEN 6 THEN 'Phu Quoc'
        ELSE 'Ha Long'
    END,
    AddressLine = CASE ((t.RowNumber - 1) % 8)
        WHEN 0 THEN 'Nguyen Hue Boulevard'
        WHEN 1 THEN 'Hoan Kiem Lake District'
        WHEN 2 THEN 'Vo Nguyen Giap Beach Road'
        WHEN 3 THEN 'Ancient Town Riverside'
        WHEN 4 THEN 'Tran Phu Seafront'
        WHEN 5 THEN 'Tuyen Lam Lake Road'
        WHEN 6 THEN 'Long Beach Road'
        ELSE 'Bai Chay Waterfront'
    END,
    Description = 'Demo property for validating marketplace and operation flows.'
FROM HotelProperties hp
INNER JOIN TechnicalDemoNames t ON t.Id = hp.Id;

SELECT COUNT(*) AS RemainingTechnicalNames
FROM HotelProperties
WHERE Name LIKE 'Smoke Hotel%'
   OR Name LIKE 'Bookable Hotel%'
   OR Name LIKE 'Reject Smoke Hotel%'
   OR Name LIKE 'QA%';

SELECT TOP (12)
    Name,
    City,
    AddressLine
FROM HotelProperties
WHERE ApprovalStatus = 'Approved'
ORDER BY Name;
"@

$encodedSql = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
$containerScript = "echo $encodedSql | base64 -d > /tmp/reset-local-demo-data.sql && /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$saPassword' -d '$database' -C -i /tmp/reset-local-demo-data.sql"

docker exec $ContainerName bash -lc $containerScript
