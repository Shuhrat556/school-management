# Setup Guide

Step-by-step instructions to get the entire School Management System running locally.

---

## Prerequisites

| Tool           | Required for        | Download                                             |
| -------------- | ------------------- | ---------------------------------------------------- |
| Docker Desktop | Backend & Admin Web | https://www.docker.com/products/docker-desktop        |
| Flutter SDK    | Mobile app          | https://docs.flutter.dev/get-started/install           |
| Git            | Cloning the repo    | https://git-scm.com                                    |

**Minimum specs:** 8 GB RAM, 20 GB free disk space.

---

## 1. Clone the project

```bash
git clone https://github.com/ToLa-Web/school-management.git
cd school-management
```

---

## 2. Environment variables

The `.env` file inside `backend/` is already committed with development defaults — **no action needed** for local development.

It contains:

| Variable                     | Purpose                              |
| ---------------------------- | ------------------------------------ |
| `JWT_SECRET`                 | Signs all JWT tokens                 |
| `EMAILSETTINGS_APP_PASSWORD` | Gmail App Password for sending emails |

> **Optional:** To use your own Gmail for email sending, open `backend/.env` and replace `EMAILSETTINGS_APP_PASSWORD` with your own [Gmail App Password](https://support.google.com/accounts/answer/185833).

---

## 3. Start the backend

```bash
cd backend
docker compose up --build
```

- First run takes **3–5 minutes** to pull images and build.
- Wait until you see `Application started` in the logs for all three services.
- Seed data (accounts, classrooms, students) is created automatically on first run.

Verify everything is running:

```bash
docker compose ps
```

All 8 containers should show status `running` or `healthy`:

| Container      | Port | Expected status |
| -------------- | ---- | --------------- |
| api-gateway    | 5001 | Running         |
| auth-service   | 5002 | Running         |
| school-service | 5003 | Running         |
| auth-db        | 5433 | Running         |
| school-db      | 5434 | Running         |
| consul         | 8500 | Running         |
| pgadmin        | 5050 | Running         |
| admin-web      | 3000 | Running         |
| web-app        | 3200 | Running         |

---

## 4. Run the Flutter app

### Option A: Android emulator

```bash
cd frontend
flutter pub get
flutter run
```

The emulator uses `10.0.2.2` to reach your localhost — already configured in `api_config.dart`.

### Option B: Physical phone (most common)

Your phone and computer must be on the **same Wi-Fi network**.

1. **Find your computer's local IP:**
   - **Windows:** run `ipconfig`, look for `IPv4 Address` under your Wi-Fi adapter
   - **Mac/Linux:** run `ifconfig | grep inet` or `ip addr`

2. **Run with your computer's IP** as the API base URL:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5001
   ```
   Example: `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5001`

3. **Run the app:**
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```

### Option C: Chrome (web)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

---

## 5. Verify everything works

| Check                          | URL / Action                                              | Expected result                          |
| ------------------------------ | --------------------------------------------------------- | ---------------------------------------- |
| API docs                       | http://localhost:5001/swagger                              | Swagger UI loads (pick Auth / School at the top right) |
| Login (API)                    | Use Swagger to POST `/api/auth/authenticate` with `admin@school.com` / `Password123!` | Returns JWT token |
| Consul dashboard               | http://localhost:8500                                     | All 3 services appear green              |
| Admin panel                    | http://localhost:3000                                     | Login page loads                         |
| Admin login                    | `admin@school.com` / `Password123!`                       | Dashboard with stats                     |
| PgAdmin                        | http://localhost:5050                                     | Login: `admin@school.com` / `admin123`   |
| Flutter app                    | Open on device/emulator, or http://localhost:3200          | Splash screen → role selection           |
| Flutter login                  | Teacher: `teacher1@school.com` / `Password123!`           | Teacher dashboard                        |

---

## 6. Admin Web (standalone, optional)

The admin panel runs automatically inside Docker. If you want to run it outside Docker for development:

```bash
cd admin-web
npm install
npm run dev
```

This starts a dev server at http://localhost:3000. API requests are proxied to `http://localhost:5001` via Next.js rewrites configured in `next.config.mjs`.

---

## Sharing with someone (teacher / teammate)

1. Run the zip script from the project root:
   ```powershell
   powershell -ExecutionPolicy Bypass -File make-zip.ps1
   ```
   This creates `school-management-for-teacher.zip` with all build artifacts excluded.

2. Send the zip. The recipient:
   - Installs Docker Desktop and Flutter SDK
   - Unzips and follows steps 2–5 above
   - For physical phone testing they pass `--dart-define=API_BASE_URL=http://THEIR_LAN_IP:5001` to `flutter run`

---

## Troubleshooting

| Symptom                                   | Fix                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------- |
| `docker compose up` errors immediately    | Make sure Docker Desktop is open and running                        |
| Port 5001 already in use                  | Run `docker compose down` first, or change the port in `docker-compose.yml` |
| App shows "Connection refused" on phone   | Wrong `API_BASE_URL`, or phone not on same Wi-Fi                   |
| App shows 401 Unauthorized                | Use seed credentials or register a new account                      |
| Emails not sending                        | Check `EMAILSETTINGS_APP_PASSWORD` in `.env` is a valid Gmail App Password |
| Consul shows unhealthy service            | Check `docker compose logs -f <service-name>` for errors            |
| Admin panel won't load on port 3000       | Run `docker compose logs -f admin-web`, then `docker compose up -d --build admin-web` |
| Want to wipe all data and start fresh     | `docker compose down -v && docker compose up --build`               |
| Flutter build errors                      | Run `flutter clean && flutter pub get` then try again               |
