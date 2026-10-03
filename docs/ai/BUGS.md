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

### B25 [O'RTA] Davomat sinfda bo'lmagan o'quvchiga yozilardi
`AttendanceService.BulkMarkAsync` o'quvchi sinfga yozilganini tekshirmasdi; admin-web davomat formasi istalgan o'quvchi + istalgan sinfni
alohida tanlatardi. Mavjud bo'lmagan o'quvchi id → FK xatosi.
· TUZATILDI: yangi belgi faqat sinfda faol o'quvchiga (aks holda 400 ismlar bilan, hech narsa saqlanmaydi), mavjud belgini tuzatish
mumkin; admin-web formasida avval sinf, keyin uning ro'yxatidan o'quvchi (AttendanceTests: avval 2/4 yiqildi).

### B26 [YUQORI] Flutter: muddati o'tgan refresh token cheksiz refresh zanjirini boshlaydi
`frontend/lib/services/api_service.dart` — 401 interceptor `/api/auth/refresh` ning o'z 401 javobini ham ushlab, yana refresh chaqirardi:
zanjir faqat auth per-IP limiti (120/daq) 429 berganda to'xtardi — butun maktab NAT IP'si uchun refresh bir daqiqaga bloklanardi.
Qayta yuborilgan so'rov yana 401 olsa ham cheksiz takrorlanardi; parallel 401'lar bir xil (rotatsiya qilinadigan) tokenni bir necha marta
sarflardi (B20 ning mobil nusxasi); qayta yuborishdagi har qanday xato (masalan 500) foydalanuvchini tizimdan chiqarardi.
· TUZATILDI: refresh/logout va qayta yuborilgan so'rovlar refresh qilinmaydi, bitta umumiy in-flight refresh, refresh 401 → tokenlar tozalanadi,
retry xatosi chaqiruvchiga qaytadi (test/api_service_refresh_test.dart: avval 3/3 yiqildi — 51 ta refresh, 3 ta refresh, cheksiz retry).

### B28 [O'RTA] Parol almashtirilganda boshqa sessiyalar tugamasdi
`AuthenticationService.ChangePasswordAsync` barcha refresh tokenlarni bekor qilishi kerak edi, lekin `UserRepository.GetByIdAsync`
(`FindAsync`) tokenlarni yuklamasdi — bo'sh kolleksiya, hech narsa bekor qilinmasdi. O'g'irlangan sessiya parol almashgandan keyin ham ishlardi.
· TUZATILDI: `GetByIdAsync` agregatni (refresh tokenlar, tashqi loginlar) yuklaydi (ChangePasswordTests: avval yiqildi).

### B27 [O'RTA] Yaroqsiz Google/Facebook tokeni bilan kirish 500 qaytarardi
`ExternalAuthValidator` — Google `InvalidJwtException`, Facebook esa `System.InvalidOperationException` tashlardi; middleware ularni bilmasdi → 500
(muddati o'tgan token bilan oddiy kirish urinishi "server xatosi" bo'lib ko'rinardi va log'ni ifloslantirardi). Facebook buzilgan tokenga
HTTP 400 qaytaradi → 502. · TUZATILDI: `ExternalTokenException` → 401 `INVALID_EXTERNAL_TOKEN`; sozlanmagan provayder → `ConfigurationException`
(500 `CONFIGURATION_ERROR`); Facebook javobi yo'q → 502 (OAuthTokenErrorTests: avval 4/4 yiqildi).

### B29 [PAST] Istalgan foydalanuvchi boshqa akkauntning email va rolini o'qiy olardi
`GET /api/auth/user/{userId}` (gateway orqali ochiq) faqat `[Authorize]` edi; mijozlar uni ishlatmaydi (faqat ichki, ishlatilmaydigan
school-service `ValidationController`). · TUZATILDI: faqat o'zi yoki Admin, noto'g'ri id → 400 (UserLookupTests: avval yiqildi).

### B30 [PAST] Flutter: istalgan rol o'quvchi/o'qituvchi ekrani orqali kirardi
`login_as_student.dart` / `login_as_teacher.dart` javobdagi rolni tekshirmay `saveUserRole('student'|'teacher')` qilardi: o'qituvchi yoki
ota-ona o'quvchi dashboard'iga tushardi (ma'lumotni server himoya qiladi, lekin ekranlar bo'sh/xato). Bir xil kod har ekranda 3 marta takrorlangan.
· TUZATILDI: umumiy `finishSignIn` (lib/Login/sign_in_flow.dart) — mos kelmagan rol → sessiya yopiladi va to'g'ri kirish sahifasi aytiladi
(test/login_flow_test.dart: avval 2 ta rol testi yiqildi).

### B31 [O'RTA] Sinf materiallari va topshiriqlari sinfga a'zolikni tekshirmasdi
`GET /api/materials/classroom/{id}` istalgan tizimga kirgan foydalanuvchiga ochiq edi; o'quvchi o'zi o'qimaydigan sinf topshirig'iga ish
yuborishi mumkin edi; `Url`/`SubmissionUrl` istalgan sxemani (javascript:, data:) qabul qilardi — admin-web'da React bloklaydi, lekin boshqa
mijozlar uchun xavfli. · TUZATILDI: materiallar — Staff, sinfdagi o'quvchi, uning ota-onasi (`ProfileAccess.CanAccessClassroomAsync`);
a'zo bo'lmagan o'quvchiga material 404; `[SafeLink]` — faqat http(s) yoki oddiy fayl nomi (ClassroomContentAccessTests: avval 5 tasi yiqildi).

### B32 [PAST] O'quvchi va ota-ona barcha sinflarning e'lonlarini ko'rardi
`GET /api/announcements` classroomId'siz barcha sinf e'lonlarini, boshqa sinf id'si bilan o'sha sinfnikini qaytarardi.
· TUZATILDI: Staff'dan boshqalar — umumiy e'lonlar + o'z (farzandi) sinflari; boshqa sinf so'rovi 403, uning e'loni 404
(`ProfileAccess.GetVisibleClassroomIdsAsync`, materiallar bilan umumiy; AnnouncementVisibilityTests: avval 4/5 yiqildi).

### B33 [YUQORI] Flutter: o'qituvchining "Announce to parents" ekrani hech narsa yubormasdi
`announce_to_parents_role.dart` — "Announcement sent successfully!" deb ko'rsatib yopilardi, lekin API chaqirilmasdi; sinflar va darslar
qattiq yozilgan namunalar ("Grade 10 - Biology"). O'qituvchi ota-onalarga xabar berildi deb o'ylardi.
· TUZATILDI: o'qituvchining sinflari API'dan, darslar — tanlangan sinf materiallaridan (matnga "Lesson: ..." qo'shiladi), yuborish —
`POST /api/announcements` (darhol publish → o'quvchi va ota-onalarga bildirishnoma), xato bo'lsa sabab ko'rsatiladi. Fayl biriktirish backend'da yo'q —
muvaffaqiyat xabari buni ochiq aytadi (test/announce_to_parents_test.dart).

### B34 [YUQORI] Flutter: uy vazifasi ekranlari to'liq soxta
`homework_role.dart` (o'qituvchi) — qattiq yozilgan ro'yxat, "assign" faqat mahalliy ro'yxatga qo'shadi; `homework_student_role.dart` (o'quvchi) —
qattiq yozilgan topshiriqlar, "submit" faqat mahalliy belgi. Backend materiallar (Assignment) va topshiriqlarni qo'llaydi.
· TUZATILDI (F7, D16): o'qituvchi — o'z sinflari topshiriqlari, topshirganlar soni, muddatli yaratish; o'quvchi — o'z sinflari topshiriqlari,
havola/fayl nomi bilan topshirish; 0 o'quvchili sinfda 0 ga bo'linish ham tuzatildi (teacher_homework_test, student_homework_test).

### B35 [O'RTA] Materialni o'chirish o'quvchilarning topshiriqlari va baholarini kaskad o'chirardi
`MaterialRepository.DeleteAsync` → `Remove()`, `Submissions.MaterialId` FK = CASCADE; ro'yxat o'chirilgan/nofaol materiallarni ham qaytarardi.
· TUZATILDI: soft delete (`DeletedAt` + nofaol), ro'yxatda o'chirilganlar yo'q, nofaol — faqat Staff'ga; o'chirilgan materialga topshiriq 404 (HomeworkTests).

### B36 [O'RTA] Flutter: o'qituvchining dars/sinf tafsiloti ekrani soxta o'quvchilarni ko'rsatardi
`schedule_detail_role.dart` — Students tab'ida qattiq yozilgan 8 ta o'quvchi ("Alexander Pong") soxta davomat va ballar bilan, "Submissions 5 / N",
"Due Tomorrow", o'quvchilar soni doim 25. · TUZATILDI: sinf ro'yxati + bugungi davomat ("Not marked" holati) + shu fandagi oxirgi baho, oxirgi uy
vazifasi va topshirganlar soni, materiallar — API'dan (`ClassSnapshot`); 0 o'quvchida bo'linish himoyalangan (test/teacher_class_detail_test.dart).
Quick Actions: davomat, baholar, e'lon/bildirishnoma, o'quvchi qo'shish haqiqiy ekranlarni ochadi; backend'i yo'q amallar (Lesson Plan,
Class Notes, Edit Class Info, Export Report) "hali mavjud emas" deydi (avval hech narsa qilmasdi).

### B37 [O'RTA] Flutter: "Create Course" hech narsa yaratmasdi
`add_course_role.dart` — boshqa ilova shablonidan qolgan forma (narx, daraja, boshlanish sanasi, "Contemporary Dance" namunasi): `createSubject` faqat nom
yuborardi, backend esa `departmentId` talab qiladi → 400, xato jimgina yutilardi; "kurs" faqat mahalliy ro'yxatda turib, qayta ishga tushirganda yo'qolardi.
· TUZATILDI: "New Subject" formasi — nom, kafedra (API'dan), tavsif → haqiqiy `POST /subjects`, xato ko'rsatiladi; kurslar ro'yxati faqat haqiqiy fanlar;
ishlatilmay qolgan `course_model.dart` o'chirildi (test/add_subject_test.dart).

### B38 [YUQORI] Flutter: dars qoldirish (ruxsat) so'rovi hech kimga yetib bormasdi
`permision_student_role.dart` — so'rov faqat ekrandagi ro'yxatga qo'shilardi ("Pending" abadiy), tarix qattiq yozilgan namunalar; backend'da bunday tushuncha
yo'q edi. · TUZATILDI (F8, D17): backend `LeaveRequests`, Flutter ekran API'ga (leave_request_test), admin-web xodimlar ko'rib chiqish va ota-ona yuborish
sahifalari; lokal stekda uchidan-uchiga sinaldi (smoke 33/33).

### B39 [PAST] Flutter: o'qituvchi bildirishnomalari soxta edi
`notifications_role.dart` — qattiq yozilgan namunalar ("Sok Pong has requested a 2-day leave", "Urgent Meeting"). · TUZATILDI: kutilayotgan dars qoldirish
so'rovlari API'dan, detal oynasida Approve/Decline (oila xabardor qilinadi); manbasi yo'q "System/Urgent" toifalari olib tashlandi
(test/teacher_notifications_test.dart).

### B40 [PAST] Flutter: o'qituvchining "Parent Management" formasi hech narsa qilmasdi
`link_parent_role.dart` — yangi ota-ona yaratish / bog'lash formasi, "Submit" `onTap: () {}`; o'qituvchida bu huquq yo'q (D10 — faqat Admin).
· TUZATILDI: ekran ota-onalar ma'lumotnomasiga aylantirildi — o'quvchini qidirish, bog'langan ota-onalar (ism, kimligi, email) `GET /students/{id}/parents`
orqali; bog'lanmagan bo'lsa, admin bog'lashi aytiladi (test/parents_directory_test.dart).

### B41 [PAST] Flutter: o'quvchi bosh sahifasi soxta "progress" va tadbirlarni ko'rsatardi
`student_dashboard.dart` — doim "Advanced Mathematics II 75%", "View All" ro'yxati 3 ta soxta kurs, kurs tafsilotida soxta boblar; "School Events" va
"See All" — qattiq yozilgan tadbirlar (Annual Sports Day, soxta qatnashchilar soni). · TUZATILDI: progress — o'quvchining haqiqiy baholari (oxirgisi
bosh sahifada, barchasi "View All"da, tafsilotda ball va semestr); tadbirlar — e'lon qilingan e'lonlar (`GET /api/announcements`, umumiy + o'z sinflari),
nishonda muallif (test/student_home_test.dart). Regressiya (tafsilot ekrani muallifni 500 ga bo'lardi) 6eb3b2f da tuzatildi.
"Recent Activity" (soxta laboratoriya mashg'ulotlari va A+ baholar) — o'quvchining haqiqiy baholari, filtrlar fanlardan va haqiqatan filtrlaydi.
O'qituvchi bosh sahifasi tadbirlari ham e'lonlardan (faqat e'lon qilinganlar, qoralamalar emas), standart ism "Alexander Smith" → "Teacher" (teacher_home_test).

### B42 [YUQORI] Flutter: "Messages" tab'lari soxta chat edi
`teacher_dashboard.dart` (`TeacherMessagesTab`, `TeacherChatDetailScreen`) va `student_dashboard.dart` (`StudentMessagesTab`, `StudentChatDetailScreen`) —
qattiq yozilgan suhbatlar (ota-onalar, o'quvchilar, hamkasblar) va "yuborilgan" xabar faqat ekranga qo'shilardi; backend'da xabar almashish yo'q.
O'qituvchi ota-onaga yozdim deb o'ylashi mumkin edi. · TUZATILDI: tab'lar "hali mavjud emas" deydi va ishlaydigan kanallarga yo'naltiradi
(o'qituvchi — e'lon yuborish, bildirishnomalar; o'quvchi — bildirishnomalar, dars qoldirish so'rovi); soxta chat kodi (~1500 qator) olib tashlandi
(git tarixida qoladi). Keyin haqiqiy xabarlar qilindi (F9, D18): tab'lar `MessagesScreen` — suhbatlar, kontaktlar, chat (test/messages_tab_test.dart).

### B43 [YUQORI] O'quvchi istalgan sinf ro'yxatini sinfdoshlarning shaxsiy ma'lumotlari bilan olardi
`GET /api/school/classrooms/{id}` faqat `[Authorize]` edi: har qanday o'quvchi (yoki ota-ona) istalgan sinfni ochib, o'quvchilarning email, telefon, jinsi va
tug'ilgan sanasini olardi (voyaga yetmaganlar PII); `GET /classrooms` butun maktab sinflarini berardi. admin-web "maxfiylik uchun" faqat ismlarni ko'rsatardi,
lekin API hammasini yuborardi. · TUZATILDI: Staff'dan boshqalar faqat o'z (farzandi) sinflarini ko'radi (boshqasi 403), ro'yxatda faqat ism va holat
(ClassroomPrivacyTests: avval 4/5 yiqildi).

### B44 [O'RTA] Flutter: dars jadvali bo'sh kun/vaqt bilan va boshqa sinfniki edi
`ScheduleDto.fromJson` `day`/`time` ni o'qirdi, API esa `dayOfWeekName`, `startTime`, `endTime` yuboradi — kun va vaqt doim bo'sh, "bugungi darslar"
(o'quvchi va o'qituvchi jadvallari) hech qachon mos kelmasdi; o'quvchi jadvali butun maktab ro'yxatidagi birinchi sinfnikini ko'rsatardi.
· TUZATILDI: haqiqiy maydonlar o'qiladi ("09:00 - 10:30"), o'quvchi jadvali o'zining barcha sinflaridan yig'iladi (test/schedule_test.dart).

### B45 [O'RTA] Parolni tiklashda yangi parolga talab yo'q edi
`ResetPasswordRequestDto.NewPassword` faqat `[Required]` — tiklash kodi bilan 1 belgili parol qo'yish mumkin edi; ro'yxatdan o'tish DTO'sida ham cheklov yo'q;
login va admin yaratishda yuqori chegara yo'q edi (ulkan kiritma PBKDF2'ni behuda yuklaydi). · TUZATILDI: yangi parollar 8–200 belgi (tiklash, ro'yxat,
admin yaratish), login paroli ≤ 200; Flutter tiklash formasi 6 → 8, admin-web formasi `minLength` va server validatsiya xatosini ko'rsatadi
(PasswordResetTests: avval 2 tasi yiqildi).

### B46 [PAST] Uzun ism yoki email bilan akkaunt yaratish 500 qaytarardi
auth `Users.Username` (ism + familiya) ≤ 50, `Email` ≤ 100, DTO'larda esa chegara yo'q — PostgreSQL "value too long" → 500 (SQLite testlari buni ko'rmasdi).
50 belgi to'liq ism uchun kam. · TUZATILDI: `Username` 101 gacha kengaytirildi (migratsiya `WidenUsername`, Down bilan; PostgreSQL'da up/down sinaldi),
DTO'larda email ≤ 100, ism/familiya ≤ 50 → 400; OAuth display name 101 gacha qisqartiriladi. Boshqa maydonlar skript bilan tekshirildi — mos.

### B47 [O'RTA] Flutter: o'qituvchining "Today's Classes" bloki o'ylab topilgan vaqtlarni ko'rsatardi
`teacher_dashboard.dart` `_buildClassData` — har bir sinfga indeks bo'yicha soxta vaqt ("07:00 - 08:00"...) berib, "tugagan/hozir" belgilarini shundan
hisoblardi; uy vazifasi ("Review chapter N exercises"), materiallar ("Textbook", "Worksheet N"), xona ("Room N") ham soxta; sinf tafsilotida qattiq "/ 40"
sig'im. · TUZATILDI: o'qituvchining bugungi haqiqiy jadvali (`GET /schedules?teacherId=`), haqiqiy vaqtdan holat; soxta vazifa/material/sig'im olib
tashlandi; bo'sh kun uchun "No classes on your timetable today" (teacher_home_test).

### B48 [YUQORI] Istalgan o'qituvchi istalgan o'quvchiga baho qo'yar, istalgan sinf davomatini belgilardi
Baho (POST/PUT/DELETE), davomat (`attendance/mark`) va sinfga yozish/chiqarish faqat rol bo'yicha (`Staff`) tekshirilardi — o'qituvchi boshqa
o'qituvchining o'quvchisiga baho qo'yishi, uni o'chirishi yoki boshqa sinf ro'yxatini o'zgartirishi mumkin edi (D4 dagi resurs darajasidagi qoida yo'q edi).
· TUZATILDI: o'qituvchi faqat o'zi o'qitadigan sinflar (sinf rahbari yoki jadvalda dars bor) va ulardagi faol o'quvchilar uchun yoza oladi, aks holda 403;
maktab profili yo'q o'qituvchi akkaunti — 403; admin cheklanmagan (TeacherScopeTests: avval 5/6 yiqildi).

### B49 [KRITIK] Flutter veb ilovasida (3200) hech kim kira olmasdi — "Null check operator used on a null value"
`ApiService` tokenlarni `flutter_secure_storage` ga yozadi; uning veb versiyasi `crypto.subtle` (Web Crypto) bilan shifrlaydi, brauzer esa uni faqat
secure context'da (HTTPS yoki localhost) beradi. Server HTTP (`http://168.222.143.80:3200`) — `crypto.subtle` = undefined, birinchi yozishda yiqiladi.
Lokal `localhost` da va mobil'da ishlagani uchun sezilmagan. Headless Chrome bilan `http://school.test` (insecure) da qayta hosil qilindi, 127.0.0.1 da ishladi.
· TUZATILDI: vebda secure context bo'lmasa `LocalStorageFallback` (to'g'ridan-to'g'ri localStorage; plugin kalitni baribir localStorage da saqlaydi) —
`lib/services/app_storage*.dart`, brauzer testi `test/app_storage_web_test.dart` (`--platform chrome`). Insecure origin'da o'qituvchi va o'quvchi
dashboard'ga kiradi, reload'dan keyin sessiya saqlanadi. To'liq yechim — HTTPS (Q3).
