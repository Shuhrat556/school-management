# API reference

All clients call the **gateway** (`http://<host>:5001` in Docker; admin-web and the Flutter web build call their own
origin, which proxies `/api/*`). Interactive docs: `/swagger` on the gateway (Auth + School documents).

Authentication: `Authorization: Bearer <accessToken>` from `POST /api/auth/authenticate`.
Auth column: **anon** = no token, **user** = any signed-in user, **Admin** = `Admin` role only.

> Role checks on school-service write endpoints are being added (BUGS B1). Until then "user" means *any* role.

Error body (both services):

```json
{ "message": "...", "code": "NOT_FOUND", "details": "...", "traceId": "...", "statusCode": 404, "path": "/api/..." }
```

## Auth service — `/api/auth`

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/register` | anon | Self sign-up — returns 400 while `Registration:Enabled=false` (default) |
| POST | `/authenticate` | anon | `{email, password}` → `{userId, firstName, lastName, email, role, userRole, token, refreshToken, …}` |
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

## School service

Base `/api/school` unless noted. Ids are GUIDs.

### Students — `/students`
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/students?page=&pageSize=` | user | Paged when `page`/`pageSize` given, otherwise full list |
| GET | `/students/{id}` | user | |
| GET | `/students/by-auth-user/{authUserId}` | user | Profile for a signed-in account |
| GET | `/students/{id}/classrooms` | user | |
| POST | `/students` | user | Create |
| PUT | `/students/{id}` | user | Update |
| DELETE | `/students/{id}` | user | **Hard** delete — cascades to grades, attendance, submissions (BUGS B17) |

### Teachers — `/teachers`
GET list (`?page=&pageSize=&departmentId=`), GET `{id}`, POST, PUT `{id}`, DELETE `{id}` — user.
POST / DELETE `/teachers/{teacherId}/departments/{departmentId}` — Admin.

### Departments — `/departments`
GET list, GET `{id}`, GET `{id}/detail` — user. POST, PUT `{id}`, DELETE `{id}`,
POST `{departmentId}/assign-teacher/{teacherId}`, DELETE `{departmentId}/remove-teacher/{teacherId}` — Admin.

### Subjects — `/subjects`
GET list, GET `{id}`, POST, PUT `{id}`, DELETE `{id}`, POST `{id}/assign-teacher` (`{teacherId}`),
DELETE `{id}/remove-teacher/{teacherId}` — user.

### Classrooms (course sections) — `/classrooms`
GET list, GET `{id}` (with students), POST, PUT `{id}`, DELETE `{id}`,
POST `{id}/enroll` (`{studentId}`), DELETE `{id}/unenroll/{studentId}` — user.

### Rooms — `/rooms`
GET list, GET `{id}` — user. POST, PUT `{id}`, DELETE `{id}` — Admin.
(The gateway also forwards the legacy `/api/rooms/**` path.)

### Schedules — `/schedules`
GET `?classroomId=` or `?teacherId=` (one is required), GET `{id}`, POST, PUT `{id}`, DELETE `{id}` — user.

### Attendance — `/attendance`
| Method | Path | Notes |
|---|---|---|
| GET | `/attendance?classroomId=&date=` | Classroom sheet for a date |
| GET | `/attendance/{studentId}/history` | One student's history |
| POST | `/attendance/mark` | Bulk mark a classroom for a date; status `Present=1`, `Absent=2`, `Late=3` |

### Grades — `/grades`
GET `?studentId=&subjectId=&semester=`, GET `{id}`, POST, PUT `{id}`, DELETE `{id}` — user. Score 0–100.

### Admin sync — `/admin`
POST `/admin/sync-profile` — Admin. Creates/updates the school profile linked to an auth account.

### Outside `/api/school`
| Base | Endpoints | Auth |
|---|---|---|
| `/api/announcements` | GET (`?classroomId=`), GET `{id}`, POST, PUT `{id}`, POST `{id}/publish`, POST `{id}/unpublish`, DELETE `{id}` | user |
| `/api/materials` | GET `classroom/{classroomId}`, POST, PUT `{id}`, DELETE `{id}` | user |
| `/api/submissions` | GET `material/{materialId}`, GET `student/{studentId}`, POST `{studentId}/submit`, PATCH `{id}/grade` | user — currently returns 500 (BUGS B9) |
| `/api/servicehealth` | GET `dashboard`, `service/{name}`, `discover/{name}`, `ping`, `test-auth-connection` | Admin |
| `/api/validation` | demo endpoints for service-to-service calls | mixed; not routed by the gateway |

## Health

`GET /health` on every service (gateway, auth, school) → `{ "status": "ok", "service": "<name>" }`.
