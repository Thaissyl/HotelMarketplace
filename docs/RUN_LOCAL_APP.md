# Run The Local App

This guide starts the local backend in VS Code and runs the Flutter app from Android Studio.

## 1. Start Docker Desktop

Open Docker Desktop and wait until it is running.

## 2. Start The Backend API

Open a PowerShell terminal in VS Code at the repository root:

```powershell
cd D:\HotelMarketplace
```

Start the backend:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1
```

The script starts SQL Server, waits for its health check, and applies all pending
Entity Framework Core migrations before starting the API. This prevents an old
persistent local database from running against a newer application model.

The API should be available at:

```text
http://localhost:5080
```

The startup script binds Kestrel to all local interfaces so Android emulators
can reach the same API through `http://10.0.2.2:5080`. It remains available from
Windows at `http://localhost:5080`.

Swagger:

```text
http://localhost:5080/swagger
```

Health check:

```powershell
Invoke-RestMethod http://localhost:5080/health
```

## 3. Stop Or Restart The Backend

If port `5080` is already in use, stop the current backend:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-local-backend.ps1
```

Then start it again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1
```

To force-restart from one command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1 -ForceRestart
```

To keep a diagnostic log while reproducing an API problem:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1 -ForceRestart -LogFile .\.local\backend.log
```

## 4. Run The Flutter App From Android Studio

Open:

```text
D:\HotelMarketplace\mobile
```

Select an Android emulator, for example `Pixel_7`.

Do not select the `Windows` target. This project is intended to run as a mobile app.

Add this Dart define in the Android Studio run configuration:

```text
--dart-define API_BASE_URL=http://10.0.2.2:5080
```

Then click Run.

If keyboard input does not work in the emulator, run this once from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\fix-android-emulator-input.ps1
```

Then restart or cold boot the emulator. This keeps host keyboard input enabled for the existing AVDs and also allows the emulator soft keyboard to appear while a hardware keyboard is connected.

You can also run from PowerShell:

```powershell
cd D:\HotelMarketplace\mobile
flutter run -d emulator-5554 --dart-define API_BASE_URL=http://10.0.2.2:5080
```

For smoother UI testing, use profile mode instead of debug mode:

```powershell
cd D:\HotelMarketplace\mobile
flutter run --profile -d emulator-5554 --dart-define API_BASE_URL=http://10.0.2.2:5080
```

You can also install a profile APK:

```powershell
cd D:\HotelMarketplace\mobile
flutter build apk --profile --dart-define API_BASE_URL=http://10.0.2.2:5080
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r .\build\app\outputs\flutter-apk\app-profile.apk
```

## 5. Test Accounts

Seed or reset local test accounts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\seed-local-test-accounts.ps1
```

The seed script also prepares demo hotel data for role testing:

- A published demo hotel with readable name, city, address, room types, and physical rooms.
- One confirmed arrival for the Receptionist Arrivals tab.
- One checked-in stay for the Receptionist Checked In and Departures tabs.
- One open housekeeping task assigned to the housekeeping staff account.
- One open maintenance request assigned to the maintenance staff account.

All seeded test accounts use this password:

```text
Test@123
```

Customer:

```text
customer@test.com
```

Property owner:

```text
owner@test.com
```

Hotel manager:

```text
manager@test.com
```

Receptionist:

```text
reception@test.com
```

Housekeeping staff:

```text
housekeeping@test.com
```

Maintenance staff:

```text
maintenance@test.com
```

Platform administrator:

```text
admin@test.com
```

## 6. Common Emulator Fixes

If Android Studio says the Windows desktop target is selected, change the device dropdown to an Android emulator.

If the emulator says the same AVD is already running:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" emu kill
```

Then start the emulator again from Android Studio.

If the emulator UI freezes with `System UI isn't responding`, use Android Studio Device Manager:

```text
Cold Boot Now
```

If it still freezes:

```text
Wipe Data
```

If text fields focus but the on-screen keyboard does not appear, reset Gboard and force the soft keyboard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\fix-android-emulator-input.ps1 -ResetGboard
```

If the UI feels slow in Android Studio, run the app in profile mode. Flutter debug mode adds runtime checks and service protocol overhead that can make emulator interactions feel slower than a real build.

## 7. Reset Demo Hotel Names

After running smoke tests or integration tests, reset local demo hotel names:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\reset-local-demo-data.ps1
```

## 8. Role Flow Demo Checklist

Use this order when demonstrating the app so every role has useful data on screen.

### Customer

1. Sign in with `customer@test.com` and `Test@123`.
2. Search hotels from the Search tab.
3. Open a hotel detail page.
4. Adjust check-in/check-out dates, guests, and rooms.
5. Select a room type and create a booking.
6. On the reservation hold screen, press `Confirm demo payment`. This records a
   local `DEMO` transaction and does not charge real money.
7. Open `Trips` to review the booking details.

### Receptionist

1. Sign in with `reception@test.com` and `Test@123`.
2. Confirm that the workspace title is `Front Desk`.
3. Confirm the selected working hotel shows a readable hotel name, not only an ID.
4. Open `Arrivals` to see confirmed bookings created by the Customer flow.
5. Tap a booking card to view guest, stay, room, and payment details.
6. Press `Assign room & check in`, choose an available physical room, and complete check-in.
7. Open `Checked In` or `Departures`, then complete checkout.
8. Use `Walk-in` only for direct guests. Select a readable room type from the dropdown, choose an available physical room, enter guest details, and create the stay.

### Housekeeping

1. Sign in with `housekeeping@test.com` and `Test@123`.
2. Open the Housekeeping workspace.
3. Review Waiting, Cleaning, and Done counters.
4. Claim an open cleaning task.
5. Mark the task clean. The room should return to available inventory after completion.

### Maintenance

1. Sign in with `maintenance@test.com` and `Test@123`.
2. Open the Maintenance workspace.
3. Search/select a room by room number.
4. Enter an issue description, choose severity, and create the request.
5. Start repair, then resolve it. The room should be released back after resolution.

### Hotel Manager

1. Sign in with `manager@test.com` and `Test@123`.
2. Review the manager overview metrics.
3. Assign open cleaning tasks to housekeeping staff when available.
4. Assign open maintenance requests to maintenance staff when available.
5. Use Front Desk, Rooms, and Maintenance tabs to supervise hotel operations.
6. Confirm the selected hotel is shown by name and address.

### Property Owner

1. Sign in with `owner@test.com` and `Test@123`.
2. Review hotel operations and staff management.
3. Create a staff account only when needed for demo.
4. Open Property to edit hotel profile, create room types, and create physical rooms.

### Platform Administrator

1. Sign in with `admin@test.com` and `Test@123`.
2. Review Analytics, Users, Hotels, Settlements, and Refunds.
3. Use Users to search, filter, ban/unban, and inspect activity.
4. Use Hotels to approve or reject pending hotel submissions.
5. Use Settlements and Refunds to demonstrate finance operations with available demo data.

## 9. Known MVP Limits Before Demo

- Saved hotels and notifications are local app state.
- Customer trips are connected to backend booking history, but the MVP booking table does not persist the original guest count separately.
- Receptionist Arrivals should have seeded data after running `seed-local-test-accounts.ps1`. You can also create one from the Customer flow and press `Confirm demo payment`.
- Flutter debug mode can feel slower on an emulator. Use profile mode for smoother demo runs.
