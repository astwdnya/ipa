# IPA Saver 📦

اپ iOS به سبک **DLiPA**: لینک یا اسم اپ رو از **App Store** میدی، با Apple ID خودت
لاگین می‌شی و **فایل IPA رو تحویل می‌گیری** تا تو حافظه‌ات ذخیره‌اش کنی — بدون نصب، بدون جیلبریک.

هسته دانلود بر پایه [ipatool](https://github.com/majd/ipatool) (MIT) وندور شده — همون رویکردی که DLiPA هم استفاده کرده.

- رابط کاربری: انگلیسی، تم روشن مینیمال
- حداقل نسخه: **iOS 16**
- خروجی: IPA رمزگذاری‌شده با FairPlay (مثل ipatool/DLiPA)

## 🚨 وضعیت فعلی (اکتبر ۲۰۲۶) — تغییر پروتکل اپل

اپل در **اوت ۲۰۲۶** سرورهای لاگین App Store را به‌روزرسانی کرد و حالا درخواست‌های ورود باید با
**SAP** (`X-Apple-ActionSignature`) امضا شوند. در نتیجه **همه‌ی ابزارهای ثالثی که پروتکل قدیمی را
استفاده می‌کنند موقتاً از کار افتادند** — از جمله این اپ، Asspp و نسخه‌های قدیمی ipatool.

- پیام خطا در این اپ: «Apple now requires SAP-signed requests…» (به‌جای ارور مبهم «The data couldn't be read»)
- ✅ **راه‌حلِ فعال همین امروز**: ورک‌فلو **Fetch IPA** در همین ریپو — چون روی سرور گیتهاب
  [ipatool رسمی v2.6+](https://github.com/majd/ipatool) را اجرا می‌کند که SAP را پشتیبانی می‌کند.
  راهنمای پایین را ببینید.
- ✅ راه‌حل دیگر: اجرای `ipatool` نسخه 2.6 به بالا روی یک کامپیوتر (Windows/Mac/Linux) و انتقال IPA به گوشی.
- 🔜 به‌محض اینکه پیاده‌سازی SAP سازگار با iOS (مثل [ApplePackage](https://github.com/Lakr233/ApplePackage)
  یا Asspp جدید) منتشر شود، به این اپ اضافه می‌شود — هر دو متن‌بازند.

## امکانات

- ✅ **تب App Store**: جستجو با اسم، Bundle ID یا لینک اپ‌استور (`apps.apple.com/.../id…`)
- ✅ لاگین با Apple ID (پشتیبانی از **کد 2FA**) — ذخیره امن در Keychain
- ✅ انتخاب Storefront کشور (۱۷۰+ کشور با پرچم)
- ✅ دانلود IPA با نوار پیشرفت + اخذ خودکار لایسنس برای اپ‌های رایگان
- ✅ اعمال `iTunesMetadata.plist` و `SC_Info/*.sinf` (FairPlay) داخل فایل — مثل ipatool
- ✅ **تب Direct Link**: دانلود IPA از لینک مستقیم (توقف/ادامه/سرعت)
- ✅ **تب My Files**: اشتراک‌گذاری به eSign/GBox، ذخیره در Files، حذف — فایل‌ها در
  `Files → On My iPhone → IPA Saver` هم دیده می‌شوند

## ⚠️ نکات مهم (حتماً بخوان)

1. **فایل IPA دانلودشده رمزگذاری‌شده (FairPlay) است** — این دقیقاً رفتار DLiPA/ipatool است:
   - برای نصب با **همان Apple ID** (مثلاً از طریق Apple Configurator روی کامپیوتر) قابل استفاده است،
   - یا اول با **GBox دیکریپتش کن**، بعد با eSign/GBox ساین و نصب کن،
   - روی دستگاه جیل‌بریک‌شده با ابزارهایی مثل `bfdecrypt`/Iridium هم قابل دیکریپت است.
2. **فقط اپ‌های رایگان** قابل دانلودند (اپ پولی باید قبلاً خریداری شده باشد؛ ابزار این اجازه را نمی‌دهد).
3. استفاده از Apple ID شخصی با ابزارهای ثالث مطابق سیاست‌های اپل نیست — **حتماً از یک Apple ID دوم** استفاده کن و ریسک را بپذیر.
4. رمز عبور فقط در **Keychain همین دستگاه** ذخیره می‌شود و جایی ارسال نمی‌شود (جز سرورهای خود اپل برای لاگین).

## ساختار پروژه

```
IPA-Saver/
├── project.yml                      # XcodeGen (4 تارگت: app + 3 کتابخانه)
├── .github/workflows/build-ipa.yml  # کامپایل خودکار IPA خود اپ (بدون مک)
├── .github/workflows/fetch-ipa.yml  # ✅ دانلود IPA هر اپ با ipatool رسمی (SAP-ready)
├── IPASaver/                        # سورس اپ (SwiftUI)
│   ├── App/                         # IPASaverApp + Theme
│   ├── Models/                      # DownloadItem, SavedFile
│   ├── Services/                    # DownloadManager, FileStore, AppStoreService
│   ├── Views/                       # AppStoreView, DownloadView, FilesView, ...
│   ├── Support/Info.plist
│   └── Resources/Assets.xcassets
└── Vendored/                        # هسته ipatool v2.2.0 (MIT)
    ├── Networking/                  # HTTPClient, HTTPDownloadClient, ...
    ├── StoreAPI/                    # StoreClient (auth/purchase/download), SignatureClient, ...
    ├── Persistence/                 # KeychainStore
    └── LICENSE-ipatool.txt
```

---

## روش ۱: گرفتن IPA آماده بدون مک (پیشنهادی) — GitHub Actions

1. یک ریپوی **Public** روی [github.com/new](https://github.com/new) بسازید (مثلاً `IPA-Saver`).
2. تمام محتویات این پوشه (`project.yml`، `IPASaver/`، `Vendored/`، `.github/`) را آپلود کنید
   (در صفحه ریپو: **uploading an existing file**) و **Commit** بزنید.
3. به تب **Actions** بروید — ورک‌فلو **Build unsigned IPA** خودش اجرا می‌شود (۳ تا ۷ دقیقه؛
   دفعه اول پکیج‌های SPM را هم دانلود می‌کند).
4. روی اجرای سبز کلیک کنید و از **Artifacts** فایل `IPASaver-unsigned-ipa` را بگیرید
   → داخلش `IPASaver-unsigned.ipa` است.
5. با eSign یا GBox ساین و نصبش کنید (راهنمای پایین).

> اجرای مجدد: تب Actions → **Run workflow**.

## روش ۲: گرفتن IPA هر اپ دلخواه — ورک‌فلو «Fetch IPA» ✅ فعال است

این ورک‌فلو [ipatool رسمی](https://github.com/majd/ipatool) را روی سرور گیتهاب کامپایل و اجرا می‌کند
(نسخه 2.6+ با پشتیبانی SAP) و IPA اپ موردنظر را به‌عنوان Artifact تحویل می‌دهد:

1. **از نسخه 1.2.1 نیازی به ساخت Secret نیست** — اکانت Apple ID از قبل داخل
   `fetch-ipa.yml` قرار گرفته (برای همین ریپو را **Private** نگه دارید).
   اگر خواستید اکانت را عوض کنید، همان دو خط بالا در فایل را ویرایش کنید یا
   Secretهای `APPLE_ID` / `APPLE_PASSWORD` بسازید که اولویت دارند.
2. به تب **Actions** بروید → ورک‌فلو **Fetch IPA from App Store** → **Run workflow**:
   - `app`: لینک اپ‌استور (مثل `https://apps.apple.com/us/app/x/id123456`) یا عدد ID یا Bundle ID
   - `platform`: معمولاً `iphone`
   - `auth_code`: اگر 2FA فعال است، **درست قبل از اجرا** کد ۶ رقمی را از دستگاه مورد اعتماد بگیرید و وارد کنید
3. بعد از اتمام (۲ تا ۵ دقیقه) روی اجرا کلیک کنید → از **Artifacts** فایل `fetched-ipa` را بگیرید.
4. IPA را به گوشی منتقل کنید → دیکریپت با GBox → ساین و نصب با eSign/GBox.

> اگر Secret نسازید، می‌توانید ایمیل/رمز را در فیلدهای ورودی همان صفحه وارد کنید —
> اما توجه: مقادیر Input در تاریخچه‌ی اجرا قابل مشاهده‌اند. اکانت دوم استفاده کنید.

## روش ۳: کامپایل محلی با Xcode (روی مک)

```bash
brew install xcodegen   # یک‌بار
cd IPA-Saver
xcodegen generate       # ساخت IPASaver.xcodeproj (+ resolve خودکار SPM)
open IPASaver.xcodeproj
```

در Xcode تیم امضای خود را انتخاب و روی دستگاه اجرا کنید؛ یا IPA بدون ساین:

```bash
xcodebuild -project IPASaver.xcodeproj -scheme IPASaver -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

mkdir Payload && cp -R build/Build/Products/Release-iphoneos/IPASaver.app Payload/
zip -r IPASaver-unsigned.ipa Payload
```

---

## ساین و نصب با eSign / GBox

1. `IPASaver-unsigned.ipa` را به گوشی منتقل کنید.
2. در eSign یا GBox: **Import/Add IPA** → فایل را انتخاب کنید.
3. با سرتیفیکیت خودتان **Sign** → **Install** بزنید.
4. اگر iOS اعتماد نکرد: `Settings → General → VPN & Device Management` → Trust کنید.

## استفاده از اپ (خود DLiPA-مانند)

1. تب **App Store** → **Sign in with Apple ID** (ایمیل + رمز؛ اگر 2FA فعال است، بعد از تلاش اول
   فیلد کد ۶ رقمی باز می‌شود).
2. Storefront کشور را متناسب با اکانت انتخاب کنید (مثلاً `US`).
3. اسم اپ یا لینک اپ‌استور را جستجو کنید → روی **Get** بزنید.
4. فایل در تب **My Files** ذخیره می‌شود؛ از آنجا Share/ذخیره در Files/حذف کنید.

## رفع اشکال

| خطا | راه‌حل |
|---|---|
| «Apple now requires SAP-signed requests…» | تغییر سروری اپل (اوت ۲۰۲۶) — از ورک‌فلو **Fetch IPA** یا ipatool 2.6+ روی کامپیوتر استفاده کنید |
| «The data couldn't be read because it isn't in the correct format» | همان مورد بالا در نسخه‌های قدیمی‌تر اپ / Asspp قدیمی |
| «Two-factor authentication is required» | کد ۶ رقمی دستگاه مورد اعتماد را وارد کنید و دوباره Sign in بزنید |
| «storefront does not match» | کشور Storefront را با کشور اکانت اپل‌آیدی خود یکی کنید |
| «Only free apps can be downloaded» | اپ پولی است — دانلود فقط برای اپ‌های رایگان |
| «session expired» | دوباره Sign in کنید |
| خطای شبکه | فیلترشکن/ تغییر شبکه؛ سرورهای اپل گاهی محدودیت منطقه‌ای دارند |

## اعتبارها

- هسته دانلود: [ipatool](https://github.com/majd/ipatool) © Majd Alfhaily — **MIT License** (در `Vendored/LICENSE-ipatool.txt`)
- ایده و رفتار مرجع: [DLiPA](https://github.com/AhmedBafkir/DLiPA)
