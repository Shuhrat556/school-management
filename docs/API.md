# API reference

All clients call the **gateway** (`http://<host>:5001` in Docker; admin-web and the Flutter web build call their own
origin, which proxies `/api/*`). Interactive docs: `/swagger` on the gateway (Auth + School documents).

Authentication: `Authorization: Bearer <accessToken>` from `POST /api/auth/authenticate`.
Auth column: **anon** = no token, **user** = any signed-in user, **Staff** = `Admin` or `Teacher`, **Admin** = `Admin` only,
**own** = a student/teacher acting on their own profile.

Error body (both services):

```json
{ "message": "...", "code": "NOT_FOUND", "details": "...", "traceId": "...", "statusCode": 404, "path": "/api/..." }
```

## Auth service — `/api/auth`

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/register` | anon | Self sign-up — returns 400 while `Registration:Enabled=false` (default) |
| POST | `/authenticate` | anon | `{email, password}` → `{userId, firstName, lastName, email, role, userRole, token, refreshToken, …}`. 5 wrong passwords in a row lock the account for 5 min → 429 `ACCOUNT_LOCKED` with `Retry-After` |
| POST | `/refresh` | anon | `{refreshToken}` → new token pair (old refresh token revoked) |
| POST | `/logout` | anon | `{refreshToken}` → revokes it |
| POST | `/request-email-verification-code` | anon | Sends a 6-digit code (60 s resend cooldown) |
| POST | `/verify-email` | anon | `{email, code}`; 5 wrong codes → 15 min lockout |
| POST | `/request-password-reset` | anon | Sends a reset code; always 200 (no account enumeration) |
| POST | `/reset-password` | anon | `{email, code, newPassword}`; revokes all refresh tokens |
| POST | `/change-password` | user | Own account only (`userId` must equal the token's `sub`) |
| POST | `/oauth/google` | anon | `{idToken}` — existing accounts only while registration is off |
| POST | `/oauth/facebook` | anon | `{accessToken}` |
| POST | `/validate` | anon | `{token}` → `{valid, userId, email}` (service-to-service) |
| GET | `/user/{userId}` | user | Basic user info |
| GET | `/admin/users` | Admin | All accounts |
| POST | `/admin/users` | Admin | Create account with role (email pre-verified) |
| DELETE | `/admin/users/{id}` | Admin | Delete account |
| PATCH | `/admin/users/{id}/role` | Admin | `{role}` |

Roles (numeric in responses): `Teacher=1`, `Student=2`, `Parent=3`, `Admin=4`.

Rate limits per client IP (429 `TOO_MANY_REQUESTS` with `Retry-After`): `authenticate` and `oauth/*` 60/min;
`request-email-verification-code`, `verify-email`, `request-password-reset`, `reset-password` 20 per 10 min; `refresh` 120/min.

## School service

Base `/api/school` unless noted. Ids are GUIDs.

### Students — `/students`
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/students?page=&pageSize=` | Staff | Paged when `page`/`pageSize` given, otherwise full list |
| GET | `/students/me` | Student | Own profile: linked by `AuthUserId`, or an unlinked profile with the token's email; 404 if none |
| GET | `/students/{id}` | Staff, own | |
| GET | `/students/by-auth-user/{authUserId}` | Staff, own | |
| GET | `/students/{id}/classrooms` | Staff, own | |
| POST | `/students` | Staff | Create |
| PUT | `/students/{id}` | Staff, own | Update; on their own profile a student cannot change `email` or `isActive` |
| DELETE | `/students/{id}` | Admin | Soft delete: the profile disappears from every endpoint and leaves its classes; grades, attendance and submissions are kept |

### Teachers — `/teachers`
GET list (`?page=&pageSize=&departmentId=`), GET `{id}` — user. GET `me` — Teacher (own profile, same lookup as `/students/me`).
POST, DELETE `{id}` (soft delete) — Admin.
PUT `{id}` — Admin, or the teacher on their own profile (`email`, `isActive`, `hireDate` stay unchanged).
POST / DELETE `/teachers/{teacherId}/departments/{departmentId}` — Admin.

### Departments — `/departments`
GET list, GET `{id}`, GET `{id}/detail` — user. POST, PUT `{id}`, DELETE `{id}`,
POST `{departmentId}/assign-teacher/{teacherId}`, DELETE `{departmentId}/remove-teacher/{teacherId}` — Admin.

### Subjects — `/subjects`
GET list, GET `{id}` — user. POST, POST `{id}/assign-teacher` (`{teacherId}`) — Staff.
PUT `{id}`, DELETE `{id}`, DELETE `{id}/remove-teacher/{teacherId}` — Admin.

### Classrooms (course sections) — `/classrooms`
GET list, GET `{id}` (with students) — user. POST, PUT `{id}`, POST `{id}/enroll` (`{studentId}`),
DELETE `{id}/unenroll/{studentId}` — Staff. DELETE `{id}` — Admin.

### Rooms — `/rooms`
GET list, GET `{id}` — user. POST, PUT `{id}`, DELETE `{id}` — Admin.
(The gateway also forwards the legacy `/api/rooms/**` path.)

### Schedules — `/schedules`
GET `?classroomId=` or `?teacherId=` (one is required), GET `{id}` — user. POST, PUT `{id}`, DELETE `{id}` — Staff.

### Attendance — `/attendance`
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/attendance?classroomId=&date=` | Staff | Classroom sheet for a date |
| GET | `/attendance/{studentId}/history` | Staff, own | One student's history |
| POST | `/attendance/mark` | Staff | Bulk mark a classroom for a date; status `Present=1`, `Absent=2`, `Late=3` |

### Grades — `/grades`
GET `?studentId=&subjectId=&semester=`, GET `{id}` — Staff; a student gets only their own grades
(`studentId` defaults to their own, any other id → 403). POST (one grade per student + subject + semester:
201 when created, 200 when it replaced the existing score), PUT `{id}`, DELETE `{id}` — Staff. Score 0–100.

Audit trail (every create, score change and delete is recorded with the caller's auth id, username and role):
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/grades/{id}/history` | Staff | Oldest first; still works after the grade is deleted. 404 only if the grade never existed and has no history |
| GET | `/grades/changes?studentId=&take=` | Admin | School-wide feed, newest first, `take` 1–200 (default 50) |

Each entry: `{id, gradeId, studentId, studentName, subjectId, subjectName, semester, action ("Created"|"Updated"|"Deleted"),
oldScore, newScore, changedByAuthUserId, changedByName, changedByRole, changedAt}`. Re-saving the same score is not recorded.

### Parents
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/students/{id}/parents` | Staff | Parent accounts linked to the student |
| POST | `/students/{id}/parents` | Admin | `{parentAuthUserId, fullName, email?, relationship?}`; linking again updates the details |
| DELETE | `/students/{id}/parents/{parentAuthUserId}` | Admin | |
| GET | `/parents/me/children` | Parent | Linked children (deleted students left out) |

A linked parent can also read the child through `/students/{id}`, `/students/{id}/classrooms`, `/grades?studentId=`
(required for parents), `/attendance/{id}/history` and `/api/submissions/student/{id}`.

### Notifications — `/notifications` (Student, Parent)
| Method | Path | Notes |
|---|---|---|
| GET | `/notifications?unreadOnly=&take=` | Newest first, `take` ≤ 200 (default 50). A student sees their own; a parent sees all their children's |
| GET | `/notifications/unread-count` | `{count}` |
| POST | `/notifications/{id}/read` | 404 if it isn't the caller's |
| POST | `/notifications/read-all` | |

Created automatically for: a new or changed grade, a first absent/late mark for a day, and a class announcement when it is
first published. Each goes to the student and to every linked parent.

### Admin sync — `/admin`
POST `/admin/sync-profile` — Admin. Creates/updates the school profile linked to an auth account.

### Outside `/api/school`
| Base | Endpoints | Auth |
|---|---|---|
| `/api/announcements` | GET (`?classroomId=`), GET `{id}` — user (non-staff see published only); POST — Staff (a teacher is always the author), PUT `{id}`, POST `{id}/publish`, POST `{id}/unpublish`, DELETE `{id}` — Admin or the authoring teacher | |
| `/api/materials` | GET `classroom/{classroomId}` — user; POST, PUT `{id}`, DELETE `{id}` — Staff | |
| `/api/submissions` | GET `material/{materialId}`, PATCH `{id}/grade` (`{grade, feedback}`) — Staff; GET `student/{studentId}` — Staff, own; POST (`{materialId, submissionUrl}`, student taken from the token) — Student; POST `{studentId}/submit` — Student, own id only (legacy) | unknown/inactive material → 404 |
| `/api/servicehealth` | GET `dashboard`, `service/{name}`, `discover/{name}`, `ping`, `test-auth-connection` | Admin |
| `/api/validation` | demo endpoints for service-to-service calls | mixed; not routed by the gateway |

## Health

`GET /health` on every service (gateway, auth, school) → `{ "status": "ok", "service": "<name>" }`.
