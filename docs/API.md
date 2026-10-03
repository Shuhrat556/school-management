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
| POST | `/change-password` | user | Own account only (`userId` must equal the token's `sub`); ends every other session |
| POST | `/oauth/google` | anon | `{idToken}` — existing accounts only while registration is off; bad token → 401 `INVALID_EXTERNAL_TOKEN` |
| POST | `/oauth/facebook` | anon | `{accessToken}` — only accounts that linked Facebook (no email matching) |
| GET | `/logins` | user | `{hasPassword, logins: [{provider, linkedAt}]}` |
| POST | `/logins/{google\|facebook}` | user | `{token}` (Google ID token / Facebook access token): link it to the caller. 409 `EXTERNAL_LOGIN_IN_USE` (linked to someone else), `PROVIDER_ALREADY_LINKED` (another account of that provider); same identity again → 200 |
| DELETE | `/logins/{google\|facebook}` | user | 204; 404 if not linked; 409 `LAST_SIGN_IN_METHOD` when it is the only way to sign in (no password) |
| POST | `/validate` | anon | `{token}` → `{valid, userId, email}` (service-to-service) |
| GET | `/user/{userId}` | user | Basic user info |
| GET | `/admin/users` | Admin | All accounts |
| POST | `/admin/users` | Admin | Create account with role (email pre-verified) |
| DELETE | `/admin/users/{id}` | Admin | Delete account |
| PATCH | `/admin/users/{id}/role` | Admin | `{role}` |

Roles (numeric in responses): `Teacher=1`, `Student=2`, `Parent=3`, `Admin=4`.

Refresh tokens rotate on every `refresh`; presenting an already rotated token more than 30 s later revokes all of the user's sessions (D14).

Rate limits per client IP (429 `TOO_MANY_REQUESTS` with `Retry-After`): `authenticate`, `oauth/*` and `POST logins/*` 60/min;
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
`students` in `GET {id}` is the current roster (active enrolments only). Unenrolling marks the enrolment `Dropped` (404 if the
student is not in the class); enrolling a student who left reactivates it, enrolling an active student again → 409.

### Rooms — `/rooms`
GET list, GET `{id}` — user. POST, PUT `{id}`, DELETE `{id}` — Admin.
(The gateway also forwards the legacy `/api/rooms/**` path.)

### Schedules — `/schedules`
GET `?classroomId=` or `?teacherId=` (one is required), GET `{id}` — user. POST, PUT `{id}`, DELETE `{id}` — Staff.
POST/PUT → 409 `SCHEDULE_CONFLICT` when the new time overlaps another session on the same day of the same teacher, the same
classroom, or the classroom's room if it is a `Classroom` or `Lab` room (a gym or auditorium may host several classes).
Back-to-back sessions (one ends when the next starts) are fine. `endTime` ≤ `startTime` → 400, unknown teacher → 404.

### Attendance — `/attendance`
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/attendance?classroomId=&date=` | Staff | Classroom sheet for a date |
| GET | `/attendance/{studentId}/history` | Staff, own | One student's history |
| POST | `/attendance/mark` | Staff | Bulk mark a classroom for a date; status `Present=1`, `Absent=2`, `Late=3`. A new mark needs an active enrolment in the classroom (otherwise 400 naming the students, nothing saved); an existing mark can still be corrected after the student left |

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

### Report card — `/students/{id}/report-card`
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/students/{id}/report-card?semester=&from=&to=` | Staff, own, linked parent | Grades of one semester (all when omitted) and attendance between `from` and `to` (`yyyy-MM-dd`, open when omitted; `from` > `to` → 400) |
| GET | `/students/{id}/report-card/csv?semester=&from=&to=` | same | The same card as a UTF-8 CSV download (`report-card-<name>-<semester>.csv`) |

JSON: `{studentId, studentName, semester, from, to, generatedAt, subjects: [{subjectId, subjectName, semester, classroomName, score,
letter, gradePoints}], averageScore, gpa, attendance: {total, present, absent, late, rate}}`. Letters A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, else F;
grade points on a 4.0 scale (93 → 4.0 … 60 → 0.7), the same scale as the web portal. `gpa` is the mean of grade points, `rate` = present ÷ all
marks × 100 (late is not present); both null when there is nothing to count. CSV cells starting with `= + - @` get a leading `'`.

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
