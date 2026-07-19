# Audit Workstreams

The audit is partitioned by capability so sections can be reviewed in parallel
without mixing evidence or duplicating decisions.

| Workstream | Scope | File |
| --- | --- | --- |
| WS-01 | Authentication, account lifecycle, roles, claims, and tenant authorization | [01-authentication-tenancy.md](01-authentication-tenancy.md) |
| WS-02 | Marketplace, customer booking, customer booking management, and payment entry | [02-marketplace-customer-booking.md](02-marketplace-customer-booking.md) |
| WS-03 | Inventory, availability, concurrency, physical rooms, and room status | [03-inventory-availability.md](03-inventory-availability.md) |
| WS-04 | Hotel setup, owner and manager permissions, and staff management | [04-hotel-setup-staff.md](04-hotel-setup-staff.md) |
| WS-05 | Front desk, walk-in, assignment, check-in, checkout, invoice, and collection | [05-front-desk-stay.md](05-front-desk-stay.md) |
| WS-06 | Housekeeping, maintenance, inspection, and room return-to-service | [06-housekeeping-maintenance.md](06-housekeeping-maintenance.md) |
| WS-07 | Platform approval, commission, reconciliation, refund, settlement, and reporting | [07-platform-finance.md](07-platform-finance.md) |
| WS-08 | Notifications, scheduler, audit trail, NFRs, deployment, and observability | [08-cross-cutting-nfr.md](08-cross-cutting-nfr.md) |
| WS-09 | Mobile navigation, role workspaces, validation, resilience, performance, and screen parity | [09-mobile-experience.md](09-mobile-experience.md) |

Each workstream must capture requirement evidence, intended design, current
implementation, verified gaps, test coverage, dependencies, and proposed
remediation. Cross-workstream conflicts belong in the central decision log.
