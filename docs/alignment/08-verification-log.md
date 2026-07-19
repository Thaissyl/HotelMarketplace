# Verification Log

Date: 2026-07-19

## Documentation Checks

| Check | Result |
| --- | --- |
| Alignment Markdown files | 29 files including implementation evidence and workstreams |
| Broken local Markdown links | 0 |
| Use cases assessed | 37 |
| Verified gaps registered | 31 |
| Approved scope decisions | 3 |
| Remaining implementation decisions | 4 |

## Static and Build Verification

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 4 tests |

## Backend Test Verification

The test-host configuration defect was corrected during ALN-001. The integration
factory now establishes an isolated `Testing` environment before creating the host,
uses the dynamic SQL Server Testcontainer connection, disables booking expiration,
and restores prior process environment values after the suite.

`dotnet test .\backend\HotelMarketplace.slnx --no-restore` completed successfully:

- API integration tests: 21 passed, 0 failed, 0 skipped.
- Domain.UnitTests: no authored tests discovered.
- Application.UnitTests: no authored tests discovered.
- The API suite includes forged-header, unassigned Platform Administrator,
  mixed-role cross-hotel, and post-token assignment-revocation scenarios.
- Inventory coverage includes same-channel contention, marketplace versus Walk-in
  contention, different but overlapping date windows, and physical-room blocks.
- Walk-in coverage includes protected anonymous-customer attribution, deferred
  assignment to `Confirmed`, immediate assignment to `CheckedIn`, disabled system
  login and Admin mutation, exact cash collection, and absence of payment expiry.
- Demo payment coverage includes wrong amount, foreign booking, expired hold,
  duplicate retry, concurrent confirmation, single transaction and commission,
  and transactional audit and notification records.

This result verifies the current ALN-001 through ALN-004 acceptance scope. It does
not establish conformance for the remaining remediation packages or replace the
missing Domain and Application test suites.

## ALN-005 Verification

The ALN-005 branch was verified after cancellation, refund initiation, no-show,
shared booking locks, migration, and Mobile actions were implemented.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `dotnet test .\backend\HotelMarketplace.slnx --no-restore` | Passed; 27 API integration tests and 5 Domain tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 1 test |
| Android profile build | Passed and installed on the existing Pixel 7 emulator |

ALN-005 coverage includes unpaid cancellation and inventory reuse, paid policy
refund creation and persistent Customer projection, foreign-customer denial,
concurrent payment versus cancellation, early no-show denial, successful no-show
evidence, invalid Domain transitions, and room assignment release. Application
unit tests remain unauthored and are still tracked as residual test debt.

## ALN-005 Emulator Verification

The Mobile client was exercised against the local SQL Server container and API on
the existing Pixel 7 emulator. The API was bound to all local interfaces and the
database migrations were applied through `scripts/start-local-backend.ps1`.

- Customer login, public hotel search, and Customer trip retrieval completed.
- A `PendingPayment` booking displayed its guest, stay dates, room count, nightly
  rate, booking total, and payment deadline.
- The cancellation quote displayed policy, collected-payment, and estimated-refund
  information. A required reason was enforced before submission.
- Cancellation completed with HTTP 200 and the trip immediately refreshed to
  `Cancelled`.
- Receptionist login opened the assigned hotel by name and loaded detailed arrival
  records with guest, phone, booking code, dates, room type, payment, and assignment
  information.
- The no-show action required an operational reason. Submitting it before the
  configured window returned HTTP 409 and the Mobile client presented the business
  explanation without exposing server details.
- The expired-booking scheduler completed its local scan without the prior
  `ReadOnlySpan<Guid>` expression-evaluation failure.

Residual limitations remain: hotel-local time zones are not yet modeled for the
no-show window, Application unit tests are not authored, and cancellation-policy
administration is not exposed as a dedicated Mobile workflow.

## ALN-006 Verification

The availability calendar was verified across Domain, API, SQL Server persistence,
public marketplace projection, Mobile contract parsing, and the Pixel 7 emulator.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `dotnet test .\backend\HotelMarketplace.slnx --no-restore` | Passed; 32 API integration tests and 8 Domain tests |
| `dotnet ef migrations has-pending-model-changes` | Passed; model matches the latest migration |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 2 tests |
| Android profile build | Passed and installed on the existing Pixel 7 emulator |

ALN-006 tests verify room-type close/open marketplace consistency, active-booking
conflict rejection, Receptionist physical-room-only authority, and concurrent
online booking versus availability blocking. It also verifies that partially
opening or unblocking a restriction preserves the unaffected date intervals.
Emulator verification confirmed the
Receptionist calendar layout, hotel and room context, filters, role-limited form,
required reason, duplicate-submit protection, and friendly HTTP 409 presentation.

The implementation intentionally uses a conservative conflict rule: a new close
or block is rejected when any active room-type commitment overlaps the requested
dates. A controlled exception or relocation workflow is not implemented. Setup
status bypass and inspection/release policy remain assigned to ALN-008.

## ALN-007 Verification

The dual-collection finance model was verified through Domain invariants, SQL
Server integration flows, migration consistency, and Mobile contract tests.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `dotnet test .\backend\HotelMarketplace.slnx --no-build` | Passed; 33 API integration tests and 12 Domain tests |
| `dotnet ef migrations has-pending-model-changes` | Passed; model matches the latest migration |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 4 tests |
| `flutter build apk --debug` | Passed; debug APK built successfully |

ALN-007 coverage verifies immediate Pay-at-Property confirmation without an
expiration, exact and partial property collection, concurrent attempts against
the final balance, Demo reconciliation, finance summary projection, settlement
creation and finalization evidence, and amount/state invariants for collection,
invoice, commission, payment, and settlement entities.

Residual work is intentionally recorded rather than hidden: Front Desk Mobile
does not yet expose independent pre-checkout partial collection, dedicated Mobile
commission-rate management remains pending, and Application.UnitTests still has
no authored tests.

## ALN-008 Verification

The stay and room lifecycle was verified across Domain transitions, SQL Server
integration flows, migration consistency, Mobile static analysis, and Android
build output.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| Domain unit tests | Passed; 15 tests |
| API integration tests | Passed; 35 tests |
| `dotnet ef migrations has-pending-model-changes` | Passed; model matches the latest migration |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 4 tests |
| `flutter build apk --debug` | Passed; debug APK built successfully |

ALN-008 coverage verifies required identity evidence, arrival-date-only check-in,
atomic room pre-assignment and replacement, early check-in rejection, cleaning
inspection, maintenance resolution and release evidence, and rejection of setup
status bypass. The integration test database applies the additive migration,
including legacy identity backfill, before exercising the API suite.

Residual work remains explicit: hotel-local timezone policy is not modeled,
task assignee ownership belongs to GAP-025, complete mutation audit/outbox belongs
to ALN-009, and Application.UnitTests still has no authored tests.

## ALN-009 Verification

The audit and notification outbox implementation was verified across protected
entity persistence, human and scheduler actors, existing explicit workflow
evidence, SQL Server migration consistency, and the unchanged Mobile build.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `dotnet test .\backend\HotelMarketplace.slnx --no-build` | Passed; 15 Domain tests and 35 API integration tests |
| `dotnet ef migrations has-pending-model-changes` | Passed; model matches the latest migration |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 4 tests |
| `flutter build apk --debug` | Passed; debug APK built successfully |

ALN-009 automatically records non-sensitive audit summaries for the protected
account, hotel, inventory, booking, finance, stay, housekeeping, and maintenance
entities. Existing explicit workflow audit and notification entries suppress a
generic duplicate for the same target. Notification records cover every event
family required by NSF-003 and remain Pending for the approved mocked-delivery
MVP scope.

Integration assertions verify audit coverage for booking, stay, room assignment,
invoice, and housekeeping entities, plus checkout and housekeeping outbox events.
Scheduler expiration is verified with a nullable human actor, a hotel-scoped
system audit, and a Customer-targeted `BookingExpired` notification.

## ALN-015 Release Readiness Verification

The release-readiness pass aligned the declared SDK baseline, project references,
Docker Compose behavior, local operations scripts, and run documentation.

| Check | Result |
| --- | --- |
| `dotnet --version` with .NET 8 baseline and `latestMajor` roll-forward | Selected installed SDK `10.0.103`; net8.0 build passed |
| `docker compose config --quiet` | Passed |
| Scheduling project references | Application and SharedKernel only; unused Persistence reference removed |
| PowerShell parser | Backup and restore scripts contain no syntax errors |
| Local SQL Server backup | Passed with checksum and compression; backup copied to ignored `.local/backups` |
| Local SQL Server restore | Passed against the configured `HotelMarketplace` database |
| EF database update after restore | Passed; database is on the latest migration |

The final commit is additionally verified from a separate clean Git worktree so
untracked emulator screenshots, local environment files, and prior build output
cannot influence build, test, Compose, or Flutter results.

## ALN-010 Staff Lifecycle Verification

The Owner and Manager staff lifecycle was verified against domain invariants,
the complete SQL Server API suite, the EF migration model, Mobile contracts, and
the Android debug build.

| Command | Result |
| --- | --- |
| `dotnet build .\backend\HotelMarketplace.slnx --no-restore` | Passed; 0 warnings and 0 errors |
| `dotnet test .\backend\HotelMarketplace.slnx --no-build` | Passed; 18 Domain tests and 36 API integration tests |
| `dotnet ef migrations has-pending-model-changes` | Passed; model matches `EnforceHotelStaffLifecycle` |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 6 tests |
| `flutter build apk --debug` | Passed; debug APK built successfully |

The lifecycle integration scenario verifies Owner-created Manager accounts,
Manager-created operational staff, attach-existing behavior, duplicate rejection,
Manager escalation and self-management denial, stale-token denial after role
change or revocation, open-task protection, reactivation, and list projection.
Actor authority is revalidated under the same transaction and application lock
as each mutation so concurrent Manager revocation cannot authorize a later staff
change.
