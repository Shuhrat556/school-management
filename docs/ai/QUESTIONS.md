# QUESTIONS — egasiga savollar va ruxsatlar

Format: `Qn` — savol · holat (OCHIQ / JAVOB BERILDI). Ruxsat so'rovlari `RUXSAT KERAK:` bilan boshlanadi.

## Q1 — `main` dagi commit qilinmagan o'zgarishlar (OCHIQ)
`main` ishchi daraxtida 9 ta fayl o'zgartirilgan, lekin commit qilinmagan (admin-web: curriculum, dashboard,
grades, students/new, lib/api.js; backend: RoomsController route `api/school/rooms`, StudentCreateDto.IsActive,
StudentService, DataSeeder). Ular izchil tuzatishlarga o'xshaydi, lekin kimniki ekani noma'lum.
Men ularni commit qilmayapman va ularga tegmayapman; ular `ai/improvements` ga o'tganda ham ishchi daraxtda qoladi.
**Savol:** bularni o'zingiz commit qilasizmi, yoki men ularni ko'rib chiqib, alohida commit sifatida qo'shaymi?

## Q2 — Production deploy va backup (OCHIQ)
RUXSAT KERAK: `ai/improvements` dagi tuzatishlar tayyor bo'lgach serverda (a) `pg_dump` bilan school_db va auth_db
zaxirasini olish, (b) kodni yangilab `docker compose up -d --build` qilish, (c) school_db ni EF migratsiyalarga
o'tkazish (baseline — mavjud jadvallarga tegmaydi, faqat `__EFMigrationsHistory` yaratadi). Hozircha hech narsa qilinmagan;
tayyor bo'lganda aniq buyruqlar ro'yxati bilan qayta so'rayman.

## Q3 — TLS va domen (OCHIQ)
RUXSAT KERAK: school-management hozir HTTP portlarda (3100/3200/5001) ochiq (BUGS B14). Taklif: subdomen
(masalan `school.<domeningiz>`) + serverdagi mavjud nginx/certbot orqali HTTPS, portlarni 127.0.0.1 ga yopish.
**Savol:** qaysi domen/subdomen ishlatilsin? DNS yozuvini siz qo'shasizmi? (Server konfiguratsiyasini o'zgartirish — ruxsat bilan.)

## Q4 — Maxfiy qiymatlarni almashtirish (OCHIQ, egasi bajaradi)
`backend/.env` bir vaqtlar git tarixiga tushgan (BUGS B5). Tavsiya: serverdagi `JWT_SECRET` va Gmail App Password'ni
yangilash (Google hisobida eski App Password'ni bekor qilish). Git tarixini tozalash (force push) — faqat sizning qaroringiz bilan.
