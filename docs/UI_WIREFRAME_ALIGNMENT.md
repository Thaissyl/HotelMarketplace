# SRS Wireframe Alignment

## Source

The canonical UI reference is:

- `docs/source/software-requirement-document.md`
- Figures 3-17 through 3-57
- Screen definitions `SCR-001` through `SCR-041`

The source images are the canonical screen reference. The Flutter
implementation follows their screen boundaries, information hierarchy, field
order, action labels, and role-specific navigation while retaining responsive
layout and accessible controls.

## Alignment Principles

- Match screen titles, required fields, information hierarchy, actions, and
  role boundaries.
- Keep list, detail, and action screens as distinct navigation states. Do not
  combine separate SRS screens into a permanently visible tab workspace.
- Do not copy Android status/navigation chrome embedded in the mock-up images.
- Do not add nonfunctional buttons to imitate a mock-up.
- Approved product decisions override stale mock-up details. In particular,
  online payment remains the explicit demo flow and marketplace quantity changes
  remain automatically applied.

## Screen Mapping

| SRS screens | Flutter implementation | Alignment |
| --- | --- | --- |
| SCR-001 Register | `register_screen.dart` | Customer/Owner selector, name, email, phone, password, confirm password, terms, validation, and submit |
| SCR-002 Login | `login_screen.dart` | Email-or-phone login, password, submit, and register navigation; Forgot Password is intentionally omitted |
| SCR-003 Profile | `account_settings_screen.dart` | Profile data, role summary, hotel scope, profile update, password change, and logout |
| SCR-004 to SCR-006 Marketplace | `marketplace_screen.dart`, `hotel_detail_screen.dart` | Search and result are separate navigation states; detail contains gallery, address, amenities, policy, availability, and room selection |
| SCR-007 to SCR-013 Customer booking | Booking and Customer workspace screens | Guest details, price summary, demo payment hold/result, trip list/detail, cancellation quote, cancellation, and refund state |
| SCR-014 Owner/Manager dashboard | `manager_overview_tab.dart` | Hotel selector, summary cards, operational metrics, and management navigation |
| SCR-015 and SCR-016 Hotel profile | `owner_hotel_onboarding.dart`, `owner_property_tab.dart`, `owner_hotel_content_card.dart` | Registration, profile, publication state, URL gallery, amenities, cancellation policy, and save actions |
| SCR-017 to SCR-019 Inventory | `owner_room_type_management_screen.dart`, `owner_physical_room_management_screen.dart`, `availability_calendar_tab.dart` | Room type and physical-room management, room filters, date range, availability action, and reason |
| SCR-020 and SCR-021 Hotel bookings | `hotel_booking_list_screen.dart`, `hotel_booking_detail_screen.dart` | Hotel booking filters, list/detail navigation, room assignment, check-in, checkout, payment collection, and no-show actions |
| SCR-022 to SCR-027 Front Desk | `front_desk_tab.dart`, `arrival_departure_screen.dart`, `room_assignment_screen.dart`, `check_in_screen.dart`, `check_out_screen.dart`, `walk_in_screen.dart` | Dashboard, arrivals, departures, in-house, no-show candidates, assignment, identity verification, checkout, collection, and walk-in |
| SCR-028 and SCR-029 Staff | `staff_management_tab.dart`, `staff_entry_screen.dart`, `staff_role_assignment_screen.dart` | Staff list, create/attach, activation state, hotel scope, role assignment, and permission summary |
| SCR-030 to SCR-032 Housekeeping | `housekeeping_tab.dart`, `housekeeping_task_list_screen.dart`, `housekeeping_task_detail_screen.dart` | Workload summary, filters, task detail, lifecycle actions, inspection, checklist gate, and issue reporting |
| SCR-033 and SCR-034 Maintenance | `maintenance_tab.dart`, `maintenance_report_issue_screen.dart`, `maintenance_request_detail_screen.dart` | Status/severity/room filters, issue creation, detail, assignee, repair progress, resolution note, and room release |
| SCR-035 Room status | `room_status_board.dart` | Live status groups, room-type context, room detail, and operational status legend |
| SCR-036 Admin dashboard | `admin_overview_tab.dart` | Reporting filters, KPI cards, finance chart, hotel table, refresh, and pagination |
| SCR-037 Hotel approval | `hotel_approval_tab.dart` | Pending list, review details, approve, rejection reason, and refresh |
| SCR-038 Commission | `commission_management_tab.dart` | Hotel selection, current rate, validated new rate, effective-state disclosure, and save |
| SCR-039 Reconciliation | `payment_reconciliation_tab.dart` | Transaction list/detail, provider reference, amount/status, reconciled action, and exception reason |
| SCR-040 Refund | `refund_management_tab.dart` | Booking/refund context, approved amount, approve/reject/process actions, and state locking |
| SCR-041 Settlement | `settlement_management_tab.dart` | Eligible records, type, expected/actual values, evidence reference/date, exception note, and settlement action |

## Approved Scope Differences

- The SRS payment mock-ups mention payOS. The approved project scope uses a
  secure, idempotent `DEMO` payment provider and never contacts a bank.
- The Login mock-up contains Forgot Password, but the approved implementation
  omits it.
- Walk-in bookings use the approved shared anonymous customer and cash
  collection flow. Unsupported card, mobile-money, and bank-transfer controls
  are not presented as working actions.
- Search criteria are edited without triggering network reload. Results load
  only after the Search action, matching SCR-004 to SCR-005.
- Detail and action workflows may use full-height modal sheets where the result
  preserves the same screen title, fields, actions, and Back behavior.
- Platform reporting currently uses all recorded MVP transactions because the
  finance summary API does not expose a date-range parameter. The UI states this
  limitation instead of presenting a fake date filter.
- Hotel-scoped work screens show the selected hotel name under the screen title
  so staff never operate against an unexplained identifier.

## Contract-Limited Fields

The following wireframe fields are represented honestly but cannot be persisted
until their backend contracts exist:

- Binary hotel image upload. The current hotel-content API accepts validated
  HTTP or HTTPS image URLs.
- Housekeeping priority, due date, checklist items, and task notes. The
  checklist is a local completion gate and is not presented as stored data.
- Commission effective date and admin note, refund admin note, and platform
  dashboard date-range filtering.
- Server-side pagination for operational and platform-administration lists.
  Current MVP lists paginate the fetched result set on the client.

## Verification

Required checks after wireframe changes:

```powershell
cd D:\HotelMarketplace\mobile
dart format lib test
flutter analyze
flutter test
flutter build apk --profile --dart-define API_BASE_URL=http://10.0.2.2:5080
```

The final visual check should cover Customer, Owner, Hotel Manager,
Receptionist, Housekeeping, Maintenance, and Platform Administrator workspaces
on the existing Pixel 7 emulator.

### Latest Verification

The July 23, 2026 alignment pass completed the following checks:

- All 41 SRS screens are mapped to concrete Flutter screens or role-specific
  navigation states.
- `flutter analyze` completed with no findings.
- All 15 Flutter tests passed.
- All 68 .NET tests passed: 25 Domain, 2 Application, and 41 API integration
  tests.
- A profile APK built successfully and was exercised on the existing Pixel 7
  emulator.
- Customer search, role-aware authentication, Front Desk in-house/checkout,
  Housekeeping status updates, Maintenance create/resolve/release, and all
  Platform Administrator sections were verified against the running API.
- Local demonstration data was normalized and reseeded so technical test names
  such as `Bookable Hotel <identifier>` are not shown to users.
