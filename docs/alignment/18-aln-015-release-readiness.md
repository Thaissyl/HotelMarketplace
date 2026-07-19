# ALN-015 Release Readiness

Status: Implemented and verified on `fix/aln-015-release-readiness`.

## Toolchain

The backend targets `net8.0`. `global.json` now declares .NET SDK 8.0.100 as the
minimum baseline and permits roll-forward to an installed stable major SDK. This
keeps the repository honest about its target framework while allowing the
verified development machine, which currently has SDK 10.0.103, to build it.

The verified Mobile toolchain is Flutter 3.41.9 with Dart 3.11.5.

## Architecture Dependency Cleanup

`Infrastructure.Scheduling` resolves only the Application expiration contract
through a scoped service. It does not use persistence implementation types, so
the unnecessary project reference to `Infrastructure.Persistence` was removed.
The remaining project references are Application and SharedKernel.

## Docker Compose

The local Compose file runs SQL Server 2022 with a named persistent data volume,
health check, explicit local port, and strong-password environment requirement.
The ineffective `/docker-entrypoint-initdb.d` mount was removed because the SQL
Server image does not execute that directory automatically. EF Core migrations
remain the single schema-management mechanism.

## Backup and Restore

`scripts/backup-local-database.ps1` creates a copy-only, checksum-protected,
compressed backup and copies it to the Git-ignored `.local/backups` directory.

`scripts/restore-local-database.ps1` validates the configured database name,
requires an existing backup and explicit `-Force`, restores through the SQL
Server container, and attempts to return the database to multi-user mode if SQL
Server reports an error.

Both scripts load secrets from the ignored local `.env` file and do not write
credentials to repository files. Backup and restore were executed successfully
against the local `HotelMarketplace` database, followed by a successful EF
database update.

## Reproducibility

The root README and `docs/RUN_LOCAL_APP.md` describe:

- tool prerequisites and environment setup;
- SQL Server startup and health verification;
- automatic migration before API startup;
- Swagger and API health checks;
- Android emulator API routing;
- test accounts and role-flow checklist;
- backup and destructive restore safeguards;
- backend and Mobile verification commands.

The final commit is verified from a separate clean Git worktree. Local `.env`,
database backups, screenshots, UI hierarchy dumps, and previous build output are
therefore excluded from the release evidence.

## Residual Scope

- Production deployment topology and managed backup scheduling are outside the
  local MVP repository.
- Android production HTTPS enforcement remains GAP-028.
- Requirement-level test expansion remains GAP-030 and ALN-014.
