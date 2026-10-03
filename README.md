# School Management System

A full-stack school management platform built with **.NET microservices**, a **Flutter** mobile app, and a **Next.js** admin panel — all orchestrated with **Docker Compose**.

---

## Tech Stack

| Layer             | Technology                                         |
| ----------------- | -------------------------------------------------- |
| API Gateway       | ASP.NET Core 10 + YARP reverse proxy (static routes) |
| Auth Service      | ASP.NET Core 10 + EF Core + PostgreSQL + JWT       |
| School Service    | ASP.NET Core 10 + EF Core + PostgreSQL             |
| Service Discovery | HashiCorp Consul 1.22                              |
| Mobile App        | Flutter 3.9+ / Dart                                |
| Admin Panel       | Next.js 16 + React 19 + Tailwind CSS               |
| Databases         | PostgreSQL 16 (two isolated instances)             |
| Containerization  | Docker + Docker Compose                            |

---

## Architecture

```
┌─────────────┐     ┌──────────────┐
│  Flutter App │     │  Admin Panel  │
│   (Mobile)   │     │  (Next.js)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       ▼                    ▼
   ┌────────────────────────────┐
   │     API Gateway  :5001     │
   │      (YARP + Consul)       │
   └─────────┬──────────┬───────┘
             │          │
     ┌───────▼───┐  ┌───▼───────────┐
     │   Auth    │  │    School     │
     │  Service  │  │   Service     │
     │  :5002    │  │   :5003       │
     └─────┬─────┘  └──────┬────────┘
           │               │
     ┌─────▼─────┐  ┌──────▼────────┐
     │  auth-db  │  │   school-db   │
     │  :5433    │  │   :5434       │
     └───────────┘  └───────────────┘
             │          │
         ┌───▼──────────▼───┐
         │      Consul      │
         │      :8500       │
         └──────────────────┘
```

| Container      | Port | Purpose                           |
| -------------- | ---- | --------------------------------- |
| api-gateway    | 5001 | Single entry point (YARP proxy)   |
| auth-service   | 5002 | Auth, JWT, OAuth, email flows     |
| school-service | 5003 | School data, roles, CRUD          |
| auth-db        | 5433 | PostgreSQL — auth data            |
| school-db      | 5434 | PostgreSQL — school data          |
| consul         | 8500 | Service discovery & health checks |
| pgadmin        | 5050 | Database browser UI               |
| admin-web      | 3000 | Next.js admin dashboard           |
| web-app        | 3200 | Flutter app built for the web     |

---

## Features

### Authentication & Authorization

- Email/password login; accounts are created by an admin (self-registration is off by default, `Registration__Enabled=true` re-opens it)
- Email verification with code
- Password reset via email code
- Google and Facebook OAuth; a signed-in user links Google/Facebook to their account (needed for Facebook sign-in)
- JWT access tokens with refresh token rotation; reusing a rotated refresh token ends all of the user's sessions
- Rate-limited sign-in, account lockout after five wrong passwords, passwords of 8–200 characters
- Four roles: **Admin**, **Teacher**, **Student**, **Parent**

### Student Management

- Full CRUD with pagination
- Classroom enrollment / unenrollment
- Profile linked to auth account

### Teacher Management

- Full CRUD with pagination
- Subject assignment (many-to-many)
- Specialization tracking

### Classroom Management

- Create classrooms by grade and academic year
- Assign homeroom teacher
- Enroll / unenroll students

### Subjects & Curriculum

- Subject CRUD
- Teacher-to-subject assignment

### Grades & Scores

- Score entry (0–100) per student, subject, and semester (saving again updates the grade)
- Audit trail: who set, changed or removed each grade, and when (admin "Grade history" page)
- Report card per student and semester: scores, letters, GPA, attendance rate; CSV download and a printable page

### Homework & Materials

- Class materials and assignments with an optional due date; teachers see how many students handed work in
- Students hand in a link or a file name; deleting an assignment keeps the students' work

### Leave Requests

- A student or a parent asks to excuse an absence; teachers and admins approve or reject it and the family is notified

### Notifications & Announcements

- In-app notifications to students and parents for new grades, absences, class announcements and leave decisions
- Announcements are school-wide or per class; students and parents only see their own classes'

### Attendance

- Bulk mark attendance per classroom per date
- Status: Present, Absent, Late
- Student attendance history

### Schedules

- Create schedules per classroom, subject, and teacher
- View by classroom or by teacher
- Day and time slot management

### Admin Panel (Next.js)

- Dashboard with stats (teachers, classrooms, students, subjects)
- Full CRUD for all entities
- User account management with inline role picker
- Profile sync across auth and school databases
- Consul service health monitoring

### Parent Portal (web)

- Admins link parent accounts (role Parent) to students on the student page
- Parents sign in to the web app and see each child's grades, GPA, attendance rate, recent absences and report card,
  get notifications and send leave requests

### Mobile App (Flutter)

- Role-based dashboards (Student / Teacher); each login screen accepts only its own role
- Teacher: manage classes, take attendance, enter grades, assign homework, add subjects, send class announcements,
  approve leave requests, look up students' parents
- Student: grades, attendance, timetable, homework hand-in, notifications, leave requests, announcements
- Link Google/Facebook under Settings → Security & Login
- Messaging is not available yet (planned); the Messages tab points to announcements and notifications
- Profile editing for both roles
- Animated splash screen with auto-login via stored tokens

---

## Default Accounts

All seed accounts use password: **`Password123!`**

| Role    | Email addresses                                                     |
| ------- | ------------------------------------------------------------------- |
| Admin   | `admin@school.com`                                                  |
| Teacher | `teacher1@school.com`, `teacher2@school.com`, `teacher3@school.com` |
| Student | `student1@school.com` … `student45@school.com`                      |
| Parent  | `parent1@school.com`, `parent2@school.com`                          |

Parent accounts start with no children: an admin links them on the student's page in admin-web (Students → a student →
Parents), after which the parent portal, notifications and leave requests work for that child.

**Teacher → class mapping:**

| Teacher  | Grade | Classes          |
| -------- | ----- | ---------------- |
| teacher1 | 10    | 10-A, 10-B, 10-C |
| teacher2 | 11    | 11-A, 11-B, 11-C |
| teacher3 | 12    | 12-A, 12-B, 12-C |

Each class has **15 students**.

---

## Documentation

| Document | Contents |
| -------- | -------- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Services, layers, auth flow, configuration |
| [docs/API.md](docs/API.md) | Every endpoint with its access level |
| [docs/DATABASE.md](docs/DATABASE.md) | Tables, relations, delete behaviour, backups |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Production setup, release checklist, backup and rollback |
| [docs/ai/](docs/ai/) | Working notes: plan, progress, known bugs, research |

---

## Quick Start

### Prerequisites

| Tool           | Required for | Download                                       |
| -------------- | ------------ | ---------------------------------------------- |
| Docker Desktop | Backend      | https://www.docker.com/products/docker-desktop |
| Flutter SDK    | Mobile app   | https://docs.flutter.dev/get-started/install   |
| Git            | Cloning      | https://git-scm.com                            |

Minimum: **8 GB RAM**, **20 GB free disk**.

### 1. Clone

```bash
git clone https://github.com/ToLa-Web/school-management.git
cd school-management
```

### 2. Start the backend

```bash
cd backend
cp .env.example .env      # then set JWT_SECRET to a random 32+ character value
docker compose up --build
```

First run takes 3–5 minutes. Wait until all services log `Application started`.

### 3. Run the Flutter app

```bash
cd frontend
flutter pub get
flutter run
```

**Physical device?** Pass your computer's IP at run time (no code change needed):

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5001
```

Your phone and computer must be on the same Wi-Fi network.

### 4. Verify

| URL                           | What                                      |
| ----------------------------- | ----------------------------------------- |
| http://localhost:5001/swagger | Swagger — Auth + School APIs in one UI    |
| http://localhost:8500         | Consul dashboard                          |
| http://localhost:5050         | PgAdmin (`PGADMIN_EMAIL` / `PGADMIN_PASSWORD` from `.env`) |
| http://localhost:3000         | Admin panel                               |
| http://localhost:3200         | Flutter app (web build)                   |

Log in with `admin@school.com` / `Password123!`

---

## Project Structure

```
school-management/
├── backend/
│   ├── docker-compose.yml
│   └── services/
│       ├── api-gateway/              # YARP reverse proxy
│       │   └── ApiGateway/
│       ├── auth-service/             # JWT, OAuth, email, user management
│       │   └── AuthService/
│       │       ├── AuthService.API/
│       │       ├── AuthService.Application/
│       │       ├── AuthService.Domain/
│       │       └── AuthService.Infrastructure/
│       └── school-service/           # Students, teachers, classrooms, grades
│           └── SchoolService/
│               ├── SchoolService.API/
│               ├── SchoolService.Application/
│               ├── SchoolService.Domain/
│               └── SchoolService.Infrastructure/
├── frontend/                         # Flutter mobile app
│   └── lib/
│       ├── main.dart
│       ├── Login/                    # Splash, role select, login, register, forgot password
│       ├── Screen/
│       │   ├── Dashboard/            # Student & teacher dashboards
│       │   ├── Role_STUDENT/         # All student-facing screens
│       │   ├── Role_TEACHER/         # All teacher-facing screens
│       │   ├── Edit-Profile/         # Profile editing
│       │   └── setting/              # Settings
│       ├── services/                 # API client, config, models, OAuth
│       ├── routes/                   # Named route definitions
│       ├── model/                    # Data models
│       ├── constants/                # Colors, typography, responsive utils
│       └── widgets/                  # Shared widgets
├── admin-web/                        # Next.js admin panel
│   └── src/
│       ├── app/
│       │   ├── dashboard/
│       │   ├── students/
│       │   ├── teachers/
│       │   ├── classrooms/
│       │   ├── subjects/
│       │   ├── grades/
│       │   ├── attendance/
│       │   ├── schedules/
│       │   ├── users/
│       │   ├── health/
│       │   └── login/
│       ├── components/               # Sidebar
│       └── lib/                      # API client, auth helpers
├── SETUP.md                          # Detailed setup instructions
├── COMMANDS.md                       # Docker & Flutter command reference
└── make-zip.ps1                      # Package project for sharing
```

---

## API Endpoints

### Auth Service (`/api/auth/`)

| Method | Endpoint                           | Description                    |
| ------ | ---------------------------------- | ------------------------------ |
| POST   | `/register`                        | Self sign-up (disabled by default) |
| POST   | `/authenticate`                    | Login (returns JWT + refresh)  |
| POST   | `/refresh`                         | Refresh access token           |
| POST   | `/logout`                          | Revoke refresh token           |
| POST   | `/request-email-verification-code` | Send email verification code   |
| POST   | `/verify-email`                    | Verify email with code         |
| POST   | `/request-password-reset`          | Send password reset code       |
| POST   | `/reset-password`                  | Reset password with code       |
| POST   | `/oauth/google`                    | Google OAuth login             |
| POST   | `/oauth/facebook`                  | Facebook OAuth login           |
| POST   | `/validate`                        | Validate a JWT (inter-service) |
| GET    | `/user/{userId}`                   | Get user info (inter-service)  |
| GET    | `/admin/users`                     | List all users (admin)         |
| POST   | `/admin/users`                     | Create user with role (admin)  |
| DELETE | `/admin/users/{id}`                | Delete user (admin)            |
| PATCH  | `/admin/users/{id}/role`           | Update user role (admin)       |

### School Service (`/api/school/`)

| Method | Endpoint                        | Description                        |
| ------ | ------------------------------- | ---------------------------------- |
| GET    | `/students`                     | List students (paginated)          |
| POST   | `/students`                     | Create student                     |
| GET    | `/students/{id}`                | Get student by ID                  |
| PUT    | `/students/{id}`                | Update student                     |
| DELETE | `/students/{id}`                | Delete student                     |
| GET    | `/teachers`                     | List teachers (paginated)          |
| POST   | `/teachers`                     | Create teacher                     |
| PUT    | `/teachers/{id}`                | Update teacher                     |
| GET    | `/classrooms`                   | List classrooms                    |
| POST   | `/classrooms`                   | Create classroom                   |
| GET    | `/classrooms/{id}`              | Classroom detail with students     |
| POST   | `/classrooms/{id}/enroll`       | Enroll student in classroom        |
| POST   | `/classrooms/{id}/unenroll`     | Remove student from classroom      |
| GET    | `/subjects`                     | List subjects                      |
| POST   | `/subjects`                     | Create subject                     |
| POST   | `/subjects/{id}/assign-teacher` | Assign teacher to subject          |
| POST   | `/subjects/{id}/remove-teacher` | Remove teacher from subject        |
| GET    | `/grades`                       | List grades (filterable)           |
| POST   | `/grades`                       | Create grade                       |
| PUT    | `/grades/{id}`                  | Update grade                       |
| DELETE | `/grades/{id}`                  | Delete grade                       |
| GET    | `/attendance`                   | Get attendance by classroom + date |
| POST   | `/attendance`                   | Bulk mark attendance               |
| GET    | `/attendance/student/{id}`      | Student attendance history         |
| GET    | `/schedules/classroom/{id}`     | Schedule by classroom              |
| GET    | `/schedules/teacher/{id}`       | Schedule by teacher                |
| POST   | `/schedules`                    | Create schedule entry              |
| DELETE | `/schedules/{id}`               | Delete schedule entry              |

Full interactive docs at **http://localhost:5001/swagger** after starting the backend.

---

## Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill it in — `.env` is git-ignored and must never be committed.

| Variable                     | Purpose                                              |
| ---------------------------- | ---------------------------------------------------- |
| `JWT_SECRET`                 | Signs all JWT tokens (random, 32+ characters; the same value is used by auth and school services) |
| `EMAILSETTINGS_FROM_EMAIL`, `EMAILSETTINGS_SMTP_USER` | Gmail account that sends verification / reset codes |
| `EMAILSETTINGS_APP_PASSWORD` | Gmail App Password for that account                  |
| `PGADMIN_EMAIL`, `PGADMIN_PASSWORD` | PgAdmin login                                 |

To send email from your own Gmail, create a [Gmail App Password](https://support.google.com/accounts/answer/185833).

---

## Useful Commands

```bash
# Start backend (background)
cd backend && docker compose up -d

# Rebuild after code changes
docker compose up -d --build

# View logs
docker compose logs -f

# Reset everything (wipe data)
docker compose down -v && docker compose up --build

# Flutter
cd frontend
flutter pub get
flutter run
flutter build apk
```

Full command reference: [COMMANDS.md](./COMMANDS.md) | Detailed setup: [SETUP.md](./SETUP.md)

---

## Troubleshooting

| Symptom                       | Fix                                                      |
| ----------------------------- | -------------------------------------------------------- |
| `docker compose up` fails     | Make sure Docker Desktop is running                      |
| Port 5001 in use              | Run `docker compose down` first                          |
| "Connection refused" on phone | Wrong `API_BASE_URL` or phone not on same Wi-Fi |
| 401 Unauthorized              | Use seed credentials or register a new account           |
| Emails not sending            | Check `EMAILSETTINGS_APP_PASSWORD` in `.env`             |
| Want a fresh start            | `docker compose down -v && docker compose up --build`    |

---

## License

This project is for educational purposes.
