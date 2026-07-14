# Collaboration Rules

These rules guide future work in this repository.

## Communication

- User-facing conversation should be in Vietnamese.
- Repository notes, README files, Markdown documentation, code comments, and technical documentation should be written in English.
- Important technical decisions must be presented to the user before implementation when they affect architecture, dependency choices, database strategy, authentication strategy, module boundaries, naming conventions, or long-term project direction.
- Small low-risk implementation details may be handled directly when they follow the established architecture.

## Git Workflow

- Do not commit or push automatically after every change.
- Only commit or push when the user explicitly asks to update Git, commit, or push.
- Before any commit or push, check `git status` and report the relevant changes.

## Project Constraints

- Keep the backend aligned with Clean Architecture.
- Do not put business logic in `Presentation.Api`.
- Do not put infrastructure concerns in `Domain`.
- Shared cross-cutting primitives belong in `SharedKernel`.
- Local environment files and secrets must not be committed.
- Prefer complete working code over pseudo-code.
