# Decision Log

This log contains conflicts or scope choices that materially affect product
behavior, security, data design, or implementation effort. Decisions are not
assumed from current code behavior.

| Decision ID | Topic | Approved decision | Implementation constraint | Status |
| --- | --- | --- | --- | --- |
| DEC-AUD-001 | Payment scope | The MVP retains demo payment and does not integrate a real payment provider. | Demo payment must still verify authentication, booking ownership, current booking state, amount, idempotency, and audit evidence. Documentation and user-facing text must clearly identify simulated payment behavior. | Approved |
| DEC-AUD-002 | Platform Administrator hotel access | Platform Administrators do not automatically receive operational authority for hotel Front Desk, Housekeeping, or Maintenance workflows. | Platform Administrators may read macro financial information, overview room information, and hotel registration or approval information. Operational hotel mutations require an explicit hotel staff assignment and an operational role; platform role alone never grants them. | Approved |
| DEC-AUD-003 | Walk-in customer and payment flow | Every walk-in booking is mapped to the shared system account named `Anonymous Walk-in Customer`. Cash is collected at the front desk, so the booking never enters `PendingPayment` and never receives a fifteen-minute payment timer. | A walk-in booking becomes `CheckedIn` when physical rooms are assigned during creation. If creation is completed without room assignment, it becomes `Confirmed` and requires the normal room-assignment and check-in transition. Both paths must use the same inventory concurrency protection as online booking. | Approved |

## Remaining Decisions Before Related Implementation

These items do not block completion of the audit or P0 authorization/inventory
work. They must be resolved before their corresponding P1 or P2 change begins.

| Decision ID | Topic | Document conflict or ambiguity | Recommended default | Needed before | Status |
| --- | --- | --- | --- | --- | --- |
| DEC-AUD-004 | Check-in identity fields | SRS requires identity information when hotel operation requires it but does not define exact fields | Store document type, document number, issuing country, and optional expiry; require type and number at check-in; restrict access and define retention | ALN-008 | Open |
| DEC-AUD-005 | Hotel Manager staff authority | SRS permits Manager staff management but leaves delegated approval detail open | Manager may manage Receptionist, HousekeepingStaff, and MaintenanceStaff only at assigned hotels; cannot grant Owner, Manager, or PlatformAdministrator; cannot elevate self | ALN-010 | Open |
| DEC-AUD-006 | Inspection and maintenance release policy | SRS has inspection states while ASSUMP-017 describes a simple maintenance workflow | Add hotel policy `RequiresRoomInspection`; maintenance completion returns to Dirty or InspectionRequired, and only an authorized completion path returns to Available | ALN-008 | Open |
| DEC-AUD-007 | Saved hotels and notifications | Current mobile stores convenience state locally while notification records are an SRS requirement | Keep notifications server-backed; either make saved hotels server-backed or explicitly remove favorites from supported scope | ALN-009, ALN-013 | Open |
