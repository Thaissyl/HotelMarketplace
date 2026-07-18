param(
    [string]$EnvFile = ".env",
    [string]$ContainerName = "hotel-marketplace-sqlserver",
    [string]$Password = "Test@123"
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

function New-Pbkdf2PasswordHash {
    param([string]$PlainTextPassword)

    $salt = [byte[]]::new(16)
    $randomNumberGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomNumberGenerator.GetBytes($salt)
    }
    finally {
        $randomNumberGenerator.Dispose()
    }
    $deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
        $PlainTextPassword,
        $salt,
        210000,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $hash = $deriveBytes.GetBytes(32)
    }
    finally {
        $deriveBytes.Dispose()
    }

    return 'PBKDF2-SHA256${0}${1}${2}' -f 210000, [Convert]::ToBase64String($salt), [Convert]::ToBase64String($hash)
}

$envValues = Read-EnvFile -Path $EnvFile
$saPassword = Require-EnvValue -Values $envValues -Name "SA_PASSWORD"
$database = Require-EnvValue -Values $envValues -Name "SQLSERVER_DATABASE"

$containerId = docker ps --filter "name=$ContainerName" --format "{{.ID}}" | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($containerId)) {
    throw "SQL Server container '$ContainerName' is not running."
}

$accounts = @(
    @{ Email = "customer@test.com"; FullName = "Test Customer"; Phone = "0900000001"; Role = "Customer"; HotelScoped = $false },
    @{ Email = "owner@test.com"; FullName = "Test Owner"; Phone = "0900000002"; Role = "PropertyOwner"; HotelScoped = $true },
    @{ Email = "manager@test.com"; FullName = "Test Hotel Manager"; Phone = "0900000003"; Role = "HotelManager"; HotelScoped = $true },
    @{ Email = "reception@test.com"; FullName = "Test Receptionist"; Phone = "0900000004"; Role = "Receptionist"; HotelScoped = $true },
    @{ Email = "housekeeping@test.com"; FullName = "Test Housekeeping"; Phone = "0900000005"; Role = "HousekeepingStaff"; HotelScoped = $true },
    @{ Email = "maintenance@test.com"; FullName = "Test Maintenance"; Phone = "0900000006"; Role = "MaintenanceStaff"; HotelScoped = $true },
    @{ Email = "admin@test.com"; FullName = "Test Platform Admin"; Phone = "0900000007"; Role = "PlatformAdministrator"; HotelScoped = $false }
)

$accountRows = foreach ($account in $accounts) {
    $hash = New-Pbkdf2PasswordHash -PlainTextPassword $Password
    "('$([Guid]::NewGuid())', '$($account.Email)', '$($account.Phone)', '$hash', '$($account.FullName)', '$($account.Role)', $([int]$account.HotelScoped))"
}

$valuesSql = $accountRows -join ",`n        "

$sql = @"
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;

DECLARE @Now datetime2(3) = SYSUTCDATETIME();

DECLARE @Accounts TABLE
(
    Id uniqueidentifier NOT NULL,
    Email nvarchar(256) NOT NULL,
    PhoneNumber nvarchar(32) NOT NULL,
    PasswordHash nvarchar(512) NOT NULL,
    FullName nvarchar(200) NOT NULL,
    RoleCode nvarchar(64) NOT NULL,
    HotelScoped bit NOT NULL
);

INSERT INTO @Accounts (Id, Email, PhoneNumber, PasswordHash, FullName, RoleCode, HotelScoped)
VALUES
        $valuesSql;

UPDATE existing
SET
    PhoneNumber = source.PhoneNumber,
    PasswordHash = source.PasswordHash,
    FullName = source.FullName,
    Status = 'Active'
FROM UserAccounts existing
INNER JOIN @Accounts source ON source.Email = existing.Email;

INSERT INTO UserAccounts (Id, Email, PhoneNumber, PasswordHash, FullName, Status, CreatedAtUtc)
SELECT source.Id, source.Email, source.PhoneNumber, source.PasswordHash, source.FullName, 'Active', @Now
FROM @Accounts source
WHERE NOT EXISTS
(
    SELECT 1
    FROM UserAccounts existing
    WHERE existing.Email = source.Email
);

INSERT INTO UserAccountRoles (Id, UserAccountId, RoleId, IsActive, AssignedAtUtc)
SELECT NEWID(), userAccount.Id, role.Id, 1, @Now
FROM @Accounts source
INNER JOIN UserAccounts userAccount ON userAccount.Email = source.Email
INNER JOIN UserRoles role ON role.Code = source.RoleCode
WHERE NOT EXISTS
(
    SELECT 1
    FROM UserAccountRoles existing
    WHERE existing.UserAccountId = userAccount.Id
      AND existing.RoleId = role.Id
      AND existing.IsActive = 1
);

DECLARE @OwnerUserAccountId uniqueidentifier =
(
    SELECT Id
    FROM UserAccounts
    WHERE Email = 'owner@test.com'
);

DECLARE @HotelId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM HotelProperties
    WHERE ApprovalStatus = 'Approved'
      AND PublicationStatus = 'Published'
    ORDER BY CreatedAtUtc, Id
);

IF @HotelId IS NULL
BEGIN
    SET @HotelId = NEWID();

    INSERT INTO HotelProperties
    (
        Id,
        OwnerUserAccountId,
        Name,
        City,
        AddressLine,
        ContactEmail,
        ContactPhone,
        Description,
        ApprovalStatus,
        PublicationStatus,
        DefaultCommissionRate,
        IsWalkInEnabled,
        CreatedAtUtc
    )
    VALUES
    (
        @HotelId,
        @OwnerUserAccountId,
        'Demo Central Hotel',
        'Ho Chi Minh City',
        'Nguyen Hue Boulevard',
        'hotel@test.com',
        '0900000099',
        'Demo hotel for local role testing.',
        'Approved',
        'Published',
        0.1000,
        1,
        @Now
    );
END;
ELSE
BEGIN
    UPDATE HotelProperties
    SET OwnerUserAccountId = @OwnerUserAccountId
    WHERE Id = @HotelId;
END;

INSERT INTO HotelStaffAssignments (Id, UserAccountId, HotelId, RoleId, AssignedByUserAccountId, IsActive, AssignedAtUtc)
SELECT NEWID(), userAccount.Id, @HotelId, role.Id, @OwnerUserAccountId, 1, @Now
FROM @Accounts source
INNER JOIN UserAccounts userAccount ON userAccount.Email = source.Email
INNER JOIN UserRoles role ON role.Code = source.RoleCode
WHERE source.HotelScoped = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM HotelStaffAssignments existing
      WHERE existing.UserAccountId = userAccount.Id
        AND existing.HotelId = @HotelId
        AND existing.RoleId = role.Id
        AND existing.IsActive = 1
  );

DECLARE @StandardRoomTypeId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM RoomTypes
    WHERE HotelId = @HotelId
      AND Name = 'Deluxe King'
);

IF @StandardRoomTypeId IS NULL
BEGIN
    SET @StandardRoomTypeId = NEWID();

    INSERT INTO RoomTypes
    (
        Id,
        HotelId,
        Name,
        AdultCapacity,
        ChildCapacity,
        BasePricePerNight,
        Description,
        Status
    )
    VALUES
    (
        @StandardRoomTypeId,
        @HotelId,
        'Deluxe King',
        2,
        1,
        1250000.00,
        'Comfortable king room for local operation testing.',
        'Active'
    );
END;

DECLARE @TwinRoomTypeId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM RoomTypes
    WHERE HotelId = @HotelId
      AND Name = 'Premium Twin'
);

IF @TwinRoomTypeId IS NULL
BEGIN
    SET @TwinRoomTypeId = NEWID();

    INSERT INTO RoomTypes
    (
        Id,
        HotelId,
        Name,
        AdultCapacity,
        ChildCapacity,
        BasePricePerNight,
        Description,
        Status
    )
    VALUES
    (
        @TwinRoomTypeId,
        @HotelId,
        'Premium Twin',
        2,
        2,
        1450000.00,
        'Twin room used for staff workflow validation.',
        'Active'
    );
END;

DECLARE @Rooms TABLE
(
    RoomNumber nvarchar(32) NOT NULL,
    RoomTypeId uniqueidentifier NOT NULL,
    Status nvarchar(64) NOT NULL
);

INSERT INTO @Rooms (RoomNumber, RoomTypeId, Status)
VALUES
    ('101', @StandardRoomTypeId, 'Available'),
    ('102', @StandardRoomTypeId, 'Available'),
    ('103', @StandardRoomTypeId, 'Dirty'),
    ('104', @StandardRoomTypeId, 'Maintenance'),
    ('201', @TwinRoomTypeId, 'Available'),
    ('202', @TwinRoomTypeId, 'Available'),
    ('203', @TwinRoomTypeId, 'Dirty'),
    ('204', @TwinRoomTypeId, 'OutOfService');

INSERT INTO PhysicalRooms (Id, HotelId, RoomTypeId, RoomNumber, Status)
SELECT NEWID(), @HotelId, source.RoomTypeId, source.RoomNumber, source.Status
FROM @Rooms source
WHERE NOT EXISTS
(
    SELECT 1
    FROM PhysicalRooms existing
    WHERE existing.HotelId = @HotelId
      AND existing.RoomNumber = source.RoomNumber
);

DECLARE @CustomerUserAccountId uniqueidentifier =
(
    SELECT Id
    FROM UserAccounts
    WHERE Email = 'customer@test.com'
);

DECLARE @ReceptionistUserAccountId uniqueidentifier =
(
    SELECT Id
    FROM UserAccounts
    WHERE Email = 'reception@test.com'
);

DECLARE @HousekeepingUserAccountId uniqueidentifier =
(
    SELECT Id
    FROM UserAccounts
    WHERE Email = 'housekeeping@test.com'
);

DECLARE @MaintenanceUserAccountId uniqueidentifier =
(
    SELECT Id
    FROM UserAccounts
    WHERE Email = 'maintenance@test.com'
);

DECLARE @ArrivalBookingId uniqueidentifier =
(
    SELECT Id
    FROM Bookings
    WHERE BookingCode = 'DEMO-ARRIVAL'
);

IF @ArrivalBookingId IS NULL
BEGIN
    SET @ArrivalBookingId = NEWID();

    INSERT INTO Bookings
    (
        Id,
        BookingCode,
        CustomerUserAccountId,
        HotelId,
        CheckInDate,
        CheckOutDate,
        PaymentMode,
        Source,
        Status,
        TotalAmount,
        GuestFullName,
        GuestPhone,
        CreatedAtUtc,
        PaymentExpiresAtUtc
    )
    VALUES
    (
        @ArrivalBookingId,
        'DEMO-ARRIVAL',
        @CustomerUserAccountId,
        @HotelId,
        CONVERT(date, DATEADD(day, 1, @Now)),
        CONVERT(date, DATEADD(day, 3, @Now)),
        'PlatformCollect',
        'Marketplace',
        'Confirmed',
        2500000.00,
        'Linh Nguyen',
        '0900000111',
        @Now,
        NULL
    );

    INSERT INTO BookingRooms
    (
        Id,
        BookingId,
        RoomTypeId,
        Quantity,
        UnitPricePerNight,
        Nights,
        LineAmount
    )
    VALUES
    (
        NEWID(),
        @ArrivalBookingId,
        @StandardRoomTypeId,
        1,
        1250000.00,
        2,
        2500000.00
    );
END;

DECLARE @InHouseBookingId uniqueidentifier =
(
    SELECT Id
    FROM Bookings
    WHERE BookingCode = 'DEMO-INHOUSE'
);

IF @InHouseBookingId IS NULL
BEGIN
    DECLARE @InHouseBookingRoomId uniqueidentifier = NEWID();
    DECLARE @InHouseRoomId uniqueidentifier =
    (
        SELECT TOP (1) Id
        FROM PhysicalRooms
        WHERE HotelId = @HotelId
          AND RoomNumber = '201'
    );

    SET @InHouseBookingId = NEWID();

    INSERT INTO Bookings
    (
        Id,
        BookingCode,
        CustomerUserAccountId,
        HotelId,
        CheckInDate,
        CheckOutDate,
        PaymentMode,
        Source,
        Status,
        TotalAmount,
        GuestFullName,
        GuestPhone,
        CreatedAtUtc,
        PaymentExpiresAtUtc
    )
    VALUES
    (
        @InHouseBookingId,
        'DEMO-INHOUSE',
        @CustomerUserAccountId,
        @HotelId,
        CONVERT(date, @Now),
        CONVERT(date, DATEADD(day, 1, @Now)),
        'PayAtProperty',
        'WalkIn',
        'CheckedIn',
        1450000.00,
        'Minh Tran',
        '0900000222',
        @Now,
        NULL
    );

    INSERT INTO BookingRooms
    (
        Id,
        BookingId,
        RoomTypeId,
        Quantity,
        UnitPricePerNight,
        Nights,
        LineAmount
    )
    VALUES
    (
        @InHouseBookingRoomId,
        @InHouseBookingId,
        @TwinRoomTypeId,
        1,
        1450000.00,
        1,
        1450000.00
    );

    INSERT INTO BookingRoomAssignments
    (
        Id,
        HotelId,
        BookingId,
        BookingRoomId,
        PhysicalRoomId,
        StartDate,
        EndDate,
        AssignedByUserAccountId,
        Status,
        AssignedAtUtc
    )
    VALUES
    (
        NEWID(),
        @HotelId,
        @InHouseBookingId,
        @InHouseBookingRoomId,
        @InHouseRoomId,
        CONVERT(date, @Now),
        CONVERT(date, DATEADD(day, 1, @Now)),
        @ReceptionistUserAccountId,
        'Active',
        @Now
    );

    INSERT INTO GuestStayRecords
    (
        Id,
        HotelId,
        BookingId,
        CheckedInByUserAccountId,
        CheckedOutByUserAccountId,
        GuestFullName,
        IdentityDocumentNumber,
        CheckedInAtUtc,
        CheckedOutAtUtc
    )
    VALUES
    (
        NEWID(),
        @HotelId,
        @InHouseBookingId,
        @ReceptionistUserAccountId,
        NULL,
        'Minh Tran',
        'DEMO-ID-201',
        @Now,
        NULL
    );

    UPDATE PhysicalRooms
    SET Status = 'Occupied'
    WHERE Id = @InHouseRoomId;
END;

DECLARE @DirtyRoomId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM PhysicalRooms
    WHERE HotelId = @HotelId
      AND RoomNumber = '103'
);

IF @DirtyRoomId IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM HousekeepingTasks
       WHERE HotelId = @HotelId
         AND PhysicalRoomId = @DirtyRoomId
         AND Status IN ('Open', 'InProgress')
   )
BEGIN
    UPDATE PhysicalRooms
    SET Status = 'Dirty'
    WHERE Id = @DirtyRoomId;

    INSERT INTO HousekeepingTasks
    (
        Id,
        HotelId,
        PhysicalRoomId,
        BookingId,
        AssignedToUserAccountId,
        TaskType,
        Status,
        CreatedAtUtc
    )
    VALUES
    (
        NEWID(),
        @HotelId,
        @DirtyRoomId,
        NULL,
        @HousekeepingUserAccountId,
        'CheckoutCleaning',
        'Open',
        @Now
    );
END;

DECLARE @MaintenanceRoomId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM PhysicalRooms
    WHERE HotelId = @HotelId
      AND RoomNumber = '104'
);

IF @MaintenanceRoomId IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM MaintenanceRequests
       WHERE HotelId = @HotelId
         AND PhysicalRoomId = @MaintenanceRoomId
         AND Status IN ('Open', 'InProgress')
   )
BEGIN
    UPDATE PhysicalRooms
    SET Status = 'Maintenance'
    WHERE Id = @MaintenanceRoomId;

    INSERT INTO MaintenanceRequests
    (
        Id,
        HotelId,
        PhysicalRoomId,
        ReportedByUserAccountId,
        AssignedToUserAccountId,
        Description,
        Severity,
        Status,
        CreatedAtUtc
    )
    VALUES
    (
        NEWID(),
        @HotelId,
        @MaintenanceRoomId,
        @ReceptionistUserAccountId,
        @MaintenanceUserAccountId,
        'Air conditioner is not cooling properly.',
        'High',
        'Open',
        @Now
    );
END;

SELECT
    source.RoleCode AS [Role],
    userAccount.Email,
    '$Password' AS [Password],
    CASE WHEN source.HotelScoped = 1 THEN CONVERT(nvarchar(36), @HotelId) ELSE '' END AS HotelId
FROM @Accounts source
INNER JOIN UserAccounts userAccount ON userAccount.Email = source.Email
ORDER BY
    CASE source.RoleCode
        WHEN 'Customer' THEN 1
        WHEN 'PropertyOwner' THEN 2
        WHEN 'HotelManager' THEN 3
        WHEN 'Receptionist' THEN 4
        WHEN 'HousekeepingStaff' THEN 5
        WHEN 'MaintenanceStaff' THEN 6
        WHEN 'PlatformAdministrator' THEN 7
        ELSE 99
    END;
"@

$encodedSql = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sql))
$containerScript = "echo $encodedSql | base64 -d > /tmp/seed-local-test-accounts.sql && /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$saPassword' -d '$database' -C -i /tmp/seed-local-test-accounts.sql"

docker exec $ContainerName bash -lc $containerScript
