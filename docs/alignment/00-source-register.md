# Source Register

## Authority Order

| Priority | Source type | Interpretation |
| --- | --- | --- |
| 1 | Canonical SRS | Required product behavior, actors, scope, rules, states, and messages |
| 2 | Confirmed clarification and scope decisions | Explicit decisions that resolve ambiguity in the SRS |
| 3 | Canonical SDD | Intended architecture, data design, transactions, and use-case realization |
| 4 | Diagram notes and screen mockups | Supporting flow, state, data, and user-interface evidence |
| 5 | Deviation report | Previously identified risks that must be independently verified |
| 6 | Codebase and tests | Evidence of current implementation behavior |

## Primary Project Sources

| ID | Source | Role | Status |
| --- | --- | --- | --- |
| SRC-SRS-001 | `docs/source/software-requirement-document.md` | Canonical requirements | Reviewed and traced by use case |
| SRC-SDD-001 | `docs/source/software-design-document.md` | Canonical design | Architecture, data design, and 37 detailed use cases reviewed |
| SRC-DEV-001 | `docs/source/srs-sdd-codebase-deviation-report.md` | Independent deviation report | Findings independently checked and adjusted for approved scope decisions |
| SRC-CODE-BE | `backend/` | Backend, persistence, jobs, migrations, and tests | Controllers, services, domain, persistence, migrations, and tests reviewed |
| SRC-CODE-MOB | `mobile/` | Flutter client and mobile tests | Router, API clients, role workspaces, configuration, and tests reviewed |

## Supporting Source Package

Root: `D:\hotel-management-srs\hotel-management-system-srs`

| Source group | Count | Audit use |
| --- | ---: | --- |
| Markdown documents | 31 | SRS text and diagram notes |
| Draw.io diagrams | 28 | Editable flow, ERD, use-case, activity, and state sources |
| PNG files | 69 | Rendered diagrams and screen mockups |
| Word documents | 3 | Original specification and design documents |
| Export scripts | 1 | Document generation provenance |

Important package documents:

| ID | Path | Audit use |
| --- | --- | --- |
| SRC-PKG-SRS | `hotel_management_system_srs_v1_2_staff_screen_mockup_ready.md` | Native Markdown SRS and screen references |
| SRC-PKG-SDD | `software-design-document.md` | Native Markdown SDD for conversion comparison |
| SRC-PKG-NOTES | `diagrams/notes/` | Context, use-case, screen-flow, ERD, activity, and state notes |
| SRC-PKG-DRAWIO | `diagrams/drawio/` | Editable diagram sources |
| SRC-PKG-MOCKUPS | `hotel_management_system_srs_v1_2_assets/` | Forty-one role-oriented screen mockups |

The supporting package contains 133 files. Its 28 diagram notes and forty-one
screen references were cross-checked against the canonical use-case, lifecycle,
entity, and screen sections. No additional source was allowed to override an
explicit canonical rule without a decision-log entry.

## Conflict Handling

When sources disagree, record the conflict in `04-decision-log.md` with exact
citations. Do not infer that a newer file name is more authoritative. Compare
document version, record-of-changes entries, clarification decisions, source
hash, and semantic content before selecting the canonical rule.
