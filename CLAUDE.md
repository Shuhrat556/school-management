# CLAUDE.md

Har sessiya boshida docs/ai/ dagi barcha fayllarni o'qi va PROGRESS.md dagi KEYINGI QADAM
dan davom et. Har qadamdan keyin PLAN.md va PROGRESS.md ni yangila. Qoidalar: docs/ai/RULES.md

## Ish konventsiyalari

- Ish faqat `ai/improvements` branchida. `main` ga to'g'ridan-to'g'ri commit qilinmaydi.
- Commit: bitta Conventional-Commit sarlavha (`type(scope): ...`) + ko'pi bilan 1-2 qisqa qator,
  jami ~160 belgi. `Co-Authored-By` yoki boshqa atributsiya qatori QO'SHILMAYDI.
- Faqat o'zing o'zgartirgan fayllarni `git add <yo'l>` bilan qo'sh; `git add -A` / `git add .` ishlatma.
  Ishchi daraxtda egasining commit qilinmagan o'zgarishlari bo'lishi mumkin (docs/ai/QUESTIONS.md, Q1).
- `docs/server_key.md`, `.env`, `docs/ai/run.log` hech qachon commit qilinmaydi (root `.gitignore`).
- PLAN.md belgilari: `[ ]` kutilmoqda, `[~]` jarayonda, `[x]` tugadi, `[!]` ruxsat kutmoqda.
- Ruxsat kerak bo'lsa (RULES.md oxiridagi ro'yxat): QUESTIONS.md ga `RUXSAT KERAK: ...` yoz,
  PLAN.md da vazifani `[!]` qil va boshqa xavfsiz vazifa bilan davom et.
  Faqat davom etadigan xavfsiz vazifa qolmasa, PROGRESS.md ga **qator boshida**
  `RUXSAT KERAK: ...` yoz — bu `ai-loop.sh` ni to'xtatadi. Ruxsat berilgach qatorni
  `RUXSAT BERILDI: ...` ga o'zgartir.
- Server (docs/server_key.md) — faqat o'qish. Production DB ga faqat SELECT.
- Build/test buyruqlari: docs/ai/CONTEXT.md, "Buyruqlar" bo'limi.
