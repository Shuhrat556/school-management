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

KEYINGI QADAM: PLAN.md 4-bo'lim — docs/ARCHITECTURE.md, API.md, DATABASE.md, DEPLOYMENT.md (disk talab qilmaydi),
so'ng egasiga hisobot; disk bo'shagach 5-bo'lim T0 (test loyihalari).
