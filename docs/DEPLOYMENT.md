# Deployment

## Current production setup

One Ubuntu 24.04 VM (4 vCPU, 4 GB RAM) runs the whole stack with Docker Compose. The host also serves another
application, so ports 3000, 3001 and 8000 on the host are **not** ours and must stay untouched.

| Item | Value |
|---|---|
| Checkout | `~/apps/school-management` (git clone, branch `main`) |
| Compose files | `backend/docker-compose.yml` + server-only `backend/docker-compose.override.yml` (not in git) |
| Secrets | `backend/.env` (mode 600, not in git) — see `backend/.env.example` |
| Compose project | `school-management` (9 containers) |
| Public ports | admin-web **3100**, Flutter web **3200**, gateway **5001** (plain HTTP — BUGS B14) |
| Internal ports | auth 5002, school 5003, Consul 8500, PgAdmin 5050, auth-db 5433, school-db 5434 — bound to 127.0.0.1 |
| Environment | `ASPNETCORE_ENVIRONMENT=Production`, `Swagger__Enabled=true` (set in the override) |
| CI/CD | none — deploys are manual over SSH |

The SSH address is kept outside the repository (`docs/server_key.md`, git-ignored).

### Override file shape

```yaml
name: school-management
x-dotnet-env: &dotnet-env
  ASPNETCORE_ENVIRONMENT: Production
  Swagger__Enabled: "true"
services:
  api-gateway:    { ports: !override ["5001:8080"],            environment: { <<: *dotnet-env } }
  auth-service:   { ports: !override ["127.0.0.1:5002:8080"],  environment: { <<: *dotnet-env } }
  school-service: { ports: !override ["127.0.0.1:5003:8080"],  environment: { <<: *dotnet-env } }
  auth-db:        { ports: !override ["127.0.0.1:5433:5432"] }
  school-db:      { ports: !override ["127.0.0.1:5434:5432"] }
  consul:         { ports: !override ["127.0.0.1:8500:8500"] }
  pgadmin:        { ports: !override ["127.0.0.1:5050:80"] }
  admin-web:      { ports: !override ["3100:3000"], build: { args: { API_URL: "http://api-gateway:8080" } } }
  web-app:        { ports: !override ["3200:80"],   build: { args: { API_BASE_URL: "" } } }
```

## Release checklist

Before:
1. All checks green locally: `dotnet build` + `dotnet test` for each service, `npm run lint && npm run build`
   in `admin-web`, `flutter analyze && flutter test` in `frontend`.
2. Note the currently deployed commit: `git -C ~/apps/school-management rev-parse --short HEAD` → write it in the release notes (rollback target).
3. **Back up both databases** (see below) and check the dump files are non-empty.
4. Read the migration list for this release. Any schema change must come as an EF migration with a working `Down`.
5. **First release with school-service migrations** (2026-09): on start the service adds `__EFMigrationsHistory` to
   school_db and marks the existing migrations as applied (no table is changed). Rolling back the code afterwards is
   safe — the old code ignores that table.
6. Outside Development both .NET services refuse to start unless `JWT_SECRET` is at least 32 bytes and is not the
   development fallback. Check without printing the value:
   `grep -cE '^JWT_SECRET=.{32,}$' backend/.env` → must print `1`.

Deploy:
```bash
cd ~/apps/school-management
git fetch origin-canonical && git checkout main && git pull --ff-only origin-canonical main
cd backend
docker compose build                  # build first, so a failed build doesn't stop the running stack
docker compose up -d                  # recreates only changed services
```

After:
```bash
docker compose ps                                        # all "Up"
curl -fsS http://127.0.0.1:5001/health                   # gateway
curl -fsS http://127.0.0.1:5002/health                   # auth
curl -fsS http://127.0.0.1:5003/health                   # school
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3100/login   # admin-web → 200
docker compose logs --since 10m auth-service school-service api-gateway | grep -iE 'error|exception|fail'
```
Then run the read-only end-to-end check from any machine (it signs in as admin, a teacher and a student and
reads grades, report cards, rosters and notifications; it changes no school data):
```bash
SMOKE_PASSWORD='<admin/teacher/student password>' python3 scripts/smoke_test.py --base http://<host>:3100
```
Log in to admin-web as an admin and open Students, Grades and Attendance once.

## Backup

```bash
ts=$(date +%F-%H%M); dir=~/backups/school-management; mkdir -p "$dir"
cd ~/apps/school-management/backend
docker compose exec -T auth-db   pg_dump -U auth_user   -Fc auth_db   > "$dir/auth_db-$ts.dump"
docker compose exec -T school-db pg_dump -U school_user -Fc school_db > "$dir/school_db-$ts.dump"
ls -lh "$dir" | tail -2
```
The same steps are scripted in `scripts/backup-db.sh` (custom-format dumps, checks the `PGDMP` header, keeps the newest
14 of each database, files `600`, directory `700`). Suggested cron (daily 03:15, needs the owner's approval to install):
```
15 3 * * * $HOME/apps/school-management/scripts/backup-db.sh >> $HOME/backups/school-management/backup.log 2>&1
```
Copy the dumps off the server as well — a backup on the same disk does not survive losing the VM.

Restore (only after a failed release, and only with the owner's approval):
```bash
docker compose exec -T school-db pg_restore -U school_user -d school_db --clean --if-exists < school_db-<ts>.dump
```

## Rollback plan

| Failure | Action |
|---|---|
| New containers fail to start / health checks fail, no schema change in the release | `git checkout <previous-commit>` → `docker compose build && docker compose up -d` |
| Release contained an EF migration | Roll the schema back first with the migration's `Down` (`dotnet ef migrations script <new> <previous>` reviewed and applied, or `efbundle <previous>`), then roll back the code as above |
| Data damaged | Stop the affected service, restore the dump taken before the release, start the previous version |

Notes for the first release from `ai/improvements` (from `b4db3c3`): the new tables and columns are ignored by the old
code, so rolling back the code alone is safe, with one visible effect — `HashRefreshTokens` stores refresh tokens hashed,
which the old code cannot match, so everyone signs in again after a rollback. `AddMessaging` needs PostgreSQL 15 or newer
(production runs 16).

## Local development

```bash
cd backend && cp .env.example .env    # set JWT_SECRET to a random 32+ char value
docker compose up --build             # gateway :5001, admin-web :3000, Flutter web :3200
```
Needs ~6 GB of free disk for images and build layers.

Without Docker, `scripts/local-stack.sh start` runs PostgreSQL 16, both services, the gateway and admin-web natively
(fresh, migrated and seeded databases in `.local-stack/`), then `python3 scripts/smoke_test.py --write` checks the main
flows end to end; `scripts/local-stack.sh stop` shuts it all down.

## Planned improvements
- HTTPS behind the host's existing nginx + certbot, with ports bound to 127.0.0.1 (BUGS B14, QUESTIONS Q3).
- Swagger off in production.
- Scheduled `pg_dump` (cron) with rotation (BUGS B15).
- GitHub Actions for build/test on every push; deploy stays manual until the owner decides otherwise.
