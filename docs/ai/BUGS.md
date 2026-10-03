# BUGS

Format: `Bn [daraja] sarlavha` — joy · tavsif · holat (OCHIQ / TUZATILDI <commit>).
Darajalar: KRITIK · YUQORI · O'RTA · PAST.

## Xavfsizlik

### B1 [KRITIK] School-service'da rolga asoslangan ruxsat yo'q
`SchoolService.API/Controllers/{Grades,Attendance,Students,Teachers,Classrooms,Subjects,Schedules,Announcements,Materials,Submissions}Controller.cs`
— faqat `[Authorize]`. Istalgan tizimga kirgan foydalanuvchi (masalan, Student) baho qo'yishi/o'zgartirishi,
davomatni belgilashi, o'quvchi/o'qituvchini o'chirishi mumkin. (OWASP A01 Broken Access Control.)
· YOZISH endpointlari TUZATILDI (D4, testlar: RoleAuthorizationTests, ProfileOwnershipTests). O'qish endpointlari (B1b) ham TUZATILDI: StudentDataAccessTests

### B2 [YUQORI] JWT secret bo'lmasa hardcode qilingan kalitga tushadi
`AuthService.Infrastructure/Settings/JwtConfig.cs`, `SchoolService.API/Program.cs` — `JWT_SECRET` berilmasa
repo'da ochiq turgan `"your-secret-key-change-me-..."` bilan token imzolanadi/tekshiriladi → har kim token soxtalashtira oladi.
Production'da ishga tushishdan oldin to'xtashi kerak (fail fast).
· TUZATILDI: Development'dan boshqa muhitda secret yo'q/fallback/<32 bayt bo'lsa servis ishga tushmaydi (JwtSecretStartupTests, ikkala servis)

### B3 [YUQORI] Login/parolni tiklash endpointlarida rate limiting yo'q
`AuthController` — `authenticate`, `request-password-reset`, `request-email-verification-code`, `refresh`.
Parolni brute-force qilish cheklanmagan (kod tekshiruvida lockout bor, parolda yo'q).
· TUZATILDI: per-IP limiter (D5, RateLimitTests) + akkaunt lockout: ketma-ket 5 xato parol → 5 daq 429 `ACCOUNT_LOCKED`
(AccountLockoutTests; auth migratsiya `AddLoginLockout`, Down bor). Eslatma: lockout akkaunt mavjudligini bildiradi — qabul qilingan (D5).

### B4 [YUQORI] Facebook OAuth tasdiqlanmagan email bo'yicha mavjud akkauntga bog'laydi
`AuthenticationService.AuthenticateExternalAsync` — Facebook uchun email bo'yicha mavjud foydalanuvchiga
avtomatik bog'lanadi (izohda "keep unverified"). Bu account takeover vektori.
· TUZATILDI: email bo'yicha bog'lash faqat provayder emailni tasdiqlaganda (Google `email_verified`); ExternalLoginTests
(avval Facebook orqali Admin akkauntiga kirildi). Oqibat: Facebook faqat oldindan bog'langan akkauntlar uchun ishlaydi (PLAN F6).

### B5 [O'RTA] `.env` git tarixida
`0e013e1` commitida `backend/.env` qo'shilgan, `9334e20` da olib tashlangan — qiymatlar tarixda qoladi.
Tavsiya: JWT secret va Gmail App Password'ni **almashtirish** (tarixni qayta yozish ruxsat talab qiladi). · OCHIQ

### B6 [O'RTA] CORS `AllowAnyOrigin` barcha servislarda
Gateway, auth, school — `AllowAll`. Production uchun aniq originlar ro'yxati kerak.
· TUZATILDI: faqat gateway'da, Development'da hammasi, boshqa muhitda `Cors:AllowedOrigins`; auth/school'dagi CORS olib tashlandi
(ular faqat gateway orqali chaqiriladi). CorsTests (yangi `ApiGateway.Tests`).

### B7 [O'RTA] Refresh tokenlar DB da ochiq holda saqlanadi
`RefreshToken.Token` — xesh o'rniga asl qiymat. DB sizib chiqsa sessiyalar o'g'irlanadi.
· TUZATILDI: base64(SHA-256) saqlanadi + indeks; migratsiya `HashRefreshTokens` mavjud tokenlarni SQL'da xeshlaydi (sessiyalar saqlanadi).
PostgreSQL 16 da up/down sinaldi. RefreshTokenStorageTests.

### B8 [PAST] Login javobi tasdiqlanmagan akkaunt mavjudligini oshkor qiladi
`AuthController.Authenticate` — parol noto'g'ri bo'lsa ham `EMAIL_NOT_VERIFIED` qaytaradi.
· TUZATILDI: faqat parol to'g'ri bo'lsa (LoginTests)

## Xatolar

### B9 [YUQORI] `/api/submissions/*` va `/api/materials/*` har doim 500
`SubmissionsController`/`MaterialsController` konkret `SubmissionService`/`MaterialService` ni so'raydi, DI da faqat interfeyslar
ro'yxatdan o'tgan → controller yaratilmaydi. Qo'shimcha: `POST /api/submissions` placeholder edi, `{studentId}/submit` istalgan
o'quvchi nomidan topshirishga ruxsat berardi, mavjud bo'lmagan material 500 berardi.
· TUZATILDI (MaterialsAndSubmissionsTests: avval 7/7 yiqildi, keyin o'tdi)

### B10 [O'RTA] Parol xeshi NULL bo'lgan akkaunt parol bilan kirsa 500
`AuthenticationService.AuthenticateAsync` — `user.PasswordHash!` null bo'lsa `VerifyPassword` da NullReferenceException
(yangi OAuth akkauntlarda `""` saqlanadi, lekin ustun nullable). · TUZATILDI (LoginTests)

### B11 [O'RTA] School DB sxemasi migratsiyasiz boshqariladi
`SchoolService.API/Program.cs` — `EnsureCreated()` + qo'lda yozilgan `ALTER TABLE ... IF NOT EXISTS` SQL.
`Migrations/` papkasi bor, lekin ishlatilmaydi; rollback imkoni yo'q, sxema drift xavfi.
· TUZATILDI: `MigrateAsync()` + `LegacySchemaBaseline` (D6); Designer'siz yetim `AddCurriculumToSubjects.cs` o'chirildi;
MigrationTests (PostgreSQL) + CI'da postgres service va `has-pending-model-changes`.

### B12 [PAST] Gateway Consul discovery natijasi tashlab yuboriladi (o'lik kod)
`ApiGateway/Program.cs` — `BuildFromConsul` natijasi ishlatilmaydi; YARP doim statik konfiguratsiyada.
· TUZATILDI: o'lik kod, `DiscoveryProxyConfigProvider.cs`, Consul paketi va `consul`/`spring` sozlamalari gateway'dan olib tashlandi.

## Repo gigiyenasi

### B13 [PAST] Keraksiz fayllar repoda
`backend/.tools/` (dotnet-ef 8.0.11 binarlari, .exe), `.idea/`, `*.DotSettings.user`, Flutter generated
fayllar (`ios/Flutter/Generated.xcconfig`, `ephemeral/`), `School_Management_System_Documentation.docx`,
`make-zip.ps1`. .gitignore ularni e'tiborsiz qoldiradi, lekin ular allaqachon track qilingan.
· TUZATILDI: 47 fayl indeksdan chiqarildi (lokal nusxalar joyida), `backend/.gitignore` ga `.tools/`. Docx va make-zip.ps1
qoldirildi (SETUP.md da ishlatiladi / hujjat).

## Server / infratuzilma

### B14 [YUQORI] Production HTTP'da, TLS va domensiz
Serverda admin-web (3100), web-app (3200), gateway (5001, Swagger yoqilgan) to'g'ridan-to'g'ri `0.0.0.0` da ochiq.
Login parollari va JWT'lar shifrlanmagan holda uzatiladi. Tavsiya: domen/subdomen + mavjud nginx/certbot orqali
reverse proxy, portlarni 127.0.0.1 ga bog'lash, production'da Swagger'ni o'chirish. Server konfiguratsiyasini
o'zgartirish ruxsat talab qiladi. · OCHIQ

### B15 [YUQORI] school_db / auth_db uchun backup yo'q
Serverda cron ham, dump fayllar ham yo'q. Deploy'dan oldin `pg_dump` majburiy (RULES 7). · OCHIQ

### B16 [O'RTA] Ma'lumot yaxlitligi uchun unique cheklovlar yo'q
school_db: Attendance (StudentId, ClassroomId, Date), StudentGrade (StudentId, SubjectId, Semester),
Students.Email, Teachers.Email — takroriy yozuvlarga DB darajasida to'siq yo'q. Faqat migratsiya orqali (B11 dan keyin).
· TUZATILDI: `AddNaturalKeyIndexes` (Down bilan), `POST /grades` upsert, BulkMark takrorlarni birlashtiradi. Prod'da dublikat yo'q (SELECT).
NaturalKeyTests, MigrationTests.Emails_are_unique_ignoring_case

### B17 [O'RTA] O'quvchini o'chirish — hard delete, baholar/davomat kaskad o'chadi
`StudentRepository.DeleteAsync` → `Remove()`; FK `StudentGrades/Attendances/Submissions/StudentClassrooms` = CASCADE.
`DeletedAt` ustuni bor, lekin ishlatilmaydi. Bitta xato bosish butun akademik tarixni yo'q qiladi. Tavsiya: soft delete
(`DeletedAt` + global query filter) yoki `IsActive=false`.
· TUZATILDI: repozitoriylarda soft delete + aktiv filtr (D8), o'quvchi sinflardan `Dropped`, rosterda ko'rinmaydi. SoftDeleteTests

### B18 [PAST] `Enrollment` entity o'lik kod
`SchoolService.Domain/Entities/Enrollment.cs` — DbContext'da yo'q, hech qayerda ishlatilmaydi (o'rnini `StudentClassroom` egallagan).
· TUZATILDI: entity va ishlatilmagan `DTOs/Enrollments` o'chirildi (EF modeli o'zgarmadi).

### B19 [PAST] Kod xeshlari uchun pepper repoda
`AuthService.API/appsettings.json` — `EmailVerification:Pepper` ochiq turardi (email tasdiqlash va parol tiklash kodlari HMAC'i
uchun). · TUZATILDI: bo'lim olib tashlandi, pepper endi `Jwt:Secret` dan olinadi (PasswordResetTests end-to-end tekshiradi).
Deploy'dan keyin 10 daqiqa ichida yuborilgan eski kodlar yaroqsiz bo'ladi — xolos.

### B20 [O'RTA] admin-web: bir vaqtdagi 401'lar bir nechta refresh chaqiradi
`admin-web/src/lib/api.js` — har bir 401 o'z `/api/auth/refresh` ini chaqirardi; refresh token rotatsiyasi sababli ikkinchisi
ishlatilgan token bilan yiqilib, foydalanuvchi tizimdan chiqarib yuborilardi (dashboard bir vaqtda 5-10 so'rov yuboradi).
· TUZATILDI: bitta umumiy in-flight refresh (tests/api-refresh.test.mjs, avval 3 ta refresh chaqirilgan).

### B21 [PAST] E'lon muallifi so'rov tanasidan olinadi
`AnnouncementCreateDto.AuthorTeacherId` — o'qituvchi boshqa o'qituvchi nomidan e'lon yozishi mumkin. Tavsiya: muallifni tokendan
(`/teachers/me`) olish, Admin uchun ixtiyoriy.
· TUZATILDI: o'qituvchi faqat o'z nomidan yozadi va faqat o'z e'lonlarini o'zgartiradi (AnnouncementTests)

### B22 [O'RTA] Qoralama e'lonlar o'quvchi va ota-onaga ko'rinadi
`GET /api/announcements` publish qilinmaganlarni ham qaytarardi. · TUZATILDI: Staff'dan boshqalar faqat publish qilinganlarni ko'radi,
qoralama `GET {id}` → 404 (AnnouncementTests)

### B23 [O'RTA] Sinfdan chiqarilgan o'quvchi ro'yxatda qoladi va qayta yozib bo'lmaydi
`ClassroomService` — unenroll qatorni `Dropped` qiladi (o'chirmaydi), lekin `GET /classrooms/{id}` ro'yxati statusni filtrlamasdi:
admin-web/o'qituvchi/Flutter "Remove from class" dan keyin ham o'quvchini ko'rsatardi. Kompozit kalit (StudentId, ClassroomId) sabab
qayta enroll har doim 409 "already enrolled" berardi (`Reenroll()` metodi bor edi, ishlatilmagan); ikkinchi unenroll 404 o'rniga 204.
· TUZATILDI: ro'yxat faqat Active, ketgan o'quvchi o'sha qatorda qayta faollashadi, faol bo'lmaganini unenroll → 404 (EnrollmentTests: avval 3/4 yiqildi).

### B24 [O'RTA] Jadvalda sinf va xona ikki marta band qilinishi mumkin edi
`ScheduleService` faqat o'qituvchi to'qnashuvini tekshirardi: bitta sinfga yoki bitta xonaga (sinfning `RoomId`) bir vaqtda ikki dars qo'yish
mumkin edi; mavjud bo'lmagan o'qituvchi FK xatosiga olib kelardi.
· TUZATILDI: sinf va xona (Classroom/Lab turlari; Gym/Auditorium umumiy) to'qnashuvi → 409, noma'lum o'qituvchi → 404, end ≤ start → 400
(ScheduleConflictTests: avval 4/8 yiqildi). Production'da (SELECT, 2026-10-03) 12 ta dars, hech qanday to'qnashuv yo'q.
