# SRS, SDD, and Codebase Alignment Audit

This directory is the working area for reconciling the Hotel Marketplace
Management System implementation with its approved requirements and design.
It separates source facts, implementation evidence, findings, decisions, and
the remediation plan so that no requirement is changed silently.

## Objective

Produce one evidence-backed implementation plan that makes the backend,
database, mobile client, automated tests, and operational documentation conform
to the canonical SRS and SDD.

## Working Rules

1. The canonical SRS defines required behavior and scope.
2. The SDD defines the intended technical design when it does not conflict with
   the SRS.
3. Diagram notes and mockups clarify flows and presentation but cannot silently
   override explicit business rules.
4. The deviation report is an audit input, not a normative specification.
5. The codebase and tests describe current behavior, not automatically correct
   behavior.
6. Every mismatch must have source evidence and implementation evidence.
7. Every unresolved conflict must be recorded in the decision log before code
   changes are made.
8. Remediation work must be split into independently verifiable changes with
   tests and migration impact stated explicitly.

## Audit Outputs

| File | Purpose |
| --- | --- |
| [00-source-register.md](00-source-register.md) | Sources, provenance, authority, and review status |
| [01-review-method.md](01-review-method.md) | Evidence and classification method |
| [02-traceability-matrix.md](02-traceability-matrix.md) | Requirement-to-code and requirement-to-test mapping |
| [03-gap-register.md](03-gap-register.md) | Confirmed deviations, risks, and proposed corrections |
| [04-decision-log.md](04-decision-log.md) | Decisions requiring explicit approval |
| [05-remediation-roadmap.md](05-remediation-roadmap.md) | Ordered implementation and verification plan |
| [06-approved-scope-decisions.md](06-approved-scope-decisions.md) | Approved project-specific behavior that constrains remediation |
| [07-audit-summary.md](07-audit-summary.md) | Consolidated conformance assessment and release position |
| [08-verification-log.md](08-verification-log.md) | Commands executed and reproducible verification results |
| [09-aln-001-hotel-role-authorization.md](09-aln-001-hotel-role-authorization.md) | ALN-001 implementation evidence and acceptance results |
| [10-aln-002-unified-inventory-commitment.md](10-aln-002-unified-inventory-commitment.md) | ALN-002 inventory invariants and concurrency evidence |
| [11-aln-003-approved-walk-in-model.md](11-aln-003-approved-walk-in-model.md) | ALN-003 protected anonymous customer and Walk-in lifecycle evidence |
| [12-aln-004-explicit-demo-payment.md](12-aln-004-explicit-demo-payment.md) | ALN-004 explicit demo payment contract, atomicity, and audit evidence |
| [13-aln-005-cancellation-refund-no-show.md](13-aln-005-cancellation-refund-no-show.md) | ALN-005 cancellation, refund initiation, no-show, and lock-order evidence |
| [14-aln-006-availability-calendar.md](14-aln-006-availability-calendar.md) | ALN-006 availability calendar, permissions, interval, marketplace, and concurrency evidence |
| [15-aln-007-dual-collection-finance.md](15-aln-007-dual-collection-finance.md) | ALN-007 dual collection, reconciliation, settlement, and invoice invariants |
| [workstreams](workstreams/README.md) | Detailed reviews by business capability |

## Completion Criteria

The audit is complete only when every in-scope use case, business rule, status
lifecycle, entity, screen authorization rule, external interface, and relevant
non-functional requirement has a traceability status. Each confirmed gap must
either be included in the remediation roadmap or be explicitly accepted as a
documented scope deviation.
