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
| SCR-002 Login | `login_screen.dart` | Email, password, login, register navigation, and MVP recovery explanation |
| SCR-003 Profile | `account_settings_screen.dart` | Profile data, role summary, hotel scope, profile update, password change, and logout |
| SCR-004 to SCR-006 Marketplace | `marketplace_screen.dart`, `hotel_detail_screen.dart` | Search and result are separate navigation states; detail contains gallery, address, amenities, policy, availability, and room selection |
| SCR-007 to SCR-013 Customer booking | Booking and Customer workspace screens | Guest details, price summary, demo payment hold/result, trip list/detail, cancellation quote, cancellation, and refund state |
| SCR-014 Owner/Manager dashboard | `manager_overview_tab.dart` | Hotel selector, hotel summary metrics, operational metrics, management menu, task previews, and hotel identity |
| SCR-015 and SCR-016 Hotel profile | Owner onboarding, property, and content widgets | Registration, profile, publication state, gallery, amenities, cancellation policy, and save actions |
| SCR-017 to SCR-019 Inventory | Property and availability tabs | Room type CRUD, physical room CRUD, lifecycle-safe status, room filters, date range, availability action, and reason |
| SCR-028 and SCR-029 Staff | `staff_management_tab.dart` | Staff list, search, create/attach, role assignment, access status, and Hotel Manager authority limits |
| SCR-020 to SCR-027 Front Desk | `front_desk_tab.dart` | Dashboard, arrivals, departures, in-house, no-show candidates, booking detail, assignment, check-in, checkout, collection, history, rooms, and walk-in |
| SCR-030 to SCR-032 Housekeeping | `housekeeping_tab.dart` | Waiting, cleaning, inspection, completed metrics, status filter, task cards, claim/progress, inspection, and issue reporting path |
| SCR-033 and SCR-034 Maintenance | `maintenance_tab.dart` | Status/severity/room filters, issue creation, request details, assignee ownership, repair progress, resolution note, and room release |
| SCR-035 Room status | Availability, Front Desk, and operations room views | Live status counts, room list, status filter, room type context, and operational lifecycle |
| SCR-036 Admin dashboard | Platform Admin Analytics | Dedicated dashboard state with refresh, hotel filter, reporting scope, KPI cards, revenue chart, and hotel finance table |
| SCR-037 Hotel approval | Platform Admin Hotels | Pending list, review details, approve, reject reason, and refresh |
| SCR-038 Commission | Platform Admin Commission | Hotel search/selection, current rate, validated new rate, and save |
| SCR-039 Reconciliation | Platform Admin Reconciliation | Transaction list, amount/status, mark reconciled, and exception reason |
| SCR-040 Refund | Platform Admin Refunds | Booking/payment context, approved amount, note, approve/reject/process actions |
| SCR-041 Settlement | Platform Admin Settlements | Type, expected/actual values, evidence reference/date, exception reason, and status action |

## Approved Scope Differences

- The SRS payment mock-ups mention payOS. The approved project scope uses a
  secure, idempotent `DEMO` payment provider and never contacts a bank.
- Search criteria are edited without triggering network reload. Results load
  only after the Search action, matching SCR-004 to SCR-005.
- Detail and action workflows may use full-height modal sheets where the result
  preserves the same screen title, fields, actions, and Back behavior.
- Platform reporting currently uses all recorded MVP transactions because the
  finance summary API does not expose a date-range parameter. The UI states this
  limitation instead of presenting a fake date filter.

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
