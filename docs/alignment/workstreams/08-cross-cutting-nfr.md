# WS-08 Cross-Cutting and Non-Functional Requirements

Status: Architecture is usable; audit, notification, transport, tests, and operations are incomplete

## Aligned Evidence

- Clean Architecture project boundaries are broadly recognizable.
- Global exception handling returns ProblemDetails without stack traces in normal
  client responses.
- Read-heavy queries commonly use projections and `AsNoTracking`.
- Unpaid booking expiration uses a lightweight hosted service.
- Demo payment writes its payment, commission, audit, and notification evidence
  in one transaction and has negative and concurrency integration coverage.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| NFR-AUD-001 | Audit is concentrated in Platform Admin repository | GAP-017 |
| NSF-003 | Notification records are not created by required business events | GAP-018 |
| NFR-SEC-006 | Android release configuration permits cleartext globally | GAP-028 |
| NFR-REL/SEC | Existing tests omit principal negative and cross-channel invariants | GAP-030 |
| NFR-BACK-001 | Backup/restore procedure is not demonstrated | GAP-031 |
| NFR-MAINT-001 | SDK pin, compose references, and scheduling dependency have drifted | GAP-031 |

## Required Design

Use transactional audit and notification outbox records, environment-specific
transport policy, requirement-level automated tests, reproducible toolchain
versions, and documented database backup/restore. Mock notification delivery is
acceptable; missing event records are not.
