# Architecture

School Management System is a set of small .NET services behind one API gateway, with two clients:
a Next.js web app (admin, teacher and student portals) and a Flutter app (mobile + web build).

## Components

```
 Browser ── admin-web (Next.js :3000) ──┐  rewrites /api/* ──┐
 Browser ── web-app (Flutter web, nginx :3200) ─ /api/* ──────┤
 Phone  ── Flutter app ─────────────── API_BASE_URL ──────────┤
                                                              ▼
                                   api-gateway (YARP :5001 → container :8080)
                                     │ /api/auth/**                    │ /api/school/**, /api/announcements/**,
                                     ▼                                 ▼ /api/rooms|materials|submissions|servicehealth/**
                           auth-service (:5002)              school-service (:5003)
                                     │                                 │
                               auth-db (PG 16)                   school-db (PG 16)
                                     └──────── register ── consul (:8500) ── register ┘
```

| Component | Path | Responsibility |
|---|---|---|
| api-gateway | `backend/services/api-gateway/ApiGateway` | YARP reverse proxy (static routes in `appsettings.json`), one Swagger UI that proxies both services' OpenAPI documents, global error shape for upstream failures |
| auth-service | `backend/services/auth-service/AuthService` | Accounts, login, JWT access + refresh tokens, email verification, password reset, Google/Facebook sign-in, admin user management |
| school-service | `backend/services/school-service/SchoolService` | Students, teachers, departments, subjects, classrooms (course sections), enrolment, rooms, schedules, attendance, grades, announcements, materials, submissions |
| consul | image `hashicorp/consul` | Service registry; services self-register on start and school-service reads it for the admin health page. The gateway routes by the static YARP config in its `appsettings.json` |
| admin-web | `admin-web/` | Next.js App Router, plain JS + Tailwind. Route groups `/admin/*`, `/teacher/*`, `/student/*`. Calls the gateway through Next.js rewrites |
| web-app / Flutter | `frontend/` | Flutter app (student + teacher dashboards). The web build is served by nginx, which proxies `/api/` to the gateway |

## Layering inside each .NET service

Clean-architecture style, one project per layer:

- `*.Domain` — entities with behaviour (private setters, methods such as `Student.Deactivate()`), enums.
- `*.Application` — DTOs, service interfaces and services (business rules), application exceptions.
- `*.Infrastructure` — EF Core `DbContext`, entity configurations, repositories, migrations, seeders, SMTP/OAuth adapters.
- `*.API` — ASP.NET Core controllers, `Program.cs` composition root, exception middleware.

Errors are thrown as typed application exceptions (`NotFoundException`, `DuplicateEmailException`, …) and
translated by `GlobalExceptionMiddleware` into `{ message, code, details, traceId, statusCode, path }`.

## Authentication and authorization

1. `POST /api/auth/authenticate` returns an HS256 JWT (60 min) and a refresh token (7 days, rotated on every use).
2. Claims: `sub` (auth user id), `email`, `name`, `role` (`Admin`, `Teacher`, `Student`, `Parent`), `jti`.
3. school-service validates the same token itself (shared `JWT_SECRET`, issuer `AuthService`,
   audience `AuthServiceClients`); it does not call auth-service per request.
4. Auth users and school profiles live in different databases. They are linked by
   `Students.AuthUserId` / `Teachers.AuthUserId`; admin-web keeps them in sync through
   `POST /api/school/admin/sync-profile`.
5. Self-registration is disabled (`Registration:Enabled=false`); admins create accounts.

## Data flow example — teacher records a grade

admin-web `/teacher/grades` → `POST /api/school/grades` (Next.js rewrite) → gateway `school-route` →
`GradesController.Create` → `GradeService` (validates student/subject, score 0–100) → `GradeRepository` → `StudentGrades` table.

## Configuration

| Setting | Where | Notes |
|---|---|---|
| `JWT_SECRET` | `backend/.env` → `Jwt__Secret` for both services | must be identical in auth and school |
| `ConnectionStrings__AuthDb` / `__SchoolDb` | `docker-compose.yml` | |
| `EmailSettings__*` | `.env` | Gmail SMTP for codes |
| `Registration__Enabled` | env | `false` by default |
| `Swagger__Enabled` | env | Swagger is always on in Development |
| `Cors__AllowedOrigins__0..n` (gateway) | env | Cross-origin browser access outside Development; empty by default — admin-web and web-app are same-origin |
| `RateLimiting__<policy>__PermitLimit` (auth) | env | Per-IP limits, see API.md |
| `API_URL` (admin-web) | build arg + env | baked into Next.js rewrites at build time |
| `API_BASE_URL` (Flutter) | `--dart-define` | empty = same origin (web build behind nginx) |

## Access rules

- school-service: writes need `Admin` or `Teacher`, deletes and most structural changes need `Admin`; a student reads
  and edits only their own profile and reads only their own grades, attendance and submissions (`ProfileAccess`).
  A parent reads the records of linked children. Class-scoped content (class details, materials, class announcements)
  is limited to the classes a student is in, or a parent's children are in (`ProfileAccess.GetVisibleClassroomIdsAsync`);
  rosters shown to them carry names only.
- Who changed what: grade changes are recorded in `GradeChanges`; leave decisions record the reviewer.
- auth-service: anonymous endpoints are rate-limited per client IP; five wrong passwords lock an account for five minutes.
- Services trust `X-Forwarded-For` only from private networks (the gateway and the web front ends).

## Known gaps

Tracked with IDs in [`docs/ai/BUGS.md`](ai/BUGS.md). Open at the time of writing: production runs over plain HTTP
without backups (B14, B15 — need the owner's go-ahead), and old secrets are in git history (B5). Not built yet:
messaging between families and teachers (PLAN F9), file uploads (hand-ins are links or file names), push notifications.
