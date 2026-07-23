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

DECLARE @MarketplaceHotels TABLE
(
    Name nvarchar(200) NOT NULL,
    City nvarchar(100) NOT NULL,
    AddressLine nvarchar(300) NOT NULL,
    ContactEmail nvarchar(256) NOT NULL,
    ContactPhone nvarchar(32) NOT NULL,
    Description nvarchar(2000) NOT NULL,
    StandardPrice decimal(18, 2) NOT NULL,
    SuitePrice decimal(18, 2) NOT NULL
);

INSERT INTO @MarketplaceHotels
(
    Name,
    City,
    AddressLine,
    ContactEmail,
    ContactPhone,
    Description,
    StandardPrice,
    SuitePrice
)
VALUES
    (
        'Hanoi Heritage Residence',
        'Ha Noi',
        '36 Hang Trong, Hoan Kiem',
        'stay@hanoiheritage.test',
        '0901000101',
        'A refined city residence near Hoan Kiem Lake and the Old Quarter.',
        1180000.00,
        1890000.00
    ),
    (
        'Da Nang Riverside Retreat',
        'Da Nang',
        '128 Bach Dang, Hai Chau',
        'stay@danangriverside.test',
        '0901000102',
        'Modern river-view accommodation with convenient access to the beach and city center.',
        1320000.00,
        2150000.00
    ),
    (
        'Hoi An Lantern Boutique',
        'Hoi An',
        '24 Tran Phu, Minh An',
        'stay@hoianlantern.test',
        '0901000103',
        'A quiet boutique stay inspired by the architecture and evening lanterns of Hoi An.',
        980000.00,
        1680000.00
    ),
    (
        'Nha Trang Bay Hotel',
        'Nha Trang',
        '72 Tran Phu, Loc Tho',
        'stay@nhatrangbay.test',
        '0901000104',
        'Comfortable coastal rooms close to the promenade, dining, and city attractions.',
        1240000.00,
        2050000.00
    ),
    (
        'Da Lat Pine Garden',
        'Da Lat',
        '18 Tran Hung Dao, Ward 10',
        'stay@dalatpine.test',
        '0901000105',
        'A calm highland property with garden views and easy access to central Da Lat.',
        1090000.00,
        1790000.00
    ),
    (
        'Saigon Opera Residence',
        'Ho Chi Minh City',
        '15 Dong Khoi, District 1',
        'stay@saigonopera.test',
        '0901000106',
        'An elegant central stay near the Opera House, riverfront, and major city landmarks.',
        1490000.00,
        2390000.00
    ),
    (
        'Saigon Riverside Suites',
        'Ho Chi Minh City',
        '88 Ton Duc Thang, District 1',
        'stay@saigonriverside.test',
        '0901000107',
        'Contemporary suites overlooking the Saigon River with convenient downtown access.',
        1580000.00,
        2590000.00
    ),
    (
        'Thu Duc Urban Stay',
        'Ho Chi Minh City',
        '42 Vo Nguyen Giap, Thu Duc City',
        'stay@thuducurban.test',
        '0901000108',
        'A practical modern hotel for business trips, families, and longer urban stays.',
        890000.00,
        1490000.00
    ),
    (
        'Hanoi West Lake House',
        'Ha Noi',
        '91 Quang An, Tay Ho',
        'stay@hanoiwestlake.test',
        '0901000109',
        'Relaxed lakeside accommodation with open views and access to the Tay Ho district.',
        1390000.00,
        2290000.00
    ),
    (
        'Hanoi Old Quarter Suites',
        'Ha Noi',
        '17 Ma May, Hoan Kiem',
        'stay@hanoioldquarter.test',
        '0901000110',
        'Characterful suites within walking distance of historic streets and local dining.',
        1270000.00,
        1980000.00
    ),
    (
        'Hanoi Garden Court',
        'Ha Noi',
        '55 Phan Dinh Phung, Ba Dinh',
        'stay@hanoigarden.test',
        '0901000111',
        'A peaceful garden-inspired residence close to the heritage quarter of Ba Dinh.',
        1210000.00,
        1920000.00
    ),
    (
        'Da Nang Ocean Terrace',
        'Da Nang',
        '210 Vo Nguyen Giap, Son Tra',
        'stay@danangocean.test',
        '0901000112',
        'Bright coastal accommodation across from the beach with generous family rooms.',
        1450000.00,
        2360000.00
    ),
    (
        'Da Nang Marble Boutique',
        'Da Nang',
        '64 Truong Sa, Ngu Hanh Son',
        'stay@danangmarble.test',
        '0901000113',
        'A boutique hotel positioned between the Marble Mountains and the coastline.',
        1160000.00,
        1870000.00
    ),
    (
        'Hoi An Riverside Courtyard',
        'Hoi An',
        '76 Nguyen Du, Cam Pho',
        'stay@hoianriverside.test',
        '0901000114',
        'Courtyard rooms beside the river with a calm atmosphere near the ancient town.',
        1050000.00,
        1740000.00
    ),
    (
        'Nha Trang Coral Residence',
        'Nha Trang',
        '19 Nguyen Thien Thuat, Loc Tho',
        'stay@nhatrangcoral.test',
        '0901000115',
        'A central coastal residence designed for beach holidays and city exploration.',
        1120000.00,
        1840000.00
    ),
    (
        'Da Lat Morning Mist Hotel',
        'Da Lat',
        '33 Ho Tung Mau, Ward 3',
        'stay@dalatmist.test',
        '0901000116',
        'Warm highland rooms overlooking the city slopes and morning mist.',
        1020000.00,
        1690000.00
    ),
    (
        'Phu Quoc Sunset Retreat',
        'Phu Quoc',
        '120 Tran Hung Dao, Duong To',
        'stay@phuquocsunset.test',
        '0901000117',
        'A tropical retreat near the western shoreline with sunset-facing accommodation.',
        1650000.00,
        2750000.00
    ),
    (
        'Phu Quoc Pearl Garden',
        'Phu Quoc',
        '28 Ganh Dau, Cua Duong',
        'stay@phuquocpearl.test',
        '0901000118',
        'Garden accommodation for guests seeking a quieter island experience.',
        1370000.00,
        2240000.00
    ),
    (
        'Vung Tau Seaside House',
        'Vung Tau',
        '96 Thuy Van, Ward 2',
        'stay@vungtauseaside.test',
        '0901000119',
        'Easygoing seaside rooms near Back Beach and the city promenade.',
        990000.00,
        1590000.00
    ),
    (
        'Can Tho Mekong Riverside',
        'Can Tho',
        '61 Hai Ba Trung, Ninh Kieu',
        'stay@canthomekong.test',
        '0901000120',
        'A comfortable riverside base for exploring Ninh Kieu and the Mekong Delta.',
        920000.00,
        1510000.00
    ),
    (
        'Hue Imperial Garden',
        'Hue',
        '40 Le Loi, Vinh Ninh',
        'stay@hueimperial.test',
        '0901000121',
        'A garden hotel inspired by Hue heritage and located near the Perfume River.',
        1080000.00,
        1770000.00
    ),
    (
        'Quy Nhon Coastal Haven',
        'Quy Nhon',
        '52 An Duong Vuong, Nguyen Van Cu',
        'stay@quynhoncoast.test',
        '0901000122',
        'A modern coastal stay for relaxed beach visits and family holidays.',
        1140000.00,
        1860000.00
    ),
    (
        'Ha Long Marina View',
        'Ha Long',
        '25 Hoang Quoc Viet, Bai Chay',
        'stay@halongmarina.test',
        '0901000123',
        'Marina-facing accommodation with convenient access to Ha Long Bay excursions.',
        1430000.00,
        2320000.00
    ),
    (
        'Mui Ne Sand Dune Resort',
        'Phan Thiet',
        '148 Nguyen Dinh Chieu, Ham Tien',
        'stay@muinedune.test',
        '0901000124',
        'A casual resort-style stay near the beach and the famous Mui Ne sand dunes.',
        1260000.00,
        2080000.00
    );

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
SELECT
    NEWID(),
    @OwnerUserAccountId,
    source.Name,
    source.City,
    source.AddressLine,
    source.ContactEmail,
    source.ContactPhone,
    source.Description,
    'Approved',
    'Published',
    0.1000,
    1,
    @Now
FROM @MarketplaceHotels source
WHERE NOT EXISTS
(
    SELECT 1
    FROM HotelProperties existing
    WHERE existing.Name = source.Name
);

UPDATE hotel
SET
    hotel.OwnerUserAccountId = @OwnerUserAccountId,
    hotel.City = source.City,
    hotel.AddressLine = source.AddressLine,
    hotel.ContactEmail = source.ContactEmail,
    hotel.ContactPhone = source.ContactPhone,
    hotel.Description = source.Description,
    hotel.ApprovalStatus = 'Approved',
    hotel.PublicationStatus = 'Published'
FROM HotelProperties hotel
INNER JOIN @MarketplaceHotels source ON source.Name = hotel.Name;

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
SELECT
    NEWID(),
    hotel.Id,
    roomType.Name,
    roomType.AdultCapacity,
    roomType.ChildCapacity,
    CASE
        WHEN roomType.Name = 'City Comfort Room' THEN source.StandardPrice
        ELSE source.SuitePrice
    END,
    roomType.Description,
    'Active'
FROM @MarketplaceHotels source
INNER JOIN HotelProperties hotel ON hotel.Name = source.Name
CROSS JOIN
(
    VALUES
        ('City Comfort Room', 2, 1, 'A comfortable room for couples and small families.'),
        ('Signature Family Suite', 4, 2, 'A spacious suite for families and longer stays.')
) roomType (Name, AdultCapacity, ChildCapacity, Description)
WHERE NOT EXISTS
(
    SELECT 1
    FROM RoomTypes existing
    WHERE existing.HotelId = hotel.Id
      AND existing.Name = roomType.Name
);

INSERT INTO PhysicalRooms (Id, HotelId, RoomTypeId, RoomNumber, Status)
SELECT
    NEWID(),
    hotel.Id,
    roomType.Id,
    room.RoomNumber,
    'Available'
FROM @MarketplaceHotels source
INNER JOIN HotelProperties hotel ON hotel.Name = source.Name
INNER JOIN RoomTypes roomType
    ON roomType.HotelId = hotel.Id
   AND roomType.Name = 'City Comfort Room'
CROSS JOIN
(
    VALUES ('101'), ('102'), ('103'), ('104')
) room (RoomNumber)
WHERE NOT EXISTS
(
    SELECT 1
    FROM PhysicalRooms existing
    WHERE existing.HotelId = hotel.Id
      AND existing.RoomNumber = room.RoomNumber
);

INSERT INTO PhysicalRooms (Id, HotelId, RoomTypeId, RoomNumber, Status)
SELECT
    NEWID(),
    hotel.Id,
    roomType.Id,
    room.RoomNumber,
    'Available'
FROM @MarketplaceHotels source
INNER JOIN HotelProperties hotel ON hotel.Name = source.Name
INNER JOIN RoomTypes roomType
    ON roomType.HotelId = hotel.Id
   AND roomType.Name = 'Signature Family Suite'
CROSS JOIN
(
    VALUES ('201'), ('202'), ('203')
) room (RoomNumber)
WHERE NOT EXISTS
(
    SELECT 1
    FROM PhysicalRooms existing
    WHERE existing.HotelId = hotel.Id
      AND existing.RoomNumber = room.RoomNumber
);

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

SELECT
    COUNT(*) AS PublishedHotelCount,
    SUM(CASE WHEN marketplace.Name IS NOT NULL THEN 1 ELSE 0 END) AS MarketplaceSeedHotelCount
FROM HotelProperties hotel
LEFT JOIN @MarketplaceHotels marketplace ON marketplace.Name = hotel.Name
WHERE hotel.ApprovalStatus = 'Approved'
  AND hotel.PublicationStatus = 'Published';
"@

$temporarySqlFile = [System.IO.Path]::GetTempFileName()
try {
    $utf8WithoutByteOrderMark = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($temporarySqlFile, $sql, $utf8WithoutByteOrderMark)

    docker cp $temporarySqlFile "${ContainerName}:/tmp/seed-local-test-accounts.sql"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy the demonstration seed into SQL Server container '$ContainerName'."
    }

    docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd `
        -S localhost `
        -U sa `
        -P $saPassword `
        -d $database `
        -C `
        -b `
        -i /tmp/seed-local-test-accounts.sql

    if ($LASTEXITCODE -ne 0) {
        throw "SQL Server rejected the demonstration seed."
    }
}
finally {
    Remove-Item -LiteralPath $temporarySqlFile -Force -ErrorAction SilentlyContinue
}
