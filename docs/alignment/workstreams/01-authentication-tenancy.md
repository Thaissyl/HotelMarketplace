# WS-01 Authentication and Tenancy

Status: Deviated; P0 correction required

## Aligned Evidence

- Registration and login use application validators and PBKDF2 password hashing.
- Inactive accounts are rejected by authentication.
- Route hotel ID has precedence over a forged `X-Hotel-Id` header.
- Existing integration coverage verifies one Owner cross-hotel denial case.

## Verified Gaps

| Requirement | Finding | Evidence | Gap |
| --- | --- | --- | --- |
| BR-AUTH-002 | Platform Administrator receives unconditional hotel access | `HotelAccessAuthorizer.cs`; operational services repeat the bypass | GAP-001 |
| UC-027 | JWT emits separate role and hotel claims and loses assignment relationship | `EfAuthUserRepository.cs`, `JwtTokenGenerator.cs` | GAP-002 |
| UC-025 | Profile API permits only Customer and Platform Administrator | `CustomerAccountController.cs` | GAP-021 |
| BR-AUTH-003 | Role and assignment revocation are not implemented as an operational lifecycle | `HotelStaffAssignment.cs`, staff service contracts | GAP-020 |

## Required Design

Authorization must answer `Does this user hold role R at hotel H now?`, not
`Does this user hold R anywhere and have H anywhere?`. Platform governance APIs
remain global. Front Desk, Housekeeping, Maintenance, Owner, and Manager
operations require an exact active assignment or ownership relationship.
