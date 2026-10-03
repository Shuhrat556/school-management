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

- F3 backend TAYYOR: `Notifications` (migratsiya `AddNotifications`), baho/davomat/e'lon ilgaklari, 4 endpoint (D11). school 119/119.
  B21 (e'lon muallifi) topildi.

- F3b: admin-web `/notifications` sahifasi (o'qilgan/o'qilmagan, hammasini o'qish) va Sidebar'da o'qilmaganlar soni. Build OK.

- F3c: Flutter `NotificationScreen` endi `/api/school/notifications` dan o'qiydi (hardcoded mock o'rniga), turi bo'yicha filtr,
  pull-to-refresh, o'qildi belgisi; 2 ta widget test. Eslatma: `dart format` bu repoda ishlatilmagan (eski formatlash) — butun faylni
  formatlamang, faqat o'zgargan joylar.

- B21/B22 TUZATILDI: e'lon muallifi tokendan, faqat muallif/Admin o'zgartiradi, qoralamalar faqat Staff'ga. school 118/118.

- `scripts/backup-db.sh` (+ DEPLOYMENT.md cron taklifi); QUESTIONS Q2 ga aniq deploy/rollback rejasi yozildi (ruxsat kutilmoqda).

## 2026-10-03 — Sessiya 2

- Oldingi sessiya F5 ni boshlab uzilgan edi (7 ta kuzatilmagan fayl: `GradeChange` entity, konfiguratsiya, repozitoriy, `ICurrentActor`).
  Ko'rib chiqildi va tugatildi.
- F5 TAYYOR (D12): `GradeChanges` audit jadvali (migratsiya `AddGradeChanges`, Down bilan; PostgreSQL 16 da up/down/up sinaldi),
  `GradeService` yaratish/o'zgartirish/o'chirishni bahoning o'zi bilan bitta `SaveChanges` da yozadi; `GET /grades/{id}/history` (Staff),
  `GET /grades/changes` (Admin). GradeAuditTests 7 ta; school 125/125 (PostgreSQL bilan). Commit 656d656.
- F5b: admin-web `/admin/grade-changes` (o'quvchi filtri, oxirgi 50/100/200) + Sidebar "Grade history". Lint 0 xato (21 eski ogohlantirish), build OK.
  `api.js` da faqat o'z hunk'im stage qilindi.

- F4 TAYYOR (D13): `GET /students/{id}/report-card` (+`/csv`) — fanlar, harf, GPA (admin-web bilan bir xil shkala `GradeScale`), o'rtacha,
  davomat (`from`/`to`); CSV RFC 4180 + BOM + formula injection himoyasi. ReportCardTests 9 ta; school 134/134 (PostgreSQL bilan). Commit 76a8153.
- F4b: admin-web `/report-card/[studentId]` (o'quvchi uchun `/report-card/me`): semestr tanlash, CSV yuklab olish, "Print / PDF"
  (Sidebar chop etishda yashiriladi). Havolalar: o'quvchi menyusi, ota-ona dashboard'i, admin o'quvchi sahifasi, o'qituvchi sinf ro'yxati.
  Lint 0 xato (21 eski), build OK. UI brauzerda sinalmadi — Docker ishlamayapti (Q6).

- B18 TUZATILDI: o'lik `Enrollment` entity va DTO'lar o'chirildi (51bed80).
- admin-web: `output: 'standalone'` Dockerfile (74855b6) va xavfsizlik headerlari (a472c49) — ikkalasi lokal `node server.js` bilan sinaldi
  (sahifalar, statik fayllar, `/api` rewrite soxta backend orqali, headerlar).
- B23 TUZATILDI: sinfdan chiqarilgan o'quvchi ro'yxatda qolardi va qayta yozilmasdi (EnrollmentTests, 01f7027).
- B24 TUZATILDI: jadvalda sinf/xona to'qnashuvi (ScheduleConflictTests, 47c5416). Prod'da SELECT bilan tekshirildi: to'qnashuv yo'q.
  school 146/146 (PostgreSQL bilan).

- B25 TUZATILDI: davomat faqat sinfda faol o'quvchiga; admin-web formasi sinf ro'yxatidan tanlaydi (AttendanceTests; 9212b11, 02685da).
  school 150/150 (PostgreSQL bilan).
- B26 TUZATILDI (Flutter): muddati o'tgan refresh token cheksiz refresh zanjiri (IP limitigacha), parallel refresh, cheksiz retry;
  yangi paketsiz soxta Dio adapter bilan 3 ta test (dab9158). Flutter 6/6, analyze toza.
- D14: refresh token reuse aniqlash (RFC 9700) + muddati o'tgan tokenlarni tozalash (RefreshTokenReuseTests; cf2fd61). auth 26/26.

- B28 TUZATILDI: parol almashtirilganda boshqa sessiyalar tugamasdi (`GetByIdAsync` tokenlarsiz yuklardi; ChangePasswordTests; d0d4b79).
- B27 TUZATILDI: yaroqsiz Google/Facebook tokeni → 500/502 o'rniga 401 `INVALID_EXTERNAL_TOKEN` (OAuthTokenErrorTests; 3142947).
- F6 backend TAYYOR (D15): `GET/POST/DELETE /api/auth/logins[/{provider}]` (AccountLinkTests 12 ta; 2d20067). Veb-UI domen/TLS (Q3) ni kutadi.
- B29 TUZATILDI: `GET /api/auth/user/{id}` faqat o'zi/Admin (UserLookupTests; d2ed91d). auth 46/46.


## 2026-10-03 — Sessiya 2 (davomi, egasi: "o'zing davom etaver")

- school-service: gateway yo'naltirmaydigan `ValidationController` + `AuthServiceClient` o'chirildi; `ServiceHealthController` `IHttpClientFactory`
  ishlatadi (865e13b). Consul + `ServiceDiscoveryClient` qoldi — admin-web `/admin/health` ishlatadi.
- F6b: Flutter Sozlamalar → "Security & Login" (avval hech narsa qilmasdi) → `LinkedAccountsScreen` (4 widget test; eba42fd).
- B30 TUZATILDI: Flutter login ekranlari rolni tekshirmasdi; umumiy `finishSignIn`, 5 ta login widget testi (9e5eeb8). Flutter 15/15.

- Docker yo'q (Q6) — butun stek lokal ishga tushirildi (PostgreSQL + dotnet run + admin-web standalone): toza bazada 10 school va auth
  migratsiyalari, seed; admin-web orqali uchidan-uchiga 29 tekshiruv o'tdi. Shu jarayonda topildi va tuzatildi:
  4xx xatolar "Unhandled exception" + stack trace bilan Error darajasida log qilinardi (fcc98c1, ErrorLoggingTests);
  auth'da ko'p-kolleksiyali Include dekart JOIN (split query, ec80414).
- `scripts/local-stack.sh` (Docker'siz stek) va `scripts/smoke_test.py` (standart faqat o'qish — deploy'dan keyin prod uchun) (0c9b1c8).

- B31: materiallar/topshiriqlar sinfga a'zolik + xavfsiz havolalar (d77ae73); B32: e'lonlar faqat o'z sinflari (a39f9a7).
- B33: Flutter o'qituvchi "Announce to parents" soxta edi → haqiqiy `POST /api/announcements` (1a04ef5).
- F7 (D16) + B34/B35: uy vazifalari — backend `DueAt`, `submissionCount`, material soft delete (4ff3573, migratsiya `AddMaterialDueDate`);
  Flutter o'qituvchi (26e92ef) va o'quvchi (63fac5f) ekranlari soxta ma'lumotdan API'ga. school 169/169 (PostgreSQL), Flutter 26/26.

- B36: o'qituvchi sinf tafsiloti — haqiqiy ro'yxat/davomat/vazifa (19d78bf); Quick Actions haqiqiy ekranlarga (aa9f928).
- B37: "Create Course" → haqiqiy fan yaratish (kafedra bilan) (f642f09). Flutter 31/31.

- F8 (D17) + B38: dars qoldirish so'rovlari — backend (b8e15e0, migratsiya `AddLeaveRequests`), Flutter o'quvchi ekrani (eb611de),
  admin-web xodimlar `/leave-requests` va ota-ona `/parent/leave-requests` (bb191fb). school 176/176, Flutter 34/34, smoke 33/33 (toza stek).

- B39: o'qituvchi bildirishnomalari = kutilayotgan dars qoldirish so'rovlari, Approve/Decline (5620408).
- B40: "Parent Management" o'lik formasi → ota-onalar ma'lumotnomasi (b90d3bc).
- B41: o'quvchi bosh sahifasi — haqiqiy baholar va e'lonlar (0e12a01; 6eb3b2f da o'z regressiyamni tuzatdim: tafsilot muallifni 500 ga bo'lardi);
  o'qituvchi bosh sahifasi tadbirlari — e'lonlar (9e2be38).
- B42: ikkala ilovadagi soxta chat tab'lari → halol joy-egallovchi, ~1500 qator soxta kod olib tashlandi; haqiqiy chat PLAN F9 (b08e56f).
  Flutter 46/46.

- O'quvchi "Recent Activity" — haqiqiy baholar, ishlaydigan filtrlar (0e78ef5).
- B43 (YUQORI, xavfsizlik): o'quvchi istalgan sinf ro'yxatini sinfdoshlarning email/telefon/tug'ilgan sanasi bilan olardi → faqat o'z sinflari, PII'siz (0c28c1b).
- B44: Flutter jadval DTO `dayOfWeekName/startTime/endTime` ni o'qimasdi (kun/vaqt bo'sh), o'quvchi jadvali boshqa sinfniki edi (1041b01).
  Flutter va backend DTO kalitlari skript bilan solishtirildi — boshqa nomuvofiqlik yo'q; o'lik `createSchedule` olib tashlandi (44f6e44).
  school 181/181, Flutter 49/49.

KEYINGI QADAM: Flutter attendance analysis, result/score ekranlari; F9 (xabarlar) dizayni. Ruxsat kelsa — Q2 deploy.
