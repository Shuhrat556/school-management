# Commands Reference

All Docker commands run from the `backend/` folder unless stated otherwise.

---

## Backend (Docker)

### Daily use

```bash
docker compose up -d          # start everything in background
docker compose down           # stop everything (data is kept)
docker compose logs -f        # watch live logs (Ctrl+C to exit)
docker compose ps             # check what is running
```

### Rebuild after code changes

```bash
docker compose up -d --build  # rebuild all changed services and restart
```

### Target a single service

```bash
docker compose logs -f auth-service        # logs for one service
docker compose restart school-service      # restart one service
docker compose up -d --build auth-service  # rebuild one service only
```

### Wipe and reset everything

```bash
docker compose down -v        # stop containers AND delete all database data
docker compose up --build     # fresh start — seed data runs again
```

---

## Database

```bash
# PostgreSQL CLI — auth database
docker compose exec auth-db psql -U auth_user -d auth_db

# PostgreSQL CLI — school database
docker compose exec school-db psql -U school_user -d school_db

# Quick query: list all users
docker compose exec auth-db psql -U auth_user -d auth_db \
  -c 'SELECT id, email, "Role" FROM "Users";'

# Quick query: list all students
docker compose exec school-db psql -U school_user -d school_db \
  -c 'SELECT "Id", "FirstName", "LastName", "Email" FROM "Students";'

# Quick query: list all classrooms
docker compose exec school-db psql -U school_user -d school_db \
  -c 'SELECT "Id", "Name", "Grade", "AcademicYear" FROM "Classrooms";'
```

PgAdmin UI (easier): http://localhost:5050 — login: `admin@school.com` / `admin123`

---

## Test the API

```bash
# Login
curl -X POST http://localhost:5001/api/auth/authenticate \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@school.com\",\"password\":\"Password123!\"}"

# Validate a token (replace TOKEN with actual value)
curl -X POST http://localhost:5001/api/auth/validate \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"TOKEN\"}"

# List students (replace TOKEN)
curl http://localhost:5001/api/school/students \
  -H "Authorization: Bearer TOKEN"

# List classrooms (replace TOKEN)
curl http://localhost:5001/api/school/classrooms \
  -H "Authorization: Bearer TOKEN"
```

Or use Swagger UI: http://localhost:5001/swagger

---

## Flutter (Mobile App)

Run from the `frontend/` folder.

```bash
flutter pub get               # install / update packages
flutter run                   # run on connected device or emulator
flutter run -d chrome         # run in Chrome browser
flutter build apk             # build Android APK
flutter build apk --release   # build release APK
flutter clean                 # clear build cache
flutter analyze               # run static analysis
```

### Change API base URL (physical device)

Pass it at run/build time (defaults live in `frontend/lib/services/api_config.dart`):

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5001
```

---

## Admin Web (Next.js)

Run from the `admin-web/` folder. Not needed if using Docker (it runs as a container).

```bash
npm install                   # install dependencies
npm run dev                   # start dev server on http://localhost:3000
npm run build                 # production build
npm start                     # start production server
```

---

## Useful Ports

| URL                              | What it is                              |
| -------------------------------- | --------------------------------------- |
| http://localhost:5001/swagger     | API docs (Auth + School) + tester       |
| http://localhost:3000             | Admin panel (Next.js)                   |
| http://localhost:3200             | Flutter app (web build)                 |
| http://localhost:8500             | Consul — service discovery dashboard    |
| http://localhost:5050             | PgAdmin — database browser              |
