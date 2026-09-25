# CONTEXT — loyiha haqida aniqlangan ma'lumotlar

## Loyiha nima
**School Management System** — maktab/o'quv muassasasi uchun boshqaruv platformasi: o'quvchilar, o'qituvchilar,
sinflar (classroom = kurs seksiyasi), fanlar, kafedralar (department), xonalar, baholar, davomat, dars jadvali,
e'lonlar, materiallar/topshiriqlar. Foydalanuvchilar: **Admin**, **Teacher**, **Student**, **Parent** (Parent
roli bor, lekin UI deyarli yo'q). Seed ma'lumotlari universitet CS fakultetiga o'xshaydi ("Year 1..4", "Semester 1 2025-2026").
Kelib chiqishi: o'quv loyihasi (upstream `ToLa-Web/school-management`, Kambodja jamoasi), egasi (`Shuhrat556`)
fork qilib 2026-09-22 dan beri modernizatsiya qilmoqda (.NET 10, Next 16, ro'yxatdan o'tishni yopish).

## Stack
| Qism | Texnologiya | Versiya |
|---|---|---|
| API Gateway | ASP.NET Core + YARP + Consul client | net10.0, Yarp 2.3.0, Consul 1.8.0, Swashbuckle 10.2.3 |
| Auth service | ASP.NET Core, EF Core + Npgsql, JWT (HS256), PBKDF2 | net10.0 |
| School service | ASP.NET Core, EF Core + Npgsql | net10.0 |
| DB | PostgreSQL 16 (2 ta alohida instance: auth_db, school_db) | postgres:16 |
| Service discovery | HashiCorp Consul | 1.22.7 |
| Admin/portal web | Next.js (App Router, JS), React, Tailwind | Next 16, React 19 |
| Mobil | Flutter/Dart (Android/iOS/web/desktop) | Flutter 3.41 lokal |
| Konteyner | Docker Compose (`backend/docker-compose.yml`) | — |

## Arxitektura (qisqa)
Mijozlar (Next.js admin-web :3000, Flutter web :3200 / mobil) → **API Gateway** :5001 (YARP) →
`/api/auth/**` → auth-service :5002 → auth_db :5433;
`/api/school/**`, `/api/announcements|rooms|materials|submissions|servicehealth/**` → school-service :5003 → school_db :5434.
Servislar Consul'ga ro'yxatdan o'tadi; gateway hozir amalda statik manzillardan foydalanadi (BUGS B12).
Auth-service JWT beradi; school-service o'sha umumiy `JWT_SECRET` bilan tokenni o'zi tekshiradi.
Auth va school bazalari bir-biriga bog'lanmagan: `Students.AuthUserId` / `Teachers.AuthUserId` orqali bog'lanadi,
admin-web `api/school/admin/sync-profile` bilan sinxronlaydi.

## Autentifikatsiya
- `POST /api/auth/authenticate` → access token (60 daq) + refresh token (7 kun, rotatsiya).
- Self-registration o'chirilgan (`Registration:Enabled=false`, b4db3c3) — akkauntlarni admin yaratadi.
- Email tasdiqlash va parol tiklash: 6 xonali kod, HMAC-SHA256 bilan xeshlangan, 10 daq, 5 urinish → 15 daq lockout.
- Google/Facebook OAuth (ID token / access token server tomonda tekshiriladi).
- Rollar: `ClaimTypes.Role` — Admin/Teacher/Student/Parent.

## Ishga tushirish
- Backend + web: `cd backend && cp .env.example .env && docker compose up --build`.
- Admin-web lokal: `cd admin-web && npm install && npm run dev` (API `next.config.mjs` rewrites orqali :5001 ga).
- Flutter: `cd frontend && flutter run --dart-define=API_BASE_URL=http://<ip>:5001`.
- Seed akkauntlar: README "Default Accounts" (parol README da, dev uchun).

## Deploy
- CI/CD fayllari repoda yo'q (`.github/` faqat lokal `modernize/` papkasi va global ignore qilingan).
- Server: `docs/server_key.md` da SSH manzili bor (repo'ga kirmaydi, D3). Holati — PLAN 2-bo'lim.

## Buyruqlar
| Maqsad | Buyruq | Holat (2026-09-24) |
|---|---|---|
| .NET build | `dotnet build backend/services/<svc>/...sln` (gateway: `ApiGateway.csproj`) | 3/3 OK, 0 warning |
| .NET paketlar | `dotnet list <sln> package --outdated` / `--vulnerable --include-transitive` | yangilanish yo'q, zaiflik yo'q |
| .NET testlar | `dotnet test backend/services/{api-gateway/ApiGateway.Tests,auth-service/AuthService/AuthService.Tests,school-service/SchoolService/SchoolService.Tests}` | xUnit + WebApplicationFactory + SQLite |
| admin-web lint | `cd admin-web && npm run lint` | 0 error, 21 warning |
| admin-web build | `npm run build` | OK |
| admin-web audit | `npm audit --omit=dev` | 0 zaiflik; next 16.3.5→16.3.6 patch bor |
| admin-web testlar | — | **test yo'q** |
| Flutter | `cd frontend && flutter pub get && flutter analyze && flutter test` | analyze toza, 1 widget test o'tadi |
| Flutter format | Repo `dart format` (3.11 tall style) bilan formatlanmagan — butun faylni formatlamang, diff shovqin bo'ladi | |
| Flutter eslatma | `pub get` (va `--no-pub` siz analyze/test) ios/macos xcconfig ni o'zgartirib Podfile yaratadi — `flutter analyze --no-pub`, `flutter test --no-pub` ishlating; tushib qolsa `git checkout` bilan qaytaring | |
| Stack lokal | `cd backend && cp .env.example .env && docker compose up --build` | Docker Desktop kerak |
| EF migratsiya sinovi | Homebrew PostgreSQL 16: `initdb -D <scratch>/pgdata -U postgres --auth=trust`, `pg_ctl -D ... -o "-p 55432 -c unix_socket_directories='' -c listen_addresses=127.0.0.1" start`, so'ng `dotnet ef database update <M> --connection "Host=127.0.0.1;Port=55432;Database=x;Username=postgres"` | sinalgan |
| EF o'zgarish tekshiruvi | `dotnet ef migrations has-pending-model-changes --project AuthService.Infrastructure --startup-project AuthService.API` | |

## Server va DB
Manzil: `docs/server_key.md` (repo'da emas). Ubuntu 24.04, 4 vCPU, 3.8 GB RAM (+2 GB swap), disk 50 GB (61% band).
Serverda egasining boshqa loyihasi ham bor (3000/3001/8000 portlar, o'z nginx + certbot saytlari) —
unga tegilmaydi.
- **Deploy usuli:** `/home/kasb/apps/school-management` — repo'ning git klon'i (`main` = b4db3c3, remote
  `origin-canonical` = Shuhrat556/school-management) + serverga xos `backend/docker-compose.override.yml`
  (git'da emas) + `backend/.env` (600). Qo'lda: `git pull && docker compose up -d --build` (CI/CD yo'q).
  Compose loyiha nomi: `school-management`, 9 konteyner.
- **Override:** `ASPNETCORE_ENVIRONMENT=Production`, `Swagger__Enabled=true`; ochiq portlar: admin-web **3100**,
  web-app **3200**, gateway **5001** (Swagger bilan). Qolganlari 127.0.0.1 ga bog'langan.
- **TLS/domen yo'q:** school-management nginx orqali emas, to'g'ridan-to'g'ri HTTP portlarda — parol va tokenlar
  shifrlanmagan holda uzatiladi (BUGS B14).
- **Backup yo'q:** school_db/auth_db uchun cron yoki dump yo'q (boshqa loyiha uchun qo'lda dump bor) (B15).
- **Loglar:** oxirgi 48 soatda gateway/auth/school/admin-web/web-app'da error/warn yo'q.
- `~/apps/school-management-releases/` — debug APK (167 MB).
- **school_db** (8.7 MB): `__EFMigrationsHistory` **yo'q** (EnsureCreated, B11). Asosan seed: 46 student, 2 teacher,
  12 classroom, 12 subject, 552 grade, 230 attendance. Indekslar: PK + FK indekslari; **unique cheklov yo'q**
  (Attendance student+sana, StudentGrade student+fan+semestr, Students/Teachers email) (B16).
- **auth_db** (7.8 MB): 56 user, 15 refresh token; EF migratsiyalar 4 ta, tarix jadvali bor.
