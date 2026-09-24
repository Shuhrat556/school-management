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
