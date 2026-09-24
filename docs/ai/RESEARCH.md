# RESEARCH

Sana: 2026-09-25. Soha: maktab/o'quv muassasasini boshqarish (SIS + elektron jurnal + portal).

## 1. Raqobatchilar

### Mahalliy (O'zbekiston / Markaziy Osiyo)
| Platforma | Asosiy imkoniyatlar | Bizda yo'q |
|---|---|---|
| **eMaktab / Kundalik** (emaktab.uz) | Elektron jurnal va kundalik: baho, uy vazifasi, davomat, izohlar, e'lonlar; ota-ona va o'quvchi 24/7 kuzatadi; o'qituvchi uchun **oflayn** ishlaydigan "eMaktab.Jurnal" ilovasi; ota-onalar uchun "Kundalik.Family" ilovasi va xabarlar; ota-ona bilan tezkor muloqot | Ota-ona portali, uy vazifasi → ota-onaga ko'rinishi, bildirishnomalar, oflayn rejim, muloqot |

### Xalqaro
| Platforma | Kuchli tomoni | Bizga dars |
|---|---|---|
| **PowerSchool** | Katta tumanlar uchun SIS, hisobotlar, compliance | Hisobotlar, audit |
| **Fedena** | 50+ modul: SIS, davomat, jadval, imtihon, gradebook, to'lov, kutubxona, transport | Imtihon/hisobot kartasi, to'lovlar |
| **OpenSIS / Gibbon** (open-source) | Bitta o'quvchi yozuvi, davomat, jadval, o'qituvchi baho kiritishi, oila portali | Oila (ota-ona) portali |
| **ManageBac** | Ota-ona portali (baho, izoh, davomat, topshiriqlar), baholar ochilganda email bildirishnoma, curriculum-ga bog'langan report card, "proofing" | Baho bildirishnomalari, report card |
| **Google Classroom / Moodle** | Topshiriq tarqatish, LMS, gradebook eksporti | Topshiriq/submission oqimi (bizda bor, lekin buzilgan — B9) |

Umumiy "must-have" ro'yxati (Gradelink 2026 sharhi): SIS, gradebook + report card, davomat, jadval/ro'yxatga olish,
ota-ona/o'quvchi portali + bildirishnomalar, mobil ilova, xavfsizlik (shifrlash, GDPR/FERPA-ga o'xshash talablar).

## 2. Rasmiy dokumentatsiya bo'yicha tavsiyalar

| Mavzu | Tavsiya | Bizdagi holat | Manba |
|---|---|---|---|
| EF Core migratsiyalar | Production uchun **migration bundle** yoki (review kerak bo'lsa) **idempotent SQL script**. `EnsureCreated()` migratsiyalarni chetlab o'tadi va keyin `Migrate()` ishlamaydi. Startup'da `Migrate()` — faqat oddiy deploy uchun maqbul (EF 9+ lock bor). Rollback: `efbundle <PrevMigration>` yoki `migrations script <from> <to>` | school-service: `EnsureCreated` + qo'lda SQL (B11); auth: startup'da `Migrate()` | [Applying Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying) |
| Rate limiting | Built-in `Microsoft.AspNetCore.RateLimiting`: `AddRateLimiter` + named policy + `[EnableRateLimiting]`; `UseRateLimiter()` `UseRouting` dan keyin; `RejectionStatusCode = 429`; foydalanuvchi kiritgan qiymat bo'yicha cheksiz partition — DoS xavfi | yo'q (B3) | [Rate limiting middleware](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit) |
| Proksi ortida IP | Gateway/nginx ortida `ForwardedHeaders` middleware va ishonchli proksi tarmoqlari kerak, aks holda hamma so'rov bitta IP'dan keladi | sozlanmagan | [Proxy and load balancer config](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer) |
| Avtorizatsiya | Rol/policy asosidagi `[Authorize(Roles=...)]` yoki `AddAuthorization` policy'lari; resurs-darajasida tekshiruv uchun `IAuthorizationService` | faqat `[Authorize]` (B1) | [Role-based authorization](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/roles) |
| Integration test | `WebApplicationFactory<Program>` (Microsoft.AspNetCore.Mvc.Testing) + test DB (Testcontainers PostgreSQL yoki in-memory) | test yo'q | [Integration tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests) |
| Next.js Docker | `output: 'standalone'` — kichik image, `node server.js`; xavfsizlik headerlari `headers()` orqali | to'liq `node_modules` bilan image | [Next.js deploying / output](https://nextjs.org/docs/app/api-reference/config/next-config-js/output) |
| JWT | Kalit majburiy, kamida 256-bit; secret bo'lmasa ishga tushmaslik | hardcode fallback (B2) | [JWT bearer auth](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication) |

## 3. Funksiyalar: Majburiy / Muhim / Kelajakda

### Majburiy (xavfsizlik va asosiy oqimlar ishlashi uchun)
1. Rolga asoslangan ruxsat school-service'da (B1) — o'quvchi baho/davomat o'zgartira olmasin.
2. Topshiriq (submission) oqimini tuzatish (B9) — o'quvchi topshiradi, o'qituvchi baholaydi.
3. Login va kod endpointlarida rate limiting (B3).
4. School DB uchun haqiqiy EF migratsiyalar va rollback (B11) + unique cheklovlar (B16).
5. Backup skripti va deploy runbook (B15).

### Muhim (raqobatchilarda bor, bizda yo'q)
1. **Ota-ona (Parent) portali** — `Parent` roli mavjud, lekin UI/API yo'q: farzand(lar)ini bog'lash, baho, davomat,
   e'lonlarni ko'rish (eMaktab, ManageBac, Gibbon).
2. **Bildirishnomalar** — yangi baho / qoldirilgan dars / e'lon haqida (avval in-app, keyin email).
3. **Report card / o'zlashtirish hisoboti** — o'quvchi bo'yicha semestr baholari, o'rtacha, davomat foizi (CSV/PDF eksport).
4. **Audit log** — kim qaysi bahoni o'zgartirdi (baho yaxlitligi).

### Kelajakda
- O'qituvchi uchun oflayn jurnal (Flutter, sinxronlash bilan).
- To'lovlar / kontrakt (Fedena) — pullik tashqi xizmat → ruxsat kerak.
- Ota-ona ↔ o'qituvchi chat, push-bildirishnomalar (FCM — tashqi xizmat → ruxsat kerak).
- Ko'p filial (multi-campus), SSO.

## Manbalar
- eMaktab: [Biz haqimizda](https://emaktab.uz/about), [Kundalik.Family ilovasi](https://emaktab.uz/news/331), [Ota-onalar so'rovi](https://emaktab.uz/news/325)
- [15 Best School Management Software for 2026 — Gradelink](https://gradelink.com/15-best-school-management-software-for-2026/)
- [Fedena vs openSIS](https://www.softwaresuggest.com/compare/fedena-vs-opensis), [Open-source SMS 2026](https://geeksourcecodes.com/6-best-open-source-school-management-systems-2026/)
- [ManageBac vs Google Classroom vs Teams vs SIS](https://www.managebac.com/blog/managebac-vs-google-classroom-vs-microsoft-teams-vs-your-sis-whats-the-difference), [What do Students & Parents see on ManageBac](https://help.managebac.com/hc/en-us/articles/360042554471-What-do-Students-Parents-See-on-ManageBac)
- Microsoft Learn: [Applying Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying), [Rate limiting](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit)
