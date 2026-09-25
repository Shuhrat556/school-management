# PLAN

Belgilar: `[ ]` kutilmoqda · `[~]` jarayonda · `[x]` tugadi · `[!]` ruxsat kutmoqda.
Har vazifa ~15-20 daqiqalik bo'lak. Ustuvorlik: 1) kritik xato/xavfsizlik → 2) testlar → 3) refaktoring → 4) yangi funksiyalar → 5) deploy.

## 0. Xotira tizimi
- [x] docs/ai/ fayllari, CLAUDE.md, ai-loop.sh, root .gitignore, `ai/improvements` branch

## 1. Loyihani aniqlash
- [x] Kodni o'qish: backend (gateway, auth, school), admin-web, Flutter → CONTEXT.md
- [x] Build + test + lint: dotnet build, npm run lint/build, flutter analyze/test → BUGS.md
- [x] Eskirgan paketlar va zaifliklar: dotnet list package --outdated/--vulnerable, npm audit, flutter pub outdated
- [ ] Docker bilan lokal ishga tushirish va smoke test (disk bo'shadi — qayta sinash)

## 2. Server va DB (faqat o'qish)
- [x] ~/.ssh/config va docs/server_key.md dagi hostni aniqlash, read-only ulanish
- [x] Serverda: servislar, resurslar, loglar, SSL, deploy usuli → CONTEXT.md
- [x] DB: sxema, indekslar, hajm, backup (faqat SELECT) → CONTEXT.md (DATABASE.md 4-bo'limda)

## 3. Tadqiqot
- [x] Raqobatchilar (xalqaro + mahalliy) → RESEARCH.md
- [x] Rasmiy hujjatlar: ASP.NET Core 10, EF Core 10, YARP, Next.js 16, Flutter → RESEARCH.md

## 4. Hujjatlar
- [x] docs/ARCHITECTURE.md
- [x] docs/API.md
- [x] docs/DATABASE.md
- [x] docs/DEPLOYMENT.md
- [x] README yangilash
- [ ] Egasiga 5-10 bandli qisqa hisobot

## 5. Kritik xatolar va xavfsizlik (har biri: test → tuzatish → build/test)
- [x] T0a: `SchoolService.Tests` (xUnit + WebApplicationFactory + SQLite in-memory), sln ga qo'shildi
- [x] T0b: `AuthService.Tests` xuddi shunday
- [x] B1: school-service rol-policy'lari (Admin / Teacher / Student) — yozish endpointlari faqat Admin/Teacher; test: Student 403
- [x] B1b: Student o'z ma'lumotlarini ko'radi (grades/attendance/submissions/students list — faqat o'ziniki) + `GET /students/me`, student-portal.js dagi "hamma o'quvchini yuklab email bo'yicha qidirish" fallback'ini olib tashlash; test
- [x] B9: SubmissionsController (+MaterialsController) DI (ISubmissionService) + studentId ni tokendan olish; test
- [x] B10: OAuth-only user parol bilan kirganda 500 emas 401; test
- [x] B2: JWT secret yo'q/qisqa bo'lsa Production'da ishga tushmaslik (ikkala servis); test
- [x] B3a: auth per-IP rate limiting + ForwardedHeaders (auth, gateway); test 429
- [x] B3b: akkaunt lockout (5 xato → 5 daq), auth migratsiya (Down bilan); test
- [x] B4: Facebook OAuth — email bo'yicha avtomatik bog'lashni faqat tasdiqlangan email bilan; test
- [x] B8: login javobida EMAIL_NOT_VERIFIED faqat parol to'g'ri bo'lsa; test
- [x] B7: refresh tokenlarni xeshlab saqlash (auth migratsiya, rollback bilan); test
- [x] B6: CORS — konfiguratsiyadan originlar ro'yxati (dev: hammasi)

## 6. Testlar (qamrov)
- [ ] School-service unit: GradeService, AttendanceService, ClassroomService (enroll/unenroll), StudentService
- [ ] Auth unit: AuthenticationService (login, refresh rotation, reset code lockout), PasswordHasher
- [ ] admin-web: vitest + api.js (refresh oqimi), auth.js (rol yo'naltirish)
- [ ] Flutter: api_service unit (Dio mock), login oqimi widget testi
- [x] CI: `.github/workflows/ci.yml` — dotnet test (3 servis), EF pending-changes, admin-web lint/build, flutter analyze/test (push qilinmagan)

## 7. Refaktoring
- [x] B11: school-service `EnsureCreated`+raw SQL → EF migratsiyalar (baseline, PostgreSQL testlari, rollback sinovi)
- [x] B16: unique cheklovlar migratsiyasi (Attendance, StudentGrade, email) + dublikat tekshiruv SQL
- [x] B17: o'quvchi/o'qituvchi soft delete (SoftDeleteTests)
- [x] B12: gateway o'lik Consul kodi — olib tashlash yoki haqiqiy dinamik provider
- [x] B13: repo gigiyenasi — .tools/, .idea/, DotSettings.user, Flutter generated fayllarni untrack qilish
- [ ] admin-web: lint warninglarini tuzatish (21), parallel 401 da bitta refresh (race)
- [ ] admin-web Dockerfile: `output: 'standalone'`

## 8. Yangi funksiyalar (RESEARCH.md: Majburiy/Muhim)
- [ ] F1: Parent portali — ota-ona ↔ o'quvchi bog'lash (school DB migratsiya), Parent API (farzand baho/davomat/e'lon)
- [ ] F2: Parent UI (admin-web `/parent/*`)
- [ ] F3: In-app bildirishnomalar (yangi baho, qoldirilgan dars, e'lon)
- [ ] F4: O'quvchi hisobot kartasi (semestr bo'yicha o'rtacha + davomat %) API + CSV eksport
- [ ] F5: Baho o'zgarishlari audit log'i
- [ ] F6: Profil sahifasidan Google/Facebook akkauntini bog'lash (`POST /api/auth/link/{provider}`, Bearer bilan)

## 9. Deploy
- [x] docs/DEPLOYMENT.md: runbook, backup (pg_dump), rollback rejasi
- [ ] scripts/backup-db.sh (lokal/serverda ishlatish uchun, faqat fayl)
- [!] Serverda backup olish va yangi versiyani deploy qilish — RUXSAT KERAK (QUESTIONS Q2)
- [!] TLS/domen uchun nginx konfiguratsiyasi — RUXSAT KERAK (QUESTIONS Q3)
