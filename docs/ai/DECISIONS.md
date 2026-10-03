# DECISIONS — texnik qarorlar

Format: `Dn — sarlavha (sana)` · Qaror · Sabab · Manba.

## D1 — ai-loop.sh ishlash tartibi (2026-09-24)
**Qaror:** `claude -p ... --permission-mode auto` ishlatiladi. Loop faqat PROGRESS.md da *qator boshida*
`RUXSAT KERAK` bo'lsa to'xtaydi; oddiy ruxsat so'rovlari QUESTIONS.md ga yoziladi va PLAN.md da `[!]` bilan
belgilanadi, shunda boshqa xavfsiz vazifalar davom etadi. Limit so'zi muvaffaqiyatli yurishda faqat oxirgi
3 qatorda qidiriladi. PROGRESS.md 3 marta ketma-ket o'zgarmasa loop to'xtaydi (bo'sh aylanishni oldini olish).
**Sabab:** eski skript `grep -i limit` bilan har qanday matnda ("rate limiting" vazifasi) 30 daqiqa kutardi,
`acceptEdits` rejimida esa Bash buyruqlari (build, test, git) `-p` rejimida rad etilardi. Eski PROGRESS.md
dagi "RUXSAT KERAK" qatori loop'ni doim to'xtatib qo'yardi.
**Manba:** `claude --help` (v2.1.281) — `--permission-mode` tanlovlari: acceptEdits, auto, bypassPermissions,
manual, dontAsk, plan.

## D2 — Egasining commit qilinmagan o'zgarishlari (2026-09-24)
**Qaror:** `main` dagi 9 ta commit qilinmagan faylga tegilmaydi va ular commit qilinmaydi; faqat o'zim
o'zgartirgan fayllar `git add <yo'l>` bilan qo'shiladi. QUESTIONS.md Q1 da so'raldi.
**Sabab:** ular kimning ishi ekani noma'lum; ularni o'z commitlarimga aralashtirish muallifni yo'qotadi.

## D3 — Server ma'lumotlari repoga yozilmaydi (2026-09-24)
**Qaror:** `docs/server_key.md` (SSH manzili) `.gitignore` ga qo'shildi; hujjatlarda server IP/port yozilmaydi,
faqat "docs/server_key.md dagi host" deb murojaat qilinadi.
**Sabab:** repo GitHub'da (origin/fork/upstream) — IP, port va kalit nomi hujum yuzasini ochadi.

## D4 — School-service rol matritsasi (2026-09-25)
**Qaror:** `[Authorize(Roles = Roles.Staff|Roles.Admin)]` atributlari (mavjud uslubga mos, `SchoolService.API/Authorization/Roles.cs`).
- **Staff (Admin+Teacher):** o'quvchi yaratish/tahrirlash, fan yaratish va o'qituvchi biriktirish, sinf yaratish/tahrirlash,
  enroll/unenroll, jadval, davomat (sinf varag'i + belgilash), baholar, e'lonlar, materiallar, topshiriqni baholash.
- **Admin:** o'quvchi/o'qituvchini o'chirish, o'qituvchi yaratish, fanni tahrirlash/o'chirish, fandan o'qituvchini olish, sinfni o'chirish
  (+ avvaldan: kafedralar, xonalar, admin sync, service health).
- **Own:** o'quvchi `PUT /students/{id}` faqat o'ziniki (`AuthUserId == sub`), `email`/`isActive` o'zgarmaydi;
  o'qituvchi `PUT /teachers/{id}` faqat o'ziniki, `email`/`isActive`/`hireDate` o'zgarmaydi.
**Sabab:** eng kam imtiyoz; o'chirish kaskad bilan akademik tarixni yo'q qiladi (B17) — faqat Admin. Mijozlar tahlil qilindi:
admin-web teacher/student sahifalari va Flutter o'qituvchi ekranlari ishlatadigan barcha yozish amallari Staff'da qoldi;
yagona uzilish — Flutter o'qituvchining "o'quvchini o'chirish" tugmasi, u olib tashlandi.
Keyingi bosqich (B1b): o'qish endpointlarida o'quvchi faqat o'z ma'lumotini ko'rishi; o'qituvchi faqat o'z sinflarini o'zgartirishi (resurs darajasi).
**Manba:** [Role-based authorization in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/roles), OWASP A01.

## D5 — Auth rate limiting va real mijoz IP'si (2026-09-25)
**Qaror:** ikki qatlam.
1. **Per-IP limiter** (built-in `Microsoft.AspNetCore.RateLimiting`, fixed window, navbatsiz): `login` 60/daq
   (authenticate, oauth/*), `codes` 20/10 daq (request-*, verify-email, reset-password), `refresh` 120/daq.
   `RateLimiting:<policy>:PermitLimit|WindowSeconds` bilan sozlanadi. 429 + `Retry-After` + `{code: "TOO_MANY_REQUESTS"}`.
   Limitlar ataylab yumshoq: butun maktab bitta NAT IP ortida bo'lishi mumkin.
2. **Akkaunt lockout** — ketma-ket 5 xato parol → 5 daqiqa 429 `ACCOUNT_LOCKED` (to'g'ri parol ham rad etiladi), muvaffaqiyatli
   kirish hisobni nollaydi. Bu akkaunt mavjudligini bildiradi (mavjud bo'lmagan email hech qachon bloklanmaydi) — ro'yxatdan o'tish yopiq
   va emaillar maktab tomonidan beriladi, shuning uchun qabul qilindi. Migratsiya `AddLoginLockout` (Down bilan).
**Real IP:** gateway va auth `UseForwardedHeaders()` bilan faqat xususiy tarmoqlardan (10/8, 172.16/12, 192.168/16, loopback)
kelgan `X-Forwarded-For` ga ishonadi, `ForwardLimit=1`. Ma'lum cheklov: Next.js `x-forwarded-for ??= socket` qiladi, ya'ni
admin-web'ga to'g'ridan-to'g'ri yuborilgan soxta XFF saqlanadi → admin-web orqali IP limitni chetlab o'tish mumkin.
Oldiga nginx qo'yilganda u XFF ni **almashtirishi** kerak (`proxy_set_header X-Forwarded-For $remote_addr;`), qo'shmasligi.
web-app nginx `$proxy_add_x_forwarded_for` qo'shadi — o'ngdagi qiymat haqiqiy, xavfsiz.
**Manba:** [Rate limiting middleware](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit),
[Configure ASP.NET Core to work with proxy servers](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer),
OWASP Authentication Cheat Sheet (login throttling).

## D6 — school_db: squash emas, baseline (2026-09-25)
**Qaror:** mavjud 6 ta migratsiya saqlanadi; `EnsureCreated` bilan yaratilgan bazalar uchun startup'da bir martalik baseline
(`LegacySchemaBaseline`): eski idempotent SQL + history'ga `20260409091051_Add_Department_Entity_And_Relationships` gacha
bo'lgan migratsiyalarni yozish, keyin `MigrateAsync()`.
**Sabab:** vaqtinchalik PostgreSQL 16'da migratsiyalar zanjiri va `EnsureCreated` sxemasi normallashtirilgan holda (ustunlar,
turlar, nullability, indekslar, cheklovlar) solishtirildi — bir xil (faqat DEFAULT qiymatlar farqi). Production sxemasi ham
(read-only so'rov) aynan shu. Squash tarixni yo'qotardi va dasturchilarning lokal bazalarini buzardi. Startup'da migratsiya
auth-service bilan bir xil yondashuv; EF 9+ migratsiya lock'i bor.
**Nozik joy:** Npgsql 10 da `IHistoryRepository.ExistsAsync()` jadval yo'q bo'lsa ham `true` qaytaradi — shuning uchun `to_regclass`.
**Manba:** [Applying Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
("Don't call EnsureCreated before Migrate").

## D7 — `POST /grades` upsert (2026-09-25)
**Qaror:** (student, fan, semestr) uchun baho allaqachon bo'lsa, POST uni yangilaydi va 200 qaytaradi (yangi bo'lsa 201).
**Sabab:** `StudentGrade` — semestr yakuniy bahosi; Flutter va admin-web qayta kiritishda POST yuboradi (`updateGrade` ishlatilmaydi),
409 qaytarish o'qituvchi oqimini buzardi. Unique indeks poyga holatida 409 bilan himoya qiladi.

## D8 — Soft delete aniq filtr bilan, global query filter'siz (2026-09-25)
**Qaror:** `StudentRepository`/`TeacherRepository` barcha o'qishlarni `DeletedAt == null` bilan cheklaydi; `DeleteAsync` =
`SoftDelete()` + `Deactivate()` (+ o'quvchining faol yozilishlari `Dropped`). Email unique indeksi o'chirilganlarni hisobga olmaydi.
**Sabab:** global filter majburiy navigatsiyalarda (StudentGrade→Student va h.k.) EF ogohlantirishi va INNER JOIN orqali
baholar/e'lonlarni kutilmaganda yashirardi. Aniq filtr ta'sir doirasini faqat profil endpointlari bilan cheklaydi;
tarixiy yozuvlar (baho, davomat) ro'yxatlarda qoladi.
**Manba:** [Global query filters — required navigation](https://learn.microsoft.com/en-us/ef/core/querying/filters#accessing-entity-with-query-filter-using-required-navigation)

## D9 — admin-web lint ogohlantirishlari qoldiriladi (2026-09-25)
**Qaror:** `react-hooks/set-state-in-effect` (16), `exhaustive-deps` (3), `no-location-assign` (2) — o'zgartirilmaydi.
**Sabab:** egasi 5801210 da `set-state-in-effect` ni ataylab `warn` qilgan; bular `useEffect(() => { load() }, [])` yuklash naqshi,
`localStorage` ni mount'dan keyin o'qish (hydration uchun zarur) va sign-out'dan keyin to'liq qayta yuklash. UI testlarisiz 16 sahifani
qayta yozish regressiya xavfi foydadan katta. `auth.js` dagi `allowedRoles` dependency'si qo'shilsa, har renderda yangi massiv sabab
effect cheksiz qayta ishga tushadi — izohda aytilgan. Xatolar (errors) 0 — CI o'tadi.

## D10 — F1: ota-ona (Parent) portali dizayni (2026-09-25)
**Qaror:** alohida Parent profili yaratilmaydi; school_db ga `StudentParents` bog'lanish jadvali qo'shiladi:
`Id, StudentId (FK → Students, cascade), ParentAuthUserId (auth user id), FullName, Email, Relationship, CreatedAt`,
unique (StudentId, ParentAuthUserId). Ota-onaning shaxsi JWT `sub` dan olinadi.
- Admin: `GET/POST /api/school/students/{id}/parents`, `DELETE /api/school/students/{id}/parents/{parentAuthUserId}`.
- Parent: `GET /api/school/parents/me/children`. Mavjud o'qish endpointlari (`students/{id}`, `students/{id}/classrooms`,
  `grades?studentId=`, `attendance/{id}/history`, `submissions/student/{id}`) `ProfileAccess.CanAccessStudentAsync` orqali
  bog'langan farzand uchun ochiladi; `grades` da Parent `studentId` ni ko'rsatishi shart.
- admin-web: `/parent/*` sahifalari (farzandlar, baho, davomat), login'da `role 3`, admin o'quvchi sahifasida "Parents" bo'limi
  (auth'dagi Parent akkauntlaridan tanlash).
**Sabab:** eng kichik o'zgarish bilan raqobatchilardagi asosiy funksiya (RESEARCH "Muhim" 1); ota-ona ma'lumoti auth'da bor,
dublikat profil sinxronlash muammosini yaratardi. Flutter ota-ona ilovasi — Kelajakda.

## D11 — F3: ilova ichidagi bildirishnomalar (2026-09-25)
**Qaror:** school_db `Notifications` (StudentId, ParentAuthUserId null=o'quvchiga / aks holda ota-onaga, Type, Title, Body, CreatedAt, ReadAt).
Yaratiladi: baho qo'yilganda/ball o'zgarganda, "kelmadi"/"kechikdi" birinchi marta belgilanganda, sinf e'loni birinchi publish'da
(o'quvchi + bog'langan ota-onalar). Best-effort: xato log qilinadi, asosiy amal buzilmaydi. API: `GET /api/school/notifications`,
`GET .../unread-count`, `POST .../{id}/read`, `POST .../read-all` (Student, Parent).
**Sabab:** eMaktab/ManageBac'dagi asosiy imkoniyat; o'quvchi manzili `AuthUserId` ga emas `StudentId` ga bog'langani uchun bog'lanmagan
seed profillar ham ishlaydi. Email/push — tashqi xizmat (Gmail allaqachon sozlangan, lekin ommaviy yuborish limitlari) → Kelajakda.
Eslatma: umumiy (sinfsiz) e'lonlar hozircha bildirishnoma yaratmaydi — butun maktabga fan-out keyinroq (queue bilan).

## D12 — F5: baho o'zgarishlari audit log'i (2026-10-03)
**Qaror:** alohida `GradeChanges` jadvali (append-only, FK'siz): baho yaratilganda, ball/semestr o'zgarganda va o'chirilganda
`GradeService` bitta yozuv qo'shadi — kim (`sub`, username, rol `ICurrentActor` orqali tokendan), qachon, eski → yangi ball.
Yozuv bahoning o'zi bilan bitta `SaveChanges` da saqlanadi (`IGradeChangeRepository.Stage`) — baho saqlanmasa audit ham yo'q,
audit yozilmasa baho ham saqlanmaydi. Bir xil ballni qayta saqlash yozilmaydi. API: `GET /grades/{id}/history` (Staff),
`GET /grades/changes` (faqat Admin — maktab bo'yicha nazorat). O'quvchi/ota-ona audit'ni ko'rmaydi (xodimlar ichki ma'lumoti).
admin-web: `/admin/grade-changes`.
**Sabab:** RESEARCH "Muhim" 4 (PowerSchool audit, baho yaxlitligi). Umumiy EF `SaveChanges` interceptor (barcha jadvallar uchun)
o'rniga aniq domen yozuvi: o'qiladigan tarix (eski/yangi ball), kam shovqin, test qilish oson. FK yo'qligi — baho o'chirilgandan
keyin ham tarix qoladi. Fan baholarga RESTRICT bilan bog'langan, o'quvchi soft delete — ya'ni API orqali baho faqat
`DELETE /grades/{id}` bilan yo'qoladi va u yoziladi. Tarix oldingi baholar uchun yo'q (backfill qilinmaydi — muallif noma'lum).
**Manba:** OWASP Logging Cheat Sheet (kim/nima/qachon, o'zgartirib bo'lmaydigan audit), [EF Core — Saving data / transactions](https://learn.microsoft.com/en-us/ef/core/saving/transactions) (bitta `SaveChanges` = bitta tranzaksiya).

## D13 — F4: o'quvchi hisobot kartasi (2026-10-03)
**Qaror:** `GET /api/school/students/{id}/report-card` (JSON) va `.../report-card/csv` — Staff, o'quvchining o'zi, bog'langan ota-ona
(`ProfileAccess`). Baholar semestr bo'yicha (`semester` bo'lmasa — hammasi), davomat `from`/`to` sana oralig'i bo'yicha: semestr bu
erkin matn ("1", "Semester 1 2025-2026"), sanalarga bog'lanmagan, shuning uchun davomatni semestr bilan filtrlab bo'lmaydi.
Harf/GPA shkalasi `GradeScale` — admin-web `student-portal.js` dagi bilan aynan bir xil (ota-ona va o'quvchi ekranidagi raqamlar mos
kelishi uchun); davomat foizi ham o'sha formula (kechikish "kelgan" hisoblanmaydi). CSV: RFC 4180, UTF-8 BOM (Excel kirill/o'zbek
harflari), formula bilan boshlanadigan katakchalarga `'` (OWASP CSV injection). PDF — brauzerning "Print → PDF" orqali (yangi kutubxona yo'q).
**Sabab:** RESEARCH "Muhim" 3 (Fedena/ManageBac report card). Server tomonda hisoblash — bitta haqiqat manbai, ota-ona/admin uchun
bir xil natija; ko'p sahifali UI hisoblarini takrorlamaslik.
**Manba:** [RFC 4180](https://www.rfc-editor.org/rfc/rfc4180), [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

## D14 — Refresh token qayta ishlatilishini aniqlash va tozalash (2026-10-03)
**Qaror:** rotatsiya qilingan (bekor) refresh token yana kelsa va bekor qilinganiga 30 soniyadan ko'p bo'lgan bo'lsa — foydalanuvchining
barcha faol refresh tokenlari bekor qilinadi (barcha sessiyalar tugaydi) va ogohlantirish log'i yoziladi. 30 soniya ichida takroriy
yuborish (double submit, eski ilova versiyasidagi poyga) — oddiy 401, sessiya saqlanadi. Yangi token berilganda muddati o'tgan tokenlar
agregatdan o'chiriladi (bekor, lekin muddati o'tmaganlari reuse aniqlash uchun 7 kungacha qoladi). Parol almashtirish/tiklash
`RevokeAllRefreshTokens()` ni ishlatadi (avval allaqachon bekor bo'lganlarning vaqtini ham qayta yozardi).
**Sabab:** o'g'irlangan refresh token bilan hujumchi va haqiqiy foydalanuvchi navbatma-navbat rotatsiya qilsa, birinchi takror ishlatishda
ikkalasi ham chiqariladi. Ikkala mijozda bitta in-flight refresh bor (B20, B26) — oddiy foydalanishda takror yuborish bo'lmaydi.
Tozalashsiz har refresh foydalanuvchining barcha eski tokenlarini yuklardi (soatiga bitta qator o'sish). Migratsiya kerak emas.
**Manba:** [RFC 9700 — OAuth 2.0 Security BCP §4.14.2](https://www.rfc-editor.org/rfc/rfc9700#section-4.14.2) (refresh token rotation, reuse detection).

## D15 — F6: Google/Facebook akkauntini bog'lash (2026-10-03)
**Qaror:** auth-service'da `GET /api/auth/logins`, `POST /api/auth/logins/{provider}` (`{token}`), `DELETE /api/auth/logins/{provider}` —
faqat tizimga kirgan foydalanuvchi o'zi uchun. Token o'sha validator bilan tekshiriladi (Google imzo + audience, Facebook `debug_token`).
Bitta provayderdan bitta akkaunt; boshqa foydalanuvchiga bog'langan identity → 409; parolsiz foydalanuvchining oxirgi logini o'chirilmaydi.
Bog'lashda email solishtirilmaydi — egalik provayder tokeni va foydalanuvchining joriy sessiyasi bilan isbotlanadi.
**Sabab:** B4 dan keyin Facebook email bo'yicha bog'lanmaydi, ya'ni admin yaratgan akkauntga Facebook bilan kirishning yagona yo'li — oldindan
bog'lash. **UI:** admin-web login sahifasidagi Google/Facebook tugmalari hozircha placeholder; Google Identity Services veb-origin sifatida
IP manzilni qabul qilmaydi, shuning uchun veb-UI domen/TLS (QUESTIONS Q3) dan keyin qilinadi. Flutter `google_sign_in`/`flutter_facebook_auth`
paketlari bor — ilova profil ekraniga ulash keyingi qadam.
**Manba:** [Google — Verify the Google ID token](https://developers.google.com/identity/sign-in/web/backend-auth),
[Meta — debug_token](https://developers.facebook.com/docs/facebook-login/guides/%20access-tokens/debugging), OWASP ASVS V2 (account linking).
