# WS-08 Cross-Cutting and Non-Functional Requirements

Status: Transactional audit, notification recording, and local operations are aligned; transport and broader requirement tests remain incomplete

## Aligned Evidence

- Clean Architecture project boundaries are broadly recognizable.
- Global exception handling returns ProblemDetails without stack traces in normal
  client responses.
- Read-heavy queries commonly use projections and `AsNoTracking`.
- Unpaid booking expiration uses a lightweight hosted service.
- Demo payment writes its payment, commission, audit, and notification evidence
  in one transaction and has negative and concurrency integration coverage.
- Protected entity mutations now create audit evidence in the same `SaveChanges`,
  including scheduler actions without a human actor.
- Required business event families create durable Pending notification outbox
  records; external delivery remains mocked under the approved MVP scope.
- Toolchain selection, Compose behavior, startup, migration, and tested local
  database backup/restore procedures are documented and reproducible.

## Verified Gaps

| Requirement | Finding | Gap |
| --- | --- | --- |
| NFR-SEC-006 | Android release configuration permits cleartext globally | GAP-028 |
| NFR-REL/SEC | Existing tests omit principal negative and cross-channel invariants | GAP-030 |

## Required Design

Use transactional audit and notification outbox records, environment-specific
transport policy, requirement-level automated tests, reproducible toolchain
versions, and documented database backup/restore. Mock notification delivery is
acceptable; missing event records are not.
