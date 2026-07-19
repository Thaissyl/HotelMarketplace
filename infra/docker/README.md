# Local Docker Infrastructure

The root `docker-compose.yml` runs SQL Server 2022 for local development. The API
and Flutter client run directly on the host so debugging, hot reload, and Android
emulator networking remain predictable.

Database schema creation is handled exclusively by Entity Framework Core
migrations through `scripts/start-local-backend.ps1`. SQL Server container images
do not automatically execute files from a Docker entrypoint initialization
directory.

The named `hotel-marketplace-sqlserver-data` volume preserves database files
across normal `docker compose down` operations. Use the repository backup and
restore scripts before deleting the volume.
