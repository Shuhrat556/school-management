# BUGS

Format: `Bn [daraja] sarlavha` — joy · tavsif · holat (OCHIQ / TUZATILDI <commit>).
Darajalar: KRITIK · YUQORI · O'RTA · PAST.

## Xavfsizlik

### B1 [KRITIK] School-service'da rolga asoslangan ruxsat yo'q
`SchoolService.API/Controllers/{Grades,Attendance,Students,Teachers,Classrooms,Subjects,Schedules,Announcements,Materials,Submissions}Controller.cs`
— faqat `[Authorize]`. Istalgan tizimga kirgan foydalanuvchi (masalan, Student) baho qo'yishi/o'zgartirishi,
davomatni belgilashi, o'quvchi/o'qituvchini o'chirishi mumkin. (OWASP A01 Broken Access Control.) · OCHIQ

### B2 [YUQORI] JWT secret bo'lmasa hardcode qilingan kalitga tushadi
`AuthService.Infrastructure/Settings/JwtConfig.cs`, `SchoolService.API/Program.cs` — `JWT_SECRET` berilmasa
repo'da ochiq turgan `"your-secret-key-change-me-..."` bilan token imzolanadi/tekshiriladi → har kim token soxtalashtira oladi.
Production'da ishga tushishdan oldin to'xtashi kerak (fail fast). · OCHIQ

### B3 [YUQORI] Login/parolni tiklash endpointlarida rate limiting yo'q
`AuthController` — `authenticate`, `request-password-reset`, `request-email-verification-code`, `refresh`.
Parolni brute-force qilish cheklanmagan (kod tekshiruvida lockout bor, parolda yo'q). · OCHIQ

### B4 [YUQORI] Facebook OAuth tasdiqlanmagan email bo'yicha mavjud akkauntga bog'laydi
`AuthenticationService.AuthenticateExternalAsync` — Facebook uchun email bo'yicha mavjud foydalanuvchiga
avtomatik bog'lanadi (izohda "keep unverified"). Bu account takeover vektori. · OCHIQ

### B5 [O'RTA] `.env` git tarixida
`0e013e1` commitida `backend/.env` qo'shilgan, `9334e20` da olib tashlangan — qiymatlar tarixda qoladi.
Tavsiya: JWT secret va Gmail App Password'ni **almashtirish** (tarixni qayta yozish ruxsat talab qiladi). · OCHIQ

### B6 [O'RTA] CORS `AllowAnyOrigin` barcha servislarda
Gateway, auth, school — `AllowAll`. Production uchun aniq originlar ro'yxati kerak. · OCHIQ

### B7 [O'RTA] Refresh tokenlar DB da ochiq holda saqlanadi
`RefreshToken.Token` — xesh o'rniga asl qiymat. DB sizib chiqsa sessiyalar o'g'irlanadi. · OCHIQ

### B8 [PAST] Login javobi tasdiqlanmagan akkaunt mavjudligini oshkor qiladi
`AuthController.Authenticate` — parol noto'g'ri bo'lsa ham `EMAIL_NOT_VERIFIED` qaytaradi. · OCHIQ

## Xatolar

### B9 [YUQORI] `/api/submissions/*` har doim 500
`SubmissionsController` konkret `SubmissionService` ni so'raydi, DI da faqat `ISubmissionService` ro'yxatdan o'tgan
→ controller yaratilmaydi. · OCHIQ (build/run bilan tasdiqlash kerak)

### B10 [YUQORI] OAuth-only foydalanuvchi parol bilan kirsa 500
`AuthenticationService.AuthenticateAsync` — `user.PasswordHash!` null bo'lsa `VerifyPassword` da NullReferenceException. · OCHIQ

### B11 [O'RTA] School DB sxemasi migratsiyasiz boshqariladi
`SchoolService.API/Program.cs` — `EnsureCreated()` + qo'lda yozilgan `ALTER TABLE ... IF NOT EXISTS` SQL.
`Migrations/` papkasi bor, lekin ishlatilmaydi; rollback imkoni yo'q, sxema drift xavfi. · OCHIQ

### B12 [PAST] Gateway Consul discovery natijasi tashlab yuboriladi (o'lik kod)
`ApiGateway/Program.cs` — `BuildFromConsul` natijasi ishlatilmaydi; YARP doim statik konfiguratsiyada. · OCHIQ

## Repo gigiyenasi

### B13 [PAST] Keraksiz fayllar repoda
`backend/.tools/` (dotnet-ef 8.0.11 binarlari, .exe), `.idea/`, `*.DotSettings.user`, Flutter generated
fayllar (`ios/Flutter/Generated.xcconfig`, `ephemeral/`), `School_Management_System_Documentation.docx`,
`make-zip.ps1`. .gitignore ularni e'tiborsiz qoldiradi, lekin ular allaqachon track qilingan. · OCHIQ

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
Students.Email, Teachers.Email — takroriy yozuvlarga DB darajasida to'siq yo'q. Faqat migratsiya orqali (B11 dan keyin). · OCHIQ
