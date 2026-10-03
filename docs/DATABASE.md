# Database

Two PostgreSQL 16 databases, one per service. There are no cross-database foreign keys; the link between an
account and a school profile is the `AuthUserId` column on `Students` / `Teachers`.

| Database | Owner service | Schema management | Size on the server (2026-09-25) |
|---|---|---|---|
| `auth_db` | auth-service | EF Core migrations, applied at startup (`Database.Migrate()`) | ~8 MB, 56 users |
| `school_db` | school-service | EF Core migrations, applied at startup; databases created earlier with `EnsureCreated()` are baselined once (see below) | ~9 MB, mostly seed data |

## auth_db

| Table | Key columns | Notes |
|---|---|---|
| `Users` | `Id`, `Email`, `NormalizedEmail` (unique), `Username` (full name), `PasswordHash` (PBKDF2-SHA256, 100k iterations; null for OAuth-only), `Role` (1 Teacher, 2 Student, 3 Parent, 4 Admin), `IsEmailVerified`, `IsActive`, `LastLoginAt` | Also holds HMAC hashes, expiry and lockout counters for email-verification and password-reset codes |
| `RefreshTokens` | `Token` (indexed), `UserId` → Users, `ExpiresAt`, `RevokedAt` | `Token` holds base64(SHA-256) of the issued token, never the token itself |
| `ExternalLogins` | `UserId` → Users, `Provider` (Google/Facebook), `ProviderUserId` | unique per provider |

`Users` also keeps `FailedLoginAttempts` and `LoginLockoutUntil` for the sign-in lockout.

Migrations: `AuthService.Infrastructure/Migrations` — `InitialCreate`, `AddEmailVerificationFields`,
`AddPasswordResetFields`, `AddExternalLogins`, `AddLoginLockout` (2 nullable/defaulted columns; `Down` drops them),
`HashRefreshTokens` (hashes existing tokens in place + index; `Down` drops the index — hashed rows stay, users sign in again).

## school_db

```
Departments 1─* Subjects 1─* Classrooms *─1 Teachers
     │               │            │  └─*1 Rooms
     *               *            ├─* StudentClassrooms *─1 Students
TeacherDepartments TeacherSubjects├─* Schedules
     *               *            ├─* Materials 1─* Submissions *─1 Students
  Teachers        Teachers        ├─* Announcements (ClassroomId nullable, AuthorTeacherId)
                                  ├─* Attendances *─1 Students   (also → Schedules)
                                  └─* StudentGrades *─1 Students (also → Subjects)
```

| Table | Purpose | Important columns |
|---|---|---|
| `Students` | Student profile | names, `Gender`, `DateOfBirth`, `Phone`, `Address`, `Email`, `IsActive`, `DeletedAt` (unused), `AuthUserId` (unique when not null) |
| `Teachers` | Teacher profile | as above + `Specialization`, `HireDate` |
| `Departments` | Academic department | `Name`, `Description`, `IsActive` |
| `TeacherDepartments` | Teacher ↔ department (M:N) | composite PK |
| `Subjects` | Course / subject | `SubjectName`, `Code`, `Category`, `Description`, `DepartmentId` |
| `TeacherSubjects` | Teacher ↔ subject (M:N) | composite PK |
| `Classrooms` | A course section (one subject, one teacher, one room, a term) | `Name`, `Grade` ("Year 1"), `AcademicYear`, `Semester`, `SubjectId`, `TeacherId`, `RoomId` |
| `StudentClassrooms` | Enrolment | `Status`, `EnrolledAt`, `UnenrolledAt` |
| `Rooms` | Physical room | `Name`, `Location`, `Capacity`, `Type` |
| `Schedules` | Weekly timetable slot | `ClassroomId`, `SubjectId`, `TeacherId`, `DayOfWeek`, `StartTime`, `EndTime`, `Type` |
| `Attendances` | One mark per student per date | `StudentId`, `ClassroomId`, `ScheduleId`, `Date`, `Status` (1 Present, 2 Absent, 3 Late) |
| `StudentGrades` | Score per student, subject, semester | `Score` (0–100), `Semester`, `GradingMethod`, `ClassroomId` |
| `Announcements` | Teacher announcement, optional classroom | `Title`, `Body`, `PublishedAt` |
| `Materials` | Learning material / assignment in a classroom | `Title`, `Url`, `Type` |
| `Submissions` | Student hand-in for a material | `SubmissionUrl`, `SubmittedAt`, `Grade`, `Feedback` |
| `Notifications` | In-app messages about a student | `StudentId`, `ParentAuthUserId` (null = for the student), `Type` (1 Grade, 2 Attendance, 3 Announcement), `Title`, `Body`, `ReadAt` |
| `GradeChanges` | Append-only grade audit trail, no foreign keys (outlives the grade) | `GradeId`, `StudentId`, `SubjectId`, `Semester`, `Action` (1 Created, 2 Updated, 3 Deleted), `OldScore`, `NewScore`, `ChangedByAuthUserId`, `ChangedByName`, `ChangedByRole`, `ChangedAt`; indexes on `GradeId` and `(StudentId, ChangedAt)` |
| `StudentParents` | Parent account ↔ student link (parent portal) | `StudentId`, `ParentAuthUserId` (auth user id), `FullName`, `Email`, `Relationship`; unique per student + parent |

### Migrations and the legacy baseline
Until 2026-09 school_db was created with `EnsureCreated()` plus hand-written SQL, so those databases have the full schema
but no `__EFMigrationsHistory`. On startup `LegacySchemaBaseline.ApplyAsync` (in `SchoolService.Infrastructure/Data`)
detects such a database (PostgreSQL, `Students` exists, no history table), runs the old idempotent SQL once more and records
every migration up to `20260409091051_Add_Department_Entity_And_Relationships` as applied. `Database.MigrateAsync()` then
applies anything newer. The migration chain was checked to produce exactly the `EnsureCreated()` schema (columns, types,
nullability, indexes, constraints) and the production schema matched it (2026-09-25).

Tests: `MigrationTests` (fresh database, legacy baseline, rolling back every migration) run when `SCHOOL_TEST_POSTGRES`
points at a PostgreSQL server, as in CI.

### Delete behaviour
Deleting a **Student** or **Teacher** through the API is a soft delete: `DeletedAt` is set, `IsActive` becomes false and
the repositories never return the row again. A deleted student's active enrolments are marked `Dropped`; grades,
attendance and submissions stay. The database-level cascades below only matter for rows removed by hand. Deleting a Classroom cascades to schedules, enrolments and materials;
grades and attendance keep the row with `ClassroomId = NULL`. Subjects referenced by grades or schedules cannot be deleted (RESTRICT).

### Indexes and constraints
Every foreign key has an index. Natural keys (migration `AddNaturalKeyIndexes`):
- `StudentGrades (StudentId, SubjectId, Semester)` unique — `POST /grades` updates the existing row instead of adding one;
- `Attendances (StudentId, ClassroomId, Date)` unique — bulk marking updates existing marks;
- `Students` / `Teachers`: `lower(Email)` unique among rows with an email that aren't deleted (raw SQL in the migration, not in the EF model).

Before applying it to a database that may hold duplicates, check (all counts must be 0):
```sql
select count(*) from (select 1 from "StudentGrades" group by "StudentId","SubjectId","Semester" having count(*)>1) d;
select count(*) from (select 1 from "Attendances" group by "StudentId","ClassroomId","Date" having count(*)>1) d;
select count(*) from (select 1 from "Students" where "Email" is not null group by lower("Email") having count(*)>1) d;
select count(*) from (select 1 from "Teachers" where "Email" is not null group by lower("Email") having count(*)>1) d;
```
Production had none on 2026-09-25.

## Local access

```bash
cd backend && docker compose up -d auth-db school-db
psql "host=localhost port=5433 dbname=auth_db user=auth_user"      # password: see docker-compose.yml
psql "host=localhost port=5434 dbname=school_db user=school_user"
```

PgAdmin runs on http://localhost:5050 with both servers pre-registered (`backend/pgadmin-servers.json`).

## Seed data

Both services seed on first start (`DataSeeder`): 1 admin, teachers, 45+ students, 2 parents, departments,
12 subjects/classrooms, rooms, schedules, grades and attendance. Accounts and the shared dev password are listed in the README.

## Backups

None are configured on the server yet (BUGS B15). The manual procedure is in [DEPLOYMENT.md](DEPLOYMENT.md#backup).
