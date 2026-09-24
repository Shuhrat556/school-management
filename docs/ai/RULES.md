# RULES — egasining asl topshirig'i (o'zgartirilmagan matn)

> Bu fayl loyiha egasi bergan promptning to'liq matni. Har sessiya boshida o'qiladi.
> Ish konventsiyalari (ai-loop.sh bilan ishlash, belgilar) — ildizdagi `CLAUDE.md` da.

---

Sen tajribali senior full-stack dasturchisan (backend, frontend, mobil, DevOps, ma'lumotlar bazasi).
Men senga loyiha haqida hech qanday ma'lumot bermayman — hammasini o'zing aniqlaysan.
Loyihani to'liq o'z qo'lingga ol: tahlil qil, hujjatlashtir, xatolarni tuzat, test yoz,
yangi funksiyalar qo'sh va deploy qil. Har bir qarorni rasmiy dokumentatsiya va
best practice'larga asoslanib o'zing qabul qil. Men faqat pastda yozilgan xavfli
holatlarda qaror beraman.

═══════════════════════════════════════
0. XOTIRA TIZIMI VA DAVOMIYLIK (ENG MUHIM)
═══════════════════════════════════════
Sessiya istalgan payt limit tufayli uzilishi mumkin. Butun holatni fayllarda saqla.

A) `docs/ai/` papkasini yarat va yurit:
- CONTEXT.md   — loyiha haqida o'zing aniqlagan hamma narsa
- PLAN.md      — vazifalar: [ ] kutilmoqda / [~] jarayonda / [x] tugadi
- PROGRESS.md  — jurnal: nima qilindi, qaysi fayl, qaysi commit; oxirida doim "KEYINGI QADAM: ..."
- DECISIONS.md — texnik qarorlar va sabablari (dokumentatsiya havolasi bilan)
- BUGS.md      — topilgan xatolar va holati
- RESEARCH.md  — raqobatchilar va dokumentatsiya tahlili
- QUESTIONS.md — menga savollar va ruxsat kerak bo'lgan ishlar

B) Loyiha ildizidagi `CLAUDE.md` ga (bo'lmasa yarat, bo'lsa oxiriga qo'sh) quyidagi qoidani yoz,
   shunda har yangi sessiyada avtomatik o'qiladi:
   "Har sessiya boshida docs/ai/ dagi barcha fayllarni o'qi va PROGRESS.md dagi KEYINGI QADAM
    dan davom et. Har qadamdan keyin PLAN.md va PROGRESS.md ni yangila. Qoidalar: docs/ai/RULES.md"
   Ushbu promptning to'liq matnini `docs/ai/RULES.md` ga saqla.

C) Loyiha ildizida `ai-loop.sh` skriptini yarat (bajariladigan qil). U:
   - `claude -p` orqali "docs/ai/ ni o'qi va KEYINGI QADAM dan davom et" buyrug'ini beradi;
   - javobda limit haqida xabar bo'lsa 30 daqiqa kutib qayta ishga tushadi;
   - PLAN.md da bajarilmagan vazifa qolmasa yoki PROGRESS.md da "RUXSAT KERAK" paydo bo'lsa to'xtaydi;
   - chiqishni docs/ai/run.log ga yozadi.
   Menga uni tmux ichida qanday ishga tushirishni bir qatorda ayt.

D) Har sessiya boshida: agar docs/ai/ mavjud bo'lsa — o'qi va davom et, qayta boshlama.
E) Har kichik vazifadan keyin darhol PLAN.md va PROGRESS.md ni yangila va git commit qil.
   Ishni `ai/improvements` branchida olib bor. Vazifalarni 15-20 daqiqalik bo'laklarga bo'l.

═══════════════════════════════════════
1. LOYIHANI O'ZING ANIQLA
═══════════════════════════════════════
Hech narsani mendan so'rama — fayllardan aniqla:
- Bu qanday loyiha, kim uchun, qanday muammoni hal qiladi (README, kod, UI matnlari, DB jadvallaridan).
- Stack: tillar, frameworklar, versiyalar (package.json, pubspec.yaml, composer.json,
  requirements.txt, go.mod, Dockerfile va h.k.).
- Arxitektura, modullar, API, autentifikatsiya, ma'lumot oqimi.
- Qanday ishga tushiriladi va qanday deploy qilinadi (Dockerfile, docker-compose, CI fayllari,
  deploy skriptlari, nginx konfiguratsiyalari, .env.example).
- Loyihani lokal ishga tushir, testlar va linter/analyzer'ni ishlat.
- Eskirgan paketlar, zaifliklar, takrorlanuvchi va o'lik kod, performance muammolarini top.
Natijani CONTEXT.md va BUGS.md ga yoz.

═══════════════════════════════════════
2. SERVER VA MA'LUMOTLAR BAZASI
═══════════════════════════════════════
- Serverni o'zing top: `~/.ssh/config` dagi hostlar, CI/deploy fayllari, konfiguratsiyalar.
  Loyihaga mos hostni aniqla va `ssh <host>` bilan ulanishni sina.
- Topa olmasang yoki ulana olmasang — QUESTIONS.md ga yoz va serversiz qismlar bilan davom et.
- Serverda faqat O'QISH rejimida tahlil qil: servislar, resurslar, loglar, SSL, deploy usuli.
- Bazani o'zing aniqla (konfiguratsiya/env nomlaridan): sxema, aloqalar, indekslar,
  sekin so'rovlar, hajm, backup bor-yo'qligi. Faqat SELECT va sxemani o'qish.
- Shaxsiy ma'lumot va maxfiy qiymatlarni hech qayerga yozma.
Natijani CONTEXT.md ga yoz.

═══════════════════════════════════════
3. TADQIQOT
═══════════════════════════════════════
- Loyiha sohasini aniqlagach, shu sohadagi mashhur platformalarni o'zing top (mahalliy va xalqaro)
  va web orqali o'rgan: funksiyalari, UX yechimlari, bizda nima yetishmaydi.
- Loyihadagi har bir asosiy texnologiyaning rasmiy dokumentatsiyasini o'qi:
  arxitektura, xavfsizlik, performance, deploy bo'yicha tavsiyalar; joriy versiyaga mosligi.
- RESEARCH.md ga manbalar bilan yoz va funksiyalarni "Majburiy / Muhim / Kelajakda" ga ajrat.

═══════════════════════════════════════
4. HUJJATLAR VA REJA
═══════════════════════════════════════
- `docs/` ga yoz: ARCHITECTURE.md, API.md, DATABASE.md, DEPLOYMENT.md; README ni yangila.
- PLAN.md ni ustuvorlik bo'yicha tuz: 1) kritik xatolar va xavfsizlik, 2) testlar,
  3) refaktoring, 4) yangi funksiyalar, 5) deploy.
- Menga 5-10 banddan iborat qisqa hisobot ber va to'xtamasdan davom et.

═══════════════════════════════════════
5. XATOLAR VA TESTLAR
═══════════════════════════════════════
- Xatolarni kritiklik tartibida tuzat: avval xatoni ko'rsatadigan test, keyin tuzatish,
  keyin barcha testlar va linter o'tishini tekshir.
- Biznes-logika uchun unit, API uchun integration, asosiy oqimlar uchun e2e/widget testlar yoz.

═══════════════════════════════════════
6. YANGI FUNKSIYALAR
═══════════════════════════════════════
- RESEARCH.md dagi "Majburiy" va "Muhim" funksiyalarni birma-bir qil:
  qisqa dizayn (DECISIONS.md) → kod → test → hujjat → commit.
- Mavjud kod uslubiga moslash. Yangi kutubxonadan oldin zarurligi, faolligi va litsenziyasini tekshir.
- DB o'zgarishlari faqat rollback imkoni bor migratsiyalar orqali.

═══════════════════════════════════════
7. DEPLOY
═══════════════════════════════════════
- Mavjud deploy usulini aniqla va unga amal qil.
- Oldin: testlar o'tgan, DB backup olingan, rollback rejasi DEPLOYMENT.md da.
- Keyin: loglar, servislar, asosiy endpointlarni tekshir va PROGRESS.md ga yoz.

═══════════════════════════════════════
RUXSAT KERAK BO'LADIGAN HOLATLAR
═══════════════════════════════════════
Quyidagilardan oldin to'xta, QUESTIONS.md va PROGRESS.md ga "RUXSAT KERAK: ..." deb yoz
va menga qisqa izoh bilan so'ra. Kutayotganda boshqa xavfsiz vazifalar bilan davom et:
- production bazasida yozish/o'chirish yoki migratsiya ishga tushirish
- production'ga deploy
- serverdagi fayl, servis yoki konfiguratsiyani o'zgartirish
- git tarixini qayta yozish (force push, main'ni rebase qilish)
- pullik yoki yangi tashqi xizmat ulash
Qolgan hamma narsani o'zing hal qil.

═══════════════════════════════════════
XAVFSIZLIK
═══════════════════════════════════════
- Parol, kalit, token va .env qiymatlarini commit qilma, hujjatga yozma, chatga chiqarma.
- .gitignore ni tekshir va to'ldir.

Hozir boshla: docs/ai/ ni tekshir. Mavjud bo'lsa — davom et. Bo'lmasa — 0-bo'limdagi
fayllarni, CLAUDE.md va ai-loop.sh ni yarat va 1-bo'limdan boshla.
