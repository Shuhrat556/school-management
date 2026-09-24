# PLAN

Belgilar: `[ ]` kutilmoqda · `[~]` jarayonda · `[x]` tugadi · `[!]` ruxsat kutmoqda.
Har vazifa ~15-20 daqiqalik bo'lak. Ustuvorlik: 1) kritik xato/xavfsizlik → 2) testlar → 3) refaktoring → 4) yangi funksiyalar → 5) deploy.

## 0. Xotira tizimi
- [x] docs/ai/ fayllari, CLAUDE.md, ai-loop.sh, root .gitignore, `ai/improvements` branch

## 1. Loyihani aniqlash
- [x] Kodni o'qish: backend (gateway, auth, school), admin-web, Flutter → CONTEXT.md
- [x] Build + test + lint: dotnet build, npm run lint/build, flutter analyze/test → BUGS.md
- [x] Eskirgan paketlar va zaifliklar: dotnet list package --outdated/--vulnerable, npm audit, flutter pub outdated
- [ ] Docker bilan lokal ishga tushirish va smoke test (Docker Desktop ishlashi kerak)

## 2. Server va DB (faqat o'qish)
- [x] ~/.ssh/config va docs/server_key.md dagi hostni aniqlash, read-only ulanish
- [x] Serverda: servislar, resurslar, loglar, SSL, deploy usuli → CONTEXT.md
- [x] DB: sxema, indekslar, hajm, backup (faqat SELECT) → CONTEXT.md (DATABASE.md 4-bo'limda)

## 3. Tadqiqot
- [ ] Raqobatchilar (xalqaro + mahalliy) → RESEARCH.md
- [ ] Rasmiy hujjatlar: ASP.NET Core 10, EF Core 10, YARP, Next.js 16, Flutter → RESEARCH.md

## 4. Hujjatlar
- [ ] docs/ARCHITECTURE.md
- [ ] docs/API.md
- [ ] docs/DATABASE.md
- [ ] docs/DEPLOYMENT.md
- [ ] README yangilash
- [ ] Egasiga 5-10 bandli qisqa hisobot
