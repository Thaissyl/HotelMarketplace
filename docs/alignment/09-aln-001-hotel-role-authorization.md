# ALN-001 Hotel-Role Authorization Implementation

Date: 2026-07-19

Branch: `fix/aln-001-hotel-role-authorization`

## Objective

Prevent a user from performing a hotel operation unless the user has an active,
compatible role at that exact hotel. Platform governance authority must not imply
Front Desk, Housekeeping, Maintenance, Owner, Customer, or payment authority.

## Implemented Invariants

1. A hotel-scoped request resolves its target hotel from the established tenant
   context and requires the `HotelScoped` policy.
2. Authorization reads active assignments from the database for every protected
   request, so revocation takes effect before an existing JWT expires.
3. Endpoint role metadata is intersected across controller and action attributes.
   A role held at one hotel cannot satisfy a different role at another hotel.
4. Property ownership is represented as `(hotelId, PropertyOwner)` without
   requiring a duplicate staff assignment.
5. JWTs retain the compatibility `role` and `hotel_id` claims and add one
   `hotel_role_access` claim per exact assignment.
6. Platform Administrator remains authorized for `/api/platform-admin` governance
   endpoints but receives no implicit operational or Customer authority.
7. Hotel-scoped authorization has one enforcement point in the authorization
   handler; the previous duplicate authorization middleware was removed.

## Persistence and Session Behavior

Authentication projects active staff assignments by joining
`HotelStaffAssignments` to `UserRoles`. Owned hotels are projected as Property
Owner access. The API response contract remains compatible because `roles` and
`hotelIds` are unchanged, while the JWT gains tuple claims.

`EfHotelAccessRepository` verifies that the account is active and then validates
the exact active assignment and allowed role. `HotelStaffAssignment.Revoke()`
provides the domain operation used to invalidate access.

## Acceptance Tests

| Scenario | Expected result | Result |
| --- | --- | --- |
| Forged `X-Hotel-Id` conflicts with route hotel | Forbidden | Passed |
| Platform Administrator has no hotel assignment | Operational endpoint returns 403 | Passed |
| Receptionist at hotel A and Manager at hotel B requests Manager data at A | Forbidden | Passed |
| The same mixed-role user requests Manager data at hotel B | Allowed | Passed |
| Assignment is revoked after JWT issuance | Next hotel request returns 403 | Passed |
| Existing booking and operational smoke flows | No regression | Passed |

## Verification

```powershell
dotnet build .\backend\HotelMarketplace.slnx --no-restore
dotnet test .\backend\HotelMarketplace.slnx --no-restore --logger "console;verbosity=minimal"
```

Build result: 0 warnings and 0 errors.

Test result: 11 API integration tests passed. The Domain and Application test
projects currently contain no authored tests; that remaining quality gap is tracked
by ALN-014.
