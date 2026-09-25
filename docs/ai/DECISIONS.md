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
