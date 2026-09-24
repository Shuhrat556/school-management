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
| consul | image `hashicorp/consul` | Service registry; services self-register on start. The gateway currently routes by static config (see "Known gaps") |
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

## Known gaps

Tracked with IDs in [`docs/ai/BUGS.md`](ai/BUGS.md). The most important:
school-service endpoints check only that a user is signed in, not the role (B1);
school-db schema is created with `EnsureCreated()` plus hand-written SQL instead of migrations (B11);
the gateway's Consul discovery result is computed and discarded (B12).
