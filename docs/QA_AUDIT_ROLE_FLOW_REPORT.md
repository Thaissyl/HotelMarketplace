# QA Audit And Role Flow Review

Date: 2026-07-18

## Executive Summary

The backend and mobile codebase is in a strong MVP state. The core backend build is clean, the Flutter app analyzes and builds successfully, and the integration test suite passes when Docker Desktop is running.

The system is suitable for a supervised demo after the local environment is started correctly. It is not yet production-ready because several mobile workflows are still MVP-level, live payment is intentionally bypassed for the MVP, and some secondary features such as saved hotels and notifications are still local-only.

## Verification Results

| Area | Result | Notes |
| --- | --- | --- |
| Backend build | Passed | `dotnet build .\backend\src\Presentation.Api\Presentation.Api.csproj --no-restore` completed with 0 warnings and 0 errors. |
| API integration tests | Passed | `dotnet test .\backend\tests\Api.IntegrationTests\Api.IntegrationTests.csproj --no-restore` passed 8/8 after Docker Desktop was started. |
| Application unit tests | No tests discovered | Project builds, but there are no discoverable tests yet. |
| Domain unit tests | No tests discovered | Project builds, but there are no discoverable tests yet. |
| Flutter analyze | Passed | `flutter analyze` completed with no issues. |
| Flutter debug APK build | Passed | `flutter build apk --debug --dart-define API_BASE_URL=http://10.0.2.2:5080` built successfully. |
| Flutter widget tests | Passed | `flutter test` passed the existing widget test. |
| Pixel_7 emulator launch | Passed | AVD `Pixel_7` booted and the app opened. |
| Login UI render | Passed | Login screen rendered correctly on Pixel_7. Screenshot: `mobile/qa-after-wait.png`. |
| Emulator keyboard input | Passed after correct focus | Email field exposes an Android `EditText`; keyboard appeared after tapping the correct field bounds. Screenshot: `mobile/qa-keyboard-focused.png`. |

## Environment Findings

Docker Desktop was initially not running. This caused Testcontainers and SQL Server-dependent checks to fail. After Docker Desktop started, the SQL Server container became healthy and the integration test suite passed.

The API process could not be started in the background by this audit session because process spawning commands such as `Start-Process powershell`, `Start-Process dotnet`, and `cmd start /B` were blocked by shell policy. To verify Swagger and live API manually, run the normal foreground command from a terminal:

```powershell
cd D:\HotelMarketplace
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-backend.ps1 -ForceRestart
```

Then open:

```text
http://localhost:5080/swagger
```

## Role Coverage Review

## Current Role Flow Readiness

| Role | Flow Readiness | Main Result |
| --- | --- | --- |
| Customer | Demo-ready | The user can register/login, search hotels, view hotel details, create a booking, press the MVP Payment button, review trips, and update profile/password. |
| Receptionist | Demo-ready | The user lands in Front Desk, sees readable hotel context, can process arrivals, check-in, checkout, and create walk-in bookings. |
| Housekeeping Staff | Demo-ready | The user can see assigned/open room-cleaning tasks, claim work, and mark rooms clean. |
| Maintenance Staff | Demo-ready | The user can create room issue requests, start repair, and resolve requests. |
| Hotel Manager | Demo-ready for supervision | The user can supervise hotel metrics, assign housekeeping and maintenance work, and access operational tabs. Inventory configuration remains owner-oriented. |
| Property Owner | Demo-ready for setup | The user can manage property profile, create room types, create physical rooms, and create staff accounts. Edit/deactivate workflows are still stronger in backend/Swagger than in mobile. |
| Platform Administrator | Partially demo-ready | Analytics and user management are usable. Hotel approval, refunds, and settlements may be empty unless dedicated demo records are seeded or created first. |

## Local Demo Data Check

The local SQL Server database currently has enough data for hotel operations:

- Seeded role accounts: 7.
- Published hotels: available.
- Confirmed arrivals: available.
- Checked-in bookings: available.
- Open housekeeping tasks: available.
- Open maintenance requests: available.

The local database currently does not guarantee visible records for these platform-admin tabs:

- Pending hotel approvals.
- Pending refund requests.
- Pending settlements.

Those tabs are functionally implemented, but they may look empty in a product demo without additional seed data.

### Customer

Implemented:

- Login/register flow with form validation.
- Marketplace search with location, dates, guests, rooms, sorting, filters, and pagination.
- Hotel details page with back navigation, hotel address, stay date editing, guests/rooms editing, and room availability.
- Booking confirmation and pending payment hold.
- Simulated payment completion through the Payment button.
- Saved hotels, trips, notifications, and settings tabs.
- Trips tab is connected to the backend booking history endpoint and keeps a local fallback for bookings created in the current session.
- Trip detail bottom sheet with booking amount, dates, guests, rooms, booking code, and payment deadline.
- Profile update and password change are connected to backend account APIs.

Needs improvement:

- Saved hotels and notifications are local state only. They are not persisted per user.
- Booking history currently exposes the stored booking data available in the MVP schema. Guest count is still limited because the booking table does not persist the original guest count separately.

### Property Owner

Implemented:

- Operations dashboard route for hotel-side roles.
- Hotel selector with hotel name, city, approval status, publication status, address/details sheet.
- Staff management tab for creating hotel staff accounts and assigning roles.
- Property setup tab for editing hotel profile, creating room types, and creating physical rooms.
- Access to manager overview, front desk, rooms/housekeeping, maintenance, and staff management.

Needs improvement:

- Staff management supports create/list but not edit, deactivate, reset password, or transfer staff between hotels.
- Owner inventory management supports create/list in mobile, but edit/deactivate controls are still stronger in Swagger/backend than in mobile.

### Hotel Manager

Implemented:

- Manager dashboard with selected hotel name instead of raw hotel ID.
- Operational metrics for housekeeping and maintenance.
- Cleaning assignment list for open housekeeping tasks.
- Maintenance assignment actions for assigning open repair requests to technicians.
- Front desk, housekeeping, and maintenance tabs.
- Workflow explanation card describing where to handle each operation.

Needs improvement:

- Manager cannot edit room inventory or room type configuration from mobile yet.
- Metrics are useful but still basic; there is no calendar, occupancy chart, or arrivals/departures timeline.

### Receptionist

Implemented:

- Receptionist is routed to the Front Desk workspace, not the customer marketplace.
- Hotel selector shows hotel name/details.
- Front desk tabs exist for Arrivals, Checked In, Departures, History, and Walk-in.
- Booking cards support details, room assignment, check-in, checkout, invoice/payment summary, and available-room selection.

Needs improvement:

- If there are no confirmed bookings, the screen can still look light on data. The app now shows a clearer empty state with a Walk-in CTA, but an online check-in demo still needs a confirmed Customer booking first.
- Walk-in booking now uses a room type selector with readable room type names, capacity, and price instead of asking staff to paste a GUID.
- Front desk needs stronger calendar context: today, tomorrow, late arrivals, and overdue checkout buckets.
- History should show searchable check-in/check-out logs, not just completed booking cards.

### Housekeeping Staff

Implemented:

- Housekeeping board with status filters.
- Summary cards for waiting, cleaning, and completed tasks.
- Task cards show room number, room status, task type, assignment state, and booking reference.
- Staff can claim a task and mark the room clean.

Needs improvement:

- Completed task history is visible only through filters and should be paginated/searchable for larger hotels.
- Task details should include priority, notes, estimated cleaning time, and last checkout time.

### Maintenance Staff

Implemented:

- Maintenance control screen with room search, issue creation, severity, target room status, status filters, pagination, and request cards.
- Staff can start repair and resolve repair.
- Creating a maintenance request removes the room from sellable inventory through backend rules.

Needs improvement:

- Maintenance request creation should support photos, issue category, reporter name, and expected downtime.
- Room picker shows room number/status, but should also show room type/floor to help staff identify rooms faster.
- Resolved requests should show resolution notes and repair cost when relevant.

### Platform Administrator

Implemented:

- Admin-only route `/platform-admin`.
- Analytics tab with finance KPIs and hotel finance list.
- Users tab with search, role filter, status filter, pagination, ban/unban, and activity history.
- Hotel approval UI with approve/reject flow.
- Settlements and refunds tabs with status updates.
- Sign-out is available.

Needs improvement:

- User activity is available, but it should be enriched with more audit events from backend workflows.
- Settlements need clearer business labels for new users, such as "money owed to hotel" and "platform fee".
- Settlement/refund workflows and hotel approval need more realistic demo data.
- Admin does not yet have full edit capability for user profile fields, hotel metadata, or role assignment.

## Security And Authorization Review

Backend controllers use role-based authorization and hotel-scoped policies for hotel operations. Platform admin APIs are restricted to `PlatformAdministrator`. Public hotel search endpoints are intentionally anonymous.

Key covered integration tests include:

- Registration/login validation.
- Hotel-scoped forbidden access.
- Forged `X-Hotel-Id` protection.
- Booking lifecycle.
- Concurrent booking prevention.
- Concurrent check-in prevention.
- Expired booking check-in failure.

Remaining security improvements:

- Add more tests for each mobile-exposed role route, especially owner staff creation, maintenance status transitions, and admin ban/unban.
- Add backend APIs for profile update and password change before enabling real account settings.
- Add rate limiting for login/register endpoints before production.
- Add refresh-token rotation if long-lived mobile sessions are required.

## UX And Demo Readiness Risks

Important risks before showing the project:

- Backend must be started manually with Docker Desktop running before launching the mobile app.
- Flutter debug mode can feel slower on the emulator. Use profile mode for demo:

```powershell
cd D:\HotelMarketplace\mobile
flutter run --profile -d emulator-5554 --dart-define API_BASE_URL=http://10.0.2.2:5080
```

- If Gboard or emulator input fails, cold boot Pixel_7 and run:

```powershell
cd D:\HotelMarketplace
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\fix-android-emulator-input.ps1 -ResetGboard
```

- The seed script now creates demo arrivals, an in-house booking, a cleaning task, and a maintenance request. If the local database has been heavily modified, run `scripts\seed-local-test-accounts.ps1` again.

## Recommended Fix Backlog

High priority before demo:

1. Add persisted saved hotels and notifications per user.
2. Add edit/deactivate controls for owner room types, physical rooms, and staff accounts.
3. Add more realistic settlement and refund demo data.
4. Add more role-specific API integration tests for owner staff creation and admin user controls.
5. Add guest count persistence to booking history if required for final grading.

Medium priority:

1. Add richer maintenance fields: category, photo, downtime, resolution note.
2. Improve admin settlement labels and demo data.
3. Add pagination/search to housekeeping completed history.
4. Add chart visualization to manager/admin dashboards.
5. Add owner edit screens for existing inventory records.

Low priority:

1. Add chart visualization to manager/admin dashboards.
2. Add notification persistence.
3. Add favorite hotel persistence.
4. Add localization if the final demo needs Vietnamese UI.

## Final Readiness Statement

The system is MVP-demo ready after Docker Desktop, SQL Server, backend API, and the Pixel_7 emulator are started correctly. The core backend quality is strong based on the passing integration tests. The mobile app is build-clean and usable, but several role workflows are still simplified and should be improved if the project is judged on product completeness rather than technical architecture.
