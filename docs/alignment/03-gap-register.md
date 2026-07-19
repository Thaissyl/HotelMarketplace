# Verified Gap Register

All entries below were checked against the canonical requirements, approved
scope decisions, and current implementation. Priority reflects integrity and
dependency order, not only user-interface visibility.

| Gap | Requirement | Verified current behavior | Required correction | Severity | Phase |
| --- | --- | --- | --- | --- | --- |
| GAP-001 | BR-AUTH-002, NFR-SEC-002 | Platform Administrator bypasses hotel access checks and is listed on Front Desk, Housekeeping, and Maintenance mutation endpoints | Remove platform-role bypass; require hotel-role assignment for operational access; retain separate platform overview APIs | Critical | P0 |
| GAP-002 | BR-AUTH-002, UC-027 | JWT contains independent role and hotel lists | Issue and validate hotel-role assignment tuples; keep platform roles separate | Critical | P0 |
| GAP-003 | UC-005, UC-031, NFR-REL-001 | Online booking locks room-type quantity while Walk-in locks selected physical rooms only | Introduce one inventory coordinator and compatible lock key for all commitment channels and date ranges | Critical | P0 |
| GAP-004 | Approved Walk-in decision | Walk-in uses the staff actor as Customer, ignores `Anonymous Walk-in Customer`, and always checks in immediately | Seed protected shared account; retain guest data per booking; choose Confirmed or CheckedIn from assignment; record cash collection | Critical | P0 |
| GAP-005 | UC-006 approved demo scope | Demo payment is mixed with unused payOS production paths and lacks broad audit/test coverage | Make demo mode explicit in configuration, API contract, UI language, transaction provider, audit, and tests; remove or isolate unused real-gateway paths | High | P0 |
| GAP-006 | UC-007, BR-REF-001/003 | No Customer cancellation endpoint, policy evaluation, booking transition, inventory release, or refund initiation | Implement transactional cancellation with policy snapshot/result, optional RefundRecord, audit, notification, API, mobile, and tests | High | P1 |
| GAP-007 | UC-017, BR-STAY-004 | No no-show operation | Implement eligibility window, booking transition, assignment release, financial trace, room lifecycle, audit, notification, API, and mobile action | High | P1 |
| GAP-008 | UC-013, BR-AVAIL-001/002 | RoomAvailability entity exists without management use case or marketplace integration | Add date-range block/open APIs, conflict validation, projected reads, mobile calendar, and concurrency tests | High | P1 |
| GAP-009 | UC-005, BR-BOOK-005 | Customer cannot select Pay at Property | Add payment mode to booking request and UI; confirm immediately; create appropriate commission receivable and collection expectation | High | P1 |
| GAP-010 | UC-020/022, BR-FIN-002/007 | Settlement permits unreconciled Platform Collect payments and does not account for refund outcomes correctly | Enforce type-specific eligibility, reconciliation, refund deduction/blocking, exception state, and immutable item evidence | High | P1 |
| GAP-011 | UC-021 | Refund records can only be manually seeded in normal tested behavior | Create refund from eligible cancellation and expose Customer refund status | High | P1 |
| GAP-012 | UC-030, BR-PAY-004/007 | PaymentCollectionRecord uses online PaymentStatus and lacks method, reference, partial/void/exception lifecycle | Introduce collection-specific status and correction/audit fields; expose independent collection operation | High | P1 |
| GAP-013 | UC-016, BR-STAY-002/003 | Checkout can issue an invoice without complete payment-mode and balance invariants; Invoice lacks documented balance/refund/finalization facts | Add folio calculation and finalization rules; prohibit underpayment/overpayment inconsistencies; preserve correction evidence | High | P1 |
| GAP-014 | UC-015, BR-STAY-005 | Check-in accepts any confirmed date and optional identity number | Enforce arrival window and configured identity requirement; protect identity data by role | High | P1 |
| GAP-015 | BR-HK-002/003, UC-033/037 | Cleaning completion and maintenance resolution return rooms directly to Available | Implement inspection and release policy; maintain status/task/request consistency | High | P1 |
| GAP-016 | BR-ROOM-002, NFR-REL-003 | Owner setup status updates can bypass occupied, dirty, housekeeping, or maintenance lifecycle | Separate configuration changes from operational transitions and reject active dependency conflicts | High | P1 |
| GAP-017 | BR-AUDIT-001, NFR-AUD-001 | Audit records are created mainly for Platform Admin changes | Add transactional audit creation for all protected state changes | High | P1 |
| GAP-018 | BR-NOTI-001, NSF-003 | Notification entity exists but core workflows do not create notification events | Add transactional notification/outbox records for required events; mock delivery may remain | High | P1 |
| GAP-019 | UC-010/011/012/026/027 | Hotel Manager cannot perform the documented management scope; Owner controller is role-locked | Add tuple-aware Manager permissions and restrict authority escalation to Owner/Platform policy | High | P2 |
| GAP-020 | UC-026/027 | Staff supports create/list only | Add attach/invite, update, deactivate/reactivate, role reassignment, hotel reassignment safeguards, and audit | High | P2 |
| GAP-021 | UC-025 | Own-profile API excludes Owner and hotel staff roles | Replace Customer-specific profile boundary with authenticated own-profile service and role-neutral mobile settings | Medium | P2 |
| GAP-022 | UC-001/002/009 | Mobile requires login for public marketplace and gives a new Owner no hotel-registration route | Make search/detail public; protect only booking; add Owner onboarding route and API client | High | P2 |
| GAP-023 | UC-008, UC-014 | Booking guest count is not persisted/read and is hard-coded to one | Persist GuestCount and expose it in Customer and Front Desk DTOs | Medium | P2 |
| GAP-024 | ENT-005 to ENT-012, SCR-006/016/018 | Hotel/room detail omits images, amenities, cancellation policy, floor, notes, and complete facilities | Extend domain/schema/contracts and role-appropriate mobile views | Medium | P2 |
| GAP-025 | UC-032 to UC-036 | Same-hotel staff can start or overwrite another assignee's task/request | Enforce assignee ownership or Manager override with audit | Medium | P2 |
| GAP-026 | SCR-038/039 | Mobile Platform Admin omits commission and reconciliation operations | Add admin clients, filters, detail evidence, and status actions | Medium | P2 |
| GAP-027 | SCR-012/013/019/022 | Payment result, Customer refund status, availability calendar, no-show candidates, and room overview are missing/partial | Add behavior-complete mobile equivalents; separate screens are optional when consolidated behavior is complete | Medium | P2 |
| GAP-028 | NFR-SEC-006 | Android main manifest globally enables cleartext and production URL accepts HTTP | Move cleartext to debug configuration and reject insecure production API URLs | High | P2 |
| GAP-029 | Saved/notification behavior | Favorites and notification-like state are device-local | Add backend records and account synchronization if retained in product scope, or formally mark them as non-SRS convenience features | Medium | P3 |
| GAP-030 | NFR-PER/REL/SEC/AUD | Eight integration tests and one Flutter widget test do not cover core negative invariants | Add domain, application, API, concurrency, authorization, finance, scheduler, and mobile contract tests | High | P0-P3 |
| GAP-031 | NFR-BACK-001, NFR-MAINT-001 | SDK pin, compose references, scheduling dependency, and startup documentation have drifted | Align .NET SDK, project references, compose assets, backup/restore, and run documentation | Low | P3 |

## Remediation Status

| Gap | Status | Evidence |
| --- | --- | --- |
| GAP-001 | Remediated on `fix/aln-001-hotel-role-authorization` | Platform Administrator bypass removed from operational and customer routes; active hotel-role assignment is required server-side |
| GAP-002 | Remediated on `fix/aln-001-hotel-role-authorization` | JWT now carries `hotel_role_access` tuples and authorization validates the active tuple against endpoint roles |
| GAP-003 | Remediated on `fix/aln-002-unified-inventory-commitment` | Marketplace and Walk-in creation share one room-type lock and commitment calculation; overlapping date windows and room blocks are covered by integration tests |
| GAP-004 | Remediated on `fix/aln-003-approved-walk-in-model` | Walk-in bookings use a protected shared customer, retain actual guest data, record exact cash collection, never enter PendingPayment, and become Confirmed or CheckedIn based on assignment |
| GAP-005 | Remediated on `fix/aln-004-explicit-demo-payment` | Runtime exposes one authenticated demo-payment endpoint, records provider `DEMO`, removes payOS routes/configuration/project code, and covers ownership, amount, expiration, idempotency, audit, and notification |
