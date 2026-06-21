# راهنمای دستورات ربات فروش V2Ray (نسخه Docker)

> همه‌ی دستورها از داخل پوشه‌ی نصب اجرا می‌شوند مگر خلاف آن گفته شود:
> ```bash
> cd /opt/irsuppbot
> ```
> دو کانتینر داریم: `irsuppbot_app` (خود ربات) و `irsuppbot_db` (دیتابیس PostgreSQL).
> داده‌ها در دو volume می‌مانند: `pgdata` (دیتابیس) و `botlogs` (لاگ‌ها).

---

## ۰) نصب از صفر (روی سرور تازه)

**پیش‌نیاز:** سرور Ubuntu 22.04 یا 24.04، دسترسی root، اتصال اینترنت.

نصب با یک دستور (اسکریپت را دانلود و اجرا می‌کند):
```bash
curl -fsSL https://raw.githubusercontent.com/IRSupp/IRSuppBot/main/install.sh -o install.sh && bash install.sh
```

اسکریپت این اطلاعات را می‌پرسد:
- **Bot token** — توکن ربات از BotFather
- **Admin numeric ID(s)** — آیدی عددی ادمین (چند تا با کاما)
- **License key** — کلید لایسنس
- **Channel ID** — اختیاری (Enter = رد)
- **ZarinPal key** — اختیاری (Enter = رد)
- **Version to install** — Enter بزن = آخرین نسخه (latest)

بقیه خودکار انجام می‌شود: نصب Docker، ساخت `.env` و `docker-compose.yml` و `update.sh`، کشیدن image، و بالا آوردن ربات و دیتابیس.

در پایان پیام `Done! Installation complete` می‌آید. حالا در تلگرام `/start` بزن.

> 💡 اگر Docker تازه نصب شد و وسط کار خطای permission دیدی، یک‌بار از سرور خارج شو و دوباره وصل شو (یا `newgrp docker` بزن)، بعد دوباره `bash install.sh`.

---

## ۱) وضعیت: ربات بالا هست یا نه؟

```bash
cd /opt/irsuppbot && docker compose ps
```
ستون `STATUS` را ببین:
- `Up` یا `running` → سالم بالا است.
- `Up (healthy)` برای دیتابیس → دیتابیس آماده است.
- `Exited` → خاموش است (با دستور استارت بالا بیاور).

دیدن همه‌ی کانتینرها (حتی خاموش‌ها) در کل سیستم:
```bash
docker ps -a
```

---

## ۲) دیدن لاگ‌ها (برای عیب‌یابی)

لاگ زنده‌ی ربات (با `Ctrl+C` خارج شو):
```bash
cd /opt/irsuppbot && docker compose logs -f bot
```

فقط ۵۰ خط آخر:
```bash
cd /opt/irsuppbot && docker compose logs --tail=50 bot
```

لاگ دیتابیس:
```bash
cd /opt/irsuppbot && docker compose logs --tail=50 db
```

---

## ۳) ری‌استارت ربات

فقط ربات (دیتابیس دست‌نخورده):
```bash
cd /opt/irsuppbot && docker compose restart bot
```

ری‌استارت همه (ربات + دیتابیس):
```bash
cd /opt/irsuppbot && docker compose restart
```

---

## ۴) خاموش / روشن کردن

خاموش‌کردن (کانتینرها بسته می‌شوند، داده می‌ماند):
```bash
cd /opt/irsuppbot && docker compose stop
```

روشن‌کردن دوباره:
```bash
cd /opt/irsuppbot && docker compose start
```

روشن‌کردن کامل (اگر کانتینرها حذف شده‌اند، از نو می‌سازد):
```bash
cd /opt/irsuppbot && docker compose up -d
```

---

## ۵) آپدیت ربات به نسخه‌ی جدید

ساده‌ترین راه (اگر `update.sh` هست):
```bash
cd /opt/irsuppbot && bash update.sh
```

نصب یک نسخه‌ی مشخص:
```bash
cd /opt/irsuppbot && bash update.sh v1.0.2
```

دستی (اگر `update.sh` نبود):
```bash
cd /opt/irsuppbot && docker compose pull bot && docker compose up -d
```

> دیتابیس، تنظیمات (`.env`) و قفل لایسنس موقع آپدیت **حفظ می‌شوند**.

---

## ۶) بکاپ گرفتن از دیتابیس (مهم)

### گرفتن بکاپ
یک فایل `.sql` از کل دیتابیس می‌سازد (با تاریخ در نام):
```bash
docker exec irsuppbot_db pg_dump -U postgres irsuppbot > /opt/irsuppbot/backup_$(date +%Y%m%d_%H%M%S).sql
```
فایل در `/opt/irsuppbot/backup_<تاریخ>.sql` ساخته می‌شود. آن را جای امن نگه‌دار.

### بکاپ فشرده (کم‌حجم‌تر)
```bash
docker exec irsuppbot_db pg_dump -U postgres irsuppbot | gzip > /opt/irsuppbot/backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### بازگرداندن بکاپ (Restore)
> ⚠️ این داده‌های فعلی را با بکاپ جایگزین می‌کند. با احتیاط.
```bash
cat /opt/irsuppbot/backup_FILE.sql | docker exec -i irsuppbot_db psql -U postgres irsuppbot
```
(اگر فشرده `.gz` بود:)
```bash
gunzip -c /opt/irsuppbot/backup_FILE.sql.gz | docker exec -i irsuppbot_db psql -U postgres irsuppbot
```

### بکاپ خودکار روزانه (اختیاری)
یک خط به crontab اضافه کن تا هر شب ساعت ۳ بکاپ بگیرد:
```bash
crontab -e
```
سپس این خط را اضافه کن:
```
0 3 * * * docker exec irsuppbot_db pg_dump -U postgres irsuppbot | gzip > /opt/irsuppbot/backup_$(date +\%Y\%m\%d).sql.gz
```

---

## ۷) حذف کامل ربات

### حذف ربات ولی نگه‌داشتن داده‌ها
```bash
cd /opt/irsuppbot && docker compose down
```
کانتینرها حذف می‌شوند ولی volumeها (`pgdata`, `botlogs`) می‌مانند. با `up -d` دوباره با همان داده بالا می‌آید.

### حذف کامل همه‌چیز (داده هم پاک می‌شود) ⚠️
> این دیتابیس و همه‌ی داده‌ها را **برای همیشه** پاک می‌کند. اول بکاپ بگیر!
```bash
cd /opt/irsuppbot && docker compose down -v
```
`-v` یعنی volumeها هم پاک شوند.

### حذف فایل‌های نصب و image
```bash
# حذف کامل کانتینر و داده
cd /opt/irsuppbot && docker compose down -v
# حذف image
docker rmi boroumandhosein/irsuppbot:latest
# حذف پوشه‌ی نصب
rm -rf /opt/irsuppbot
```

---

## ۸) تنظیمات و فایل‌ها

دیدن تنظیمات (`.env`) — شامل توکن و کلیدها:
```bash
cat /opt/irsuppbot/.env
```

ویرایش تنظیمات (مثلاً عوض‌کردن توکن یا ادمین):
```bash
nano /opt/irsuppbot/.env
# بعد از ویرایش، ربات را ری‌استارت کن تا اعمال شود:
cd /opt/irsuppbot && docker compose restart bot
```

---

## ۹) فضای دیسک و پاک‌سازی

دیدن فضای استفاده‌شده‌ی داکر:
```bash
docker system df
```

پاک‌کردن image‌ها و کانتینرهای بلااستفاده (داده‌ی ربات دست‌نخورده):
```bash
docker system prune -f
```

---

## ۱۰) عیب‌یابی سریع

| مشکل | راه‌حل |
|------|--------|
| ربات جواب نمی‌دهد | `docker compose logs --tail=50 bot` را ببین |
| `Conflict: terminated by other getUpdates` | دو نسخه با یک توکن اجرا شده‌اند. مطمئن شو فقط یک کانتینر فعال است (`docker ps`) و نسخه‌ی systemd خاموش است |
| بعد از آپدیت خطای دیتابیس | معمولاً migration. ربات را ری‌استارت کن؛ اگر نشد لاگ را بفرست |
| ربات بالا نمی‌آید | `docker compose ps` و `docker compose logs db` را چک کن (شاید دیتابیس آماده نشده) |
| می‌خواهم از اول شروع کنم | بکاپ بگیر، بعد `docker compose down -v` و دوباره `up -d` |

---

## دستورهای پرکاربرد (خلاصه)

```bash
cd /opt/irsuppbot

docker compose ps                 # وضعیت
docker compose logs -f bot        # لاگ زنده
docker compose restart bot        # ری‌استارت
docker compose stop               # خاموش
docker compose start              # روشن
bash update.sh                    # آپدیت
docker compose down               # حذف (داده می‌ماند)
docker compose down -v            # حذف کامل (داده پاک می‌شود)

# بکاپ دیتابیس
docker exec irsuppbot_db pg_dump -U postgres irsuppbot > backup.sql
```
