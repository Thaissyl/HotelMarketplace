# ALN-010 Owner, Manager, and Staff Lifecycle

Status: Implemented and verified on `feat/aln-010-staff-lifecycle`.

## Scope

ALN-010 partially closes GAP-019 and substantially closes GAP-020. Property
Owners and assigned Hotel Managers can manage hotel-local staff without granting
platform or ownership authority.

## Authority Model

- A Property Owner may create or attach HotelManager, Receptionist,
  HousekeepingStaff, and MaintenanceStaff accounts for a hotel they own.
- A Hotel Manager may create or attach Receptionist, HousekeepingStaff, and
  MaintenanceStaff accounts at a hotel where their Manager assignment is active.
- A Hotel Manager cannot manage another Manager, cannot grant elevated roles,
  and cannot change or deactivate their own assignment.
- PlatformAdministrator is not accepted as a hotel staff role and platform
  authority does not bypass the `HotelScoped` policy.

## Lifecycle and Concurrency

Create, attach, role change, deactivate, and reactivate operations run in a
serializable transaction. SQL application locks serialize account identity and
hotel-assignment mutations. A filtered unique index permits at most one active
assignment for a user at a hotel.

The persistence layer keeps global role records synchronized with active hotel
assignments. Revoking or changing the final assignment for a role deactivates
that global role. Authorization also validates the current active hotel-role
tuple in the database, so a JWT issued before revocation loses access without
waiting for token expiration.

An assignment cannot be deactivated or moved to another role while its user owns
open housekeeping or maintenance work. Inactive accounts and protected system
accounts cannot be attached. Platform Administrator accounts cannot be converted
into hotel staff.

## API and Mobile

`OperationsHotelsController` exposes hotel-scoped list, create, attach, and
assignment update endpoints to PropertyOwner and HotelManager. The Mobile Staff
workspace exposes Create account and Attach existing modes, active-access state,
role changes, and pause or restore actions. Manager UI omits Manager authority
and self-management actions.

## Data Migration

`EnforceHotelStaffLifecycle` deactivates historical duplicate active assignments
deterministically before replacing the role-specific unique index with a unique
filtered `(UserAccountId, HotelId)` active-assignment index.

## Acceptance Evidence

- Backend build passes with zero warnings and zero errors.
- Domain tests cover assignment and account-role transitions.
- SQL Server integration tests cover Owner and Manager permissions, attach,
  duplicate rejection, role change, stale-token denial, open-task protection,
  deactivate, reactivate, and list behavior.
- Flutter analysis and tests cover the updated assignment contract and mutation
  request serialization.

## Residual Scope

- Invitation links and email delivery are not required for the attach-existing
  MVP flow.
- Cross-hotel transfer is represented as an independent assignment at the target
  hotel, not as a destructive move.
- Role-neutral own-profile management remains GAP-021.
- Delegated Manager mutation of hotel profile, room types, and physical-room
  setup remains GAP-019.
