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

- B1b TUZATILDI: o'quvchi faqat o'z profil/baho/davomatini ko'radi, ro'yxat Staff'ga; `GET /students/me`, `GET /teachers/me`
  (AuthUserId, bo'lmasa bog'lanmagan profil email bo'yicha). admin-web student-portal va Flutter login'lari endi butun ro'yxatni
  yuklamaydi. Testlar 88/88 (B1b testlari tuzatish bilan birga yozildi). `StudentService.cs`/`api.js` da faqat o'z hunk'im stage qilindi.

- B9 TUZATILDI: materials va submissions controllerlari interfeys orqali; topshiriq faqat o'z nomidan (token), noma'lum material → 404.
  Avval 7 test 500 bilan yiqildi, tuzatishdan keyin 95/95.

- T0b: `AuthService.Tests` (SQLite, FakeEmailSender), Program.cs'ga o'sha flaglar. Commit 9cfb473.
- B10 TUZATILDI: NULL parol xeshi bilan login 500 o'rniga 401 (test avval 500 bilan yiqildi).

- B2 TUZATILDI: ikkala servis Development'dan tashqarida zaif/yo'q JWT secret bilan ishga tushmaydi (testlar avval 3+3 yiqildi).
  B19: appsettings'dagi pepper olib tashlandi. DEPLOYMENT.md ga secret uzunligini tekshirish qadami. auth 10/10, school 99/99.

- B3a: auth per-IP rate limiting (D5) + gateway/auth ForwardedHeaders (faqat xususiy tarmoqlar). Testlar 14/14
  (IP bo'yicha ajratish, ishonchsiz peer XFF'i e'tiborsiz). Next.js XFF cheklovi D5 da.

- B3b: akkaunt lockout (5 xato → 5 daq 429 ACCOUNT_LOCKED), auth migratsiya `AddLoginLockout` (Down bilan), testlar 17/17.
  Flutter login xatosi endi `error` kalitini ham ko'rsatadi. **Deploy'da auth migratsiyasi ishga tushadi (startup Migrate) — Q2 ruxsati bilan.**

- B4 TUZATILDI: OAuth email bo'yicha bog'lash faqat tasdiqlangan email bilan (Facebook takeover testi avval 200 qaytargan). auth 20/20.

- B8 TUZATILDI: `EMAIL_NOT_VERIFIED` faqat to'g'ri paroldan keyin (test avval yiqildi). auth 21/21.

- B7 TUZATILDI: refresh tokenlar SHA-256 xesh ko'rinishida (+indeks); `HashRefreshTokens` migratsiyasi eski tokenlarni SQL'da xeshlaydi.
  Scratchpad'da vaqtinchalik PostgreSQL 16 (port 55432) ko'tarildi — migratsiya up/down haqiqiy DB'da sinaldi. auth 23/23.

- B6 TUZATILDI: gateway CORS konfiguratsiyadan (`Cors:AllowedOrigins`), servislarda CORS yo'q. Yangi `api-gateway/ApiGateway.Tests`
  (+`ApiGateway.slnx`). Testlar: gateway 4, auth 23, school 99.

- CI: `.github/workflows/ci.yml` qo'shildi (branch push qilinganda ishlaydi; men push qilmadim).

- B11 TUZATILDI: school-service `MigrateAsync()` + legacy baseline (D6). Migratsiyalar va EnsureCreated sxemasi, prod sxemasi
  bilan solishtirildi — mos. 3 ta PostgreSQL testi (SCHOOL_TEST_POSTGRES), CI'da postgres service. school 102/102.
  **Deploy'da school_db ga `__EFMigrationsHistory` qo'shiladi — Q2 ruxsati bilan.**

- B16 TUZATILDI: `AddNaturalKeyIndexes` migratsiyasi (grade/attendance unique, email lower() unique), grade upsert (D7),
  BulkMark dedupe. Legacy test endi haqiqiy eski sxemani simulyatsiya qiladi (baseline'gacha migrate + history'siz) —
  shu tufayli "eski indeks yo'q" holati topildi va `DROP INDEX IF EXISTS` qilindi. school 106/106 (PostgreSQL bilan).

- XATO TUZATILDI (jarayon): B16 commitiga `git add <dir>` tufayli egasining `DataSeeder.cs` o'zgarishi tushib qolgan edi —
  push qilinmagan commit amend qilindi (a517e77), ishchi daraxtdagi o'zgarish saqlandi; CLAUDE.md ga qoida qo'shildi.
- B17 TUZATILDI: o'quvchi/o'qituvchi soft delete (D8). school 108/108 (PostgreSQL bilan).

- B12 TUZATILDI: gateway'dan o'lik Consul discovery kodi olib tashlandi; ARCHITECTURE.md "Access rules" + yangilangan "Known gaps".

- B13: 47 ta generated/IDE/eskirgan tool fayli untrack qilindi (`git rm --cached`, lokal fayllar saqlangan).

- B20 TUZATILDI: admin-web 401 refresh race (bitta umumiy refresh). `npm test` = Node o'rnatilgan test runner (yangi paket yo'q), CI'da.

- F1 (backend) va F2 (admin-web) TAYYOR: `StudentParents` bog'lanishi, `/parents/me/children`, ota-ona uchun farzand ma'lumotlariga
  kirish; `/parent/dashboard` (o'rtacha ball, GPA, davomat, oxirgi baholar/qoldirilgan darslar), admin "Parents" paneli,
  login/Sidebar/useAuth'da role 3. school 114/114, admin-web build OK. Docker hali ham ishlamayapti (Q6).

KEYINGI QADAM: PLAN 8-bo'lim F4 — o'quvchi hisobot kartasi API (semestr o'rtachasi + davomat %) + CSV; keyin F3 bildirishnomalar.
