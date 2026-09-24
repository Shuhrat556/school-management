# PROGRESS

Jurnal: eng yangisi pastda. Har yozuv: sana — nima qilindi · fayllar · commit.

## 2026-09-24 — Sessiya 1

- Oldingi holat: `docs/ai/` da faqat PROGRESS.md bor edi, u "ruxsat kerak" deb loop'ni to'xtatgan
  (docs/ai fayllari yo'qligi sababli). Egasi topshiriqni to'liq berdi — noldan boshlandi, eski yozuv almashtirildi.
- `ai/improvements` branchi `main` (b4db3c3) dan ochildi. Egasining 9 ta commit qilinmagan fayli tegilmagan (QUESTIONS Q1).
- Yaratildi: docs/ai/{RULES,PLAN,PROGRESS,DECISIONS,BUGS,RESEARCH,QUESTIONS,CONTEXT}.md, CLAUDE.md,
  ai-loop.sh (qayta yozildi, D1), root .gitignore (server_key.md, Library/, .env, run.log).
- Kod o'qildi: gateway, auth-service, school-service Program.cs va kontrollerlar → BUGS.md B1–B13.

- Build/lint/test: .NET 3/3 OK (0 warning, test yo'q); admin-web lint 0 error/21 warning, build OK, audit 0;
  Flutter analyze toza, 1 test o'tadi. `flutter pub get` o'zgartirgan ios/macos fayllari qaytarildi. → CONTEXT "Buyruqlar".
- Server (read-only SSH): deploy = serverdagi git klon + override + `docker compose up -d --build`; HTTP-only,
  backup yo'q, school_db migratsiya tarixisiz. → CONTEXT "Server va DB", BUGS B14–B16.
- Docker Desktop lokal ishga tushirildi (`open -a Docker`).

## 2026-09-25 — Sessiya 1 (davomi)

- RESEARCH.md: raqobatchilar (eMaktab/Kundalik, PowerSchool, Fedena, OpenSIS/Gibbon, ManageBac) va rasmiy hujjatlar
  (EF migratsiyalar, rate limiting). PLAN.md 5–9 bo'limlari tuzildi. QUESTIONS Q2–Q4. Commit 35fb255.
- Lokal `docker compose up --build` — image yuklash paytida Mac diski to'ldi (~180 MB bo'sh), Docker Desktop to'xtadi.
  Docker yopildi, boshqa ishlatilmaydi → QUESTIONS Q5. Lokal `backend/.env` (gitignored, tasodifiy secret) yaratildi.

- Hujjatlar: docs/ARCHITECTURE.md, API.md, DATABASE.md, DEPLOYMENT.md yaratildi; README/SETUP/COMMANDS dagi eskirgan
  `.env commit qilingan`, ochiq registratsiya va PgAdmin paroli haqidagi gaplar tuzatildi. BUGS B17 (hard delete), B18.
- Disk bo'shadi (16 GB) → Q5 yopildi.

- T0a: `SchoolService.Tests` (xUnit, WebApplicationFactory, SQLite in-memory); Program.cs'ga `Database:InitializeOnStartup`
  va `Consul:Enabled` flaglari; Dockerfile'lar faqat API loyihasini restore qiladi + `.dockerignore`. Commit 8395b2b.
- B1 TUZATILDI: rol atributlari (D4), o'quvchi/o'qituvchi faqat o'z profilini tahrirlaydi; Flutter o'qituvchi ekranidan
  "delete" tugmasi olib tashlandi. Testlar 78/78. Commit 63ec4bf.

KEYINGI QADAM: PLAN 5-bo'lim B1b — o'quvchi uchun o'qish endpointlarini cheklash + `GET /students/me`, student-portal.js ni moslash.
