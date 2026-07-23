# Seed Local Demonstration Data

This guide creates the same reproducible demonstration dataset on another
development machine. The seed is idempotent and can be run repeatedly without
duplicating the named hotels, room types, physical rooms, test accounts, or
core operational records.

## Prerequisites

- Docker Desktop is running.
- The repository contains a valid local `.env` file.
- SQL Server migrations have been applied.
- The `hotel-marketplace-sqlserver` container is healthy.

The normal backend startup script prepares these requirements:

```powershell
cd D:\HotelMarketplace
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1
```

Stop the API with `Ctrl+C` only if the terminal needs to be reused. SQL Server
must remain running.

## Run The Seed

```powershell
cd D:\HotelMarketplace
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\seed-local-test-accounts.ps1
```

The script reads the SQL Server database name and SA password from the ignored
local `.env` file. Credentials are not embedded in the script.

## Seeded Marketplace Data

The resulting database contains at least:

- One primary operations hotel with arrivals, an in-house stay, room status
  variety, a housekeeping task, and a maintenance request.
- Twenty-four additional published marketplace hotels across major Vietnamese
  destinations.
- Two active room types for each additional hotel.
- Seven available physical rooms for each additional hotel.
- Enough records to demonstrate search, city filtering, hotel details, room
  availability, and pagination.

The primary operations hotel remains the only hotel assigned to the seeded
Manager, Receptionist, Housekeeping, and Maintenance accounts. This preserves
hotel-scoped authorization while the additional hotels enrich Customer and
Platform Administrator screens.

## Test Accounts

All accounts use password `Test@123`.

| Role | Email |
| --- | --- |
| Customer | `customer@test.com` |
| Property Owner | `owner@test.com` |
| Hotel Manager | `manager@test.com` |
| Receptionist | `reception@test.com` |
| Housekeeping Staff | `housekeeping@test.com` |
| Maintenance Staff | `maintenance@test.com` |
| Platform Administrator | `admin@test.com` |

## Reset Account Passwords

Running the script again resets every listed account to `Test@123`, restores an
active account status, repairs required role assignments, and recreates missing
demonstration records.

## Custom Password

To use a different shared password:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\seed-local-test-accounts.ps1 `
  -Password "YourStrongDemoPassword"
```

## Verify In The Application

1. Start the backend and open `http://localhost:5080/swagger`.
2. Run the Flutter app with `API_BASE_URL=http://10.0.2.2:5080`.
3. Sign in as `customer@test.com` and open the Search workspace.
4. Search without a city to view the full marketplace.
5. Filter by `Ha Noi`, `Da Nang`, `Ho Chi Minh City`, `Hoi An`, or another seeded
   destination.
6. Sign in as `admin@test.com` to verify the global hotel list.
7. Sign in as `reception@test.com` to verify that operational access remains
   limited to the primary hotel.
