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
_(1-bo'lim build/test bosqichida to'ldiriladi)_

## Server va DB
_(PLAN 2-bo'lim)_
