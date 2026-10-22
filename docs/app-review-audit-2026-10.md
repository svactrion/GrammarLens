# App Review uyum taraması — Ekim 2026 guideline güncellemesi

**Tarih:** 20 Ekim 2026
**Kapsam:** `main` (GrammarLens `1.3.0+6`, App Store incelemesinde, ilk public sürüm) + `proxy/` (Cloudflare Worker).
**Yöntem:** Kod okuma ve arama. Kod değiştirilmedi. Release binary'si incelenmedi (repoda build yok); binary'ye ilişkin iddialar kaynak koddan çıkarım ve "emin değilim" notuyla işaretli.
**Kaynak:** https://developer.apple.com/app-store/review/guidelines/ (2.5.19, 5.1.2(i), 2.3.14 ve 2.5.2'nin metni 20 Ekim 2026'da sayfadan okunarak doğrulandı).

---

## Status updates (English; the audit below is kept as written)

- **#3 App Privacy (owner, 2026-10-23):** updated in App Store Connect:
  the Analytics purpose added to Purchase History and to Device ID; User
  ID not declared (RevenueCat's documentation says it is not needed for an
  anonymous ID). **Open:** Coarse Location (owner's decision).
- **#5 iPad window: closed (owner, 2026-10-23), clean.** Checked on the
  iPadOS 27 simulator (iPad Pro 13-inch, `main`, dev config): full screen,
  iPhone width, the narrowest window, wide and short, live resizing;
  onboarding, Daily Test (hint, multi-blank, keyboard), the result screen,
  the paywall, Home, Review → AI permission → practice, Profile, and the
  narrowest window at the Large text size. Not checked on a real iPad.
- **#10 `strings` check: moved** to the 1.4.0 release build
  (`1.4.0-plan.md`, Phase 5); build 6's archive is no longer on the
  owner's machine. Not done.
- **Action 4, Notes for Review (owner, 2026-10-23):** updated in App Store
  Connect: how a weak spot is created, the AI permission covering every
  practice session, the AI running through our server, no hidden
  features, Premium's 5 sessions a day.

---

## 1. Özet

**Genel risk: Orta (alt sınırda).** Hesap kapatma riski taşıyan bir bulgu yok. 2.5.19 açısından proje temiz: tüm geliştirici araçları (entitlement override, fiyat fixture'ı, debug paneli, tema önizleme, onboarding sıfırlama) `kDebugMode` / `kReleaseMode` derleme sabitlerine bağlı. Bu yüzden release build'de derleyici bu kodu siler; runtime'da açılabilen bir yol, gizli jest, remote config, promo/kod girişi, beyaz liste ya da obfuscation yok. AI tarafında 5.1.2(i)'nin istediği izin akışı var: ilk gönderimden önce açık onay alınıyor, onay kalıcı, sürümlü, geri alınabilir ve fail-closed. API anahtarı client'ta değil. Riski "Orta"ya çıkaran üç şey var. (1) İzin ekranı, onboarding metni ve gizlilik politikası AI'ya gidenleri "Topic Practice" olarak anlatıyor. Oysa ücretsiz kullanıcının AI'ya veri gönderdiği tek yol weak-spot practice ("Practice this") ve bu Topic Practice değil. Onay alınıyor ama yanlış özelliğin adıyla alınıyor. (2) Uygulama içinde gizlilik politikasına sabit bir giriş yok: link sadece paywall'da ve AI izin ekranında. (3) App Privacy beyanının learning goal ve weak-spot practice açısından güncel olduğu repoda doğrulanamıyor; roadmap'te iki madde hâlâ açık.

---

## 2. Bulgular tablosu

| # | Önem | Guideline | Dosya:satır | Bulgu | Önerilen çözüm |
|---|---|---|---|---|---|
| 1 | Orta | 5.1.2(i), 5.1.1(i) | `lib/screens/ai_consent_screen.dart:41`, `:61`; `lib/screens/onboarding_screen.dart:34-36`; gizlilik politikası (site) | İzin ekranının başlığı "Topic Practice", metni "Topic Practice uses an AI service…". Onboarding'deki "Your data & AI" sayfası "If you use Topic Practice, your answers are sent to Anthropic" diyor. Canlı politika da AI'ya yalnızca Topic Practice verisinin gittiğini söylüyor. Ancak `ensureAiConsent` tüm practice oturumlarında (`launchPracticeSet`: Topic Practice ve weak-spot "Practice this") çalışıyor. Ücretsiz kullanıcı Topic Practice'e hiç giremiyor (Premium), AI'ya veri gönderdiği tek yol weak-spot practice. Reviewer ücretsiz hesapla "Practice this"e bastığında "Topic Practice" başlıklı bir izin ekranı görüyor. Onay **alınıyor**, yani izinsiz paylaşım yok; ama "clearly disclose" şartı açısından metin yanlış özelliği anıyor. Profile → Data ise doğru ifadeyi ("practice sessions") kullanıyor. Roadmap'teki açık madde: `docs/roadmap.md:412`. | Politika metnini **hemen** güncelleyin: "Topic Practice and weak-spot practice (Practice this)" veya "any practice session". Uygulamadaki iki metni sonraki build'de düzeltin: başlık "Practice feedback" ya da "AI feedback", metin "Practice sessions (Topic Practice and practicing a weak spot) use an AI service…". Gönderilen veri değişmediği için `AiConsent.currentVersion` artırılmak zorunda değil. Wording'in kapsamı genişlediği için artırmak daha temkinli bir seçim (karar sizin). |
| 2 | Orta | 5.1.1(i) | `lib/screens/settings_screen.dart:601-621` | Gizlilik politikası linki sadece `premium_screen.dart:943` (paywall footer) ve `ai_consent_screen.dart:96` içinde. Profile/Settings'in "App information" bölümünde yalnızca "Data" ve "Credits" var; Data ekranında da link yok. Kural, politikanın uygulama içinde "easily accessible" olmasını istiyor. Premium kullanıcısının paywall'ı görmesi için bir sebebi yok, AI iznini vermiş kullanıcı da izin ekranını bir daha görmüyor. Bu iki grup politikaya uygulama içinden ulaşamıyor. | "App information" kartına "Privacy Policy" satırı ekleyin, hatta "Terms of Use" ile birlikte (`LegalLink` / `openLegalLink` hazır). Bir sonraki build. Reddedilirse en hızlı çözüm bu. |
| 3 | Orta (emin değilim) | 5.1.1, 5.1.2 | `docs/roadmap.md:412`, `:415` | App Privacy beyanı repoda yok, bu yüzden SDK'larla tutarlılığı doğrulanamadı. Roadmap'te iki madde açık: (a) politikanın "practice sessions" ifadesiyle uyumu, (b) learning goal Firebase'e gönderildiği için App Privacy cevaplarının gözden geçirilmesi. Politikanın kendisi learning goal'ü zaten anıyor (16 Ekim 2026 güncellemesi). | App Store Connect → App Privacy'yi Bölüm 3'teki "beklenen beyan" listesiyle karşılaştırın. Bu kod değişikliği gerektirmez; inceleme sürerken yapılabilir. App Privacy beyanı sürümden bağımsızdır, hemen güncellenebilir. |
| 4 | Orta (emin değilim) | 3.1.2(c), 2.3 | App Store Connect metadata (repoda yok) | 1.0.0, 6 Ekim 2026'da 3.1.2(c) nedeniyle reddedildi (metadata'da EULA/Terms linki yoktu). Düzeltme yalnızca o sürümün açıklamasına eklendi (`docs/roadmap.md:9`). 1.3.0 sürümünün açıklamasında bu satırların bulunduğu repoda kayıtlı değil. | 1.3.0'ın açıklamasında Terms of Use (EULA) ve Privacy linklerinin olduğunu ASC'de kontrol edin. Uygulama içi paywall'da Terms ve Privacy linkleri var (`premium_screen.dart:941-944`). |
| 5 | Orta (emin değilim) | 2.1, 4 (Design) | `ios/Runner/Info.plist:58`; `docs/roadmap.md:382` | `UIRequiresFullScreen` iPadOS 26'da artık uygulamayı tam ekranda tutmuyor; uygulama yeniden boyutlandırılabilir pencere olarak açılıyor. Dar pencerede ve yatay pencerede davranış hiç test edilmedi. Reviewer'lar iPad'de test edebiliyor ve iPad screenshot'ları da gönderildi. | Kod değişikliği gerektirmeyen ilk adım: iPadOS 26 simülatöründe pencereyi daraltıp her ana ekranı kontrol edin. Sorun çıkarsa sonraki build'de ele alın. |
| 6 | Düşük | 5.1.2(i) | `lib/screens/practice_screen.dart:135-141` | İzin, oturum başlarken (`practice_launch.dart:118`) kontrol ediliyor. Cevaplar ise oturum sonunda `scoreAnswers` ile gönderiliyor ve bu noktada izin yeniden okunmuyor. Teorik durum: kullanıcı oturum açıkken izni geri alırsa cevaplar yine de gönderilir. Practice ekranı tam ekran açıldığı için pratikte zor bir senaryo. | `_submit` içinde gönderimden önce `getAiConsent()?.allowsSending` kontrolü (defense in depth). Sonraki build. |
| 7 | Düşük | 2.1 | `lib/screens/practice_launch.dart:185`; `lib/screens/practice_screen.dart:158` | Hata snackbar'ları `'$errorPrefix: $e'` biçiminde. `ClaudeApiException.toString()` ise `"ClaudeApiException: …"` döndürüyor. Ağ ya da kota hatasında reviewer ekranda Dart sınıf adını görür. Ayrıca `notConfigured` mesajı (`claude_service.dart:207-210`) "config/dev.json… README.md" diyor. Preflight bu durumu engelliyor, ama yanlış yapılandırılmış bir build'de reviewer'a geliştirici talimatı gösterilir. | Mesajda `e.message` kullanın. Sonraki build. |
| 8 | Düşük | 2.1 | `proxy/wrangler.jsonc:24` | `GLOBAL_DAILY_LIMIT` 300. Bu sınır aşılırsa tüm kullanıcılar "GrammarLens has reached its overall limit for today" mesajını görür. İnceleme sırasında olursa reviewer AI özelliğini çalışmıyor sanabilir. Lansman trafiğinde olası değil. | İnceleme süresince Workers Logs'ta `anthropic_usage` sayısını izleyin; gerekirse dashboard'dan geçici olarak artırın (deploy gerekmez). |
| 9 | Düşük | 5.1.1 | Gizlilik politikası (site) | Politika IP adresinden söz etmiyor. Cloudflare (proxy) ve Firebase IP'yi görüyor; Firebase "approximate region" çıkarıyor. | Politikaya bir cümle: "Our server's host (Cloudflare) and Firebase receive your IP address as part of any network request; we do not store it." İstendiğinde hemen yapılabilir. |
| 10 | Düşük (emin değilim) | 2.5.19 | `lib/services/subscription_service.dart:314-425` | `buildDebugFixtureOffering()` public ve doğrudan bir `kDebugMode` kapısı yok. Yalnızca kapılı `setDebugFixtureOffering` ve testler çağırıyor, bu yüzden tree-shaking ile silinmesi beklenir. Kalsa bile erişilemez ölü koddur, açılabilir bir özellik değildir. | Release IPA'da doğrulayın: `strings Payload/Runner.app/Frameworks/App.framework/App \| grep -E "Entitlement override\|debug preview fixture\|Preview pricing\|Reset first-launch"` boş dönmeli. |
| 11 | Bilgi | 2.5.19 | `lib/screens/settings_screen.dart:779`; `lib/widgets/monthly_climb/climb_debug_controls.dart:33`; `lib/utils/debug_sample_collection.dart:41` | Debug paneli ve Climb debug araçları `!kReleaseMode` ile kapılı. Yani **profile** build'lerde de görünürler. App Store/TestFlight build'leri `flutter build ipa --release` ile alındığı için sorun yok. | Dağıtıma giden her build'in `--release` olduğunu koruyun (`docs/development.md` zaten böyle). |
| 12 | Bilgi | 2.5.19 | `lib/utils/debug_tools.dart:14` | `DebugTools.enabledForTesting` runtime bir değişken, ama her kullanımda `kDebugMode && …` / `!kReleaseMode && …` ile birlikte okunuyor. Release'de sabit `false`'a katlanıyor. Bunu tek başına okuyan bir kullanım yok. | Gerekmiyor. Yeni bir debug aracı eklenirken aynı kalıbı koruyun. |
| 13 | Bilgi | 2.5.19, 2.5.2 | `proxy/wrangler.jsonc:29` | `SHARED_DAILY_TEST_ENABLED` sunucu taraflı tek "flag". Kapatılırsa uygulama paylaşılan set yerine paket içindeki fallback havuzunu (7 set) gösteriyor. Özellik aynı kalıyor, sadece içerik kaynağı değişiyor; yeni ekran ya da yeni akış açmıyor. 2.5.19/2.5.2 riski yok. | Gerekmiyor. |
| 14 | Bilgi | 2.5.19 | `proxy/src/index.ts:54-66`, `:82`; `proxy/src/legacy_daily_test.ts` | `/v1/generate-daily-test` yalnızca 1.0.0 için tutulmuş eski route. 1.0.0 hiç yayınlanmayacak ve 1.3.0 client'ı bu yolu çağırmıyor (bir test bunu `lib/` için doğruluyor). Binary'de değil, App Review'u ilgilendirmez; ama app token'ı bilen biri hâlâ Anthropic maliyeti oluşturabilir. | 1.0.0 kesin olarak geri çekildiyse sonraki proxy deploy'unda kaldırılabilir. |
| 15 | Bilgi | 2.5.19 | Build ayarları | `--obfuscate` / `--split-debug-info` kullanılmıyor (`docs/development.md`, `docs/roadmap.md`, scriptler). Crashlytics için yalnızca dSYM yükleniyor (`firebase.json`: `uploadDebugSymbols`). Gizleme amaçlı bir kullanım yok. | Gerekmiyor. |
| 16 | Bilgi | 1.6 | `lib/config/app_config.dart:14-17`; `proxy/wrangler.jsonc` | Anthropic API anahtarı client'ta **yok**; Worker secret olarak duruyor. Binary'de iki değer var: `APP_TOKEN` ve RevenueCat public SDK anahtarı. RevenueCat anahtarı public olmak üzere tasarlanmış. `APP_TOKEN` çıkarılabilir; kötüye kullanıma karşı asıl koruma cihaz başına 15 / global 300 günlük kota. | Gerekmiyor. Kritik bulgu yok. |
| 17 | Bilgi (emin değilim) | 5.1.2 | `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` | `GoogleAppMeasurement 11.15.0` bağımlılıkla birlikte `google-ads-on-device-conversion-ios-sdk`'yı da getiriyor. Uygulama on-device conversion API'lerini çağırmıyor, AdSupport bağlı değil ve ATT istenmiyor. Bu durumda IDFA toplanmaz. Politikanın "does not use IDFA" ifadesi kodla tutarlı. | Gerekmiyor. Firebase ileride reklam/conversion özellikleriyle yapılandırılırsa ATT ve App Privacy yeniden değerlendirilmeli. |
| 18 | Bilgi (emin değilim) | 5.1.1 | `ios/Runner/` | Uygulama düzeyinde `PrivacyInfo.xcprivacy` yok. Uygulamanın kendi native kodu required-reason API kullanmıyor; Flutter ve eklentiler (Firebase, RevenueCat, sqflite, url_launcher) kendi manifestlerini getiriyor. Build 6 yüklenirken bir ITMS-91053 uyarısı gelip gelmediği repoda kayıtlı değil. | Upload e-postasında uyarı yoksa işlem gerekmez. |
| 19 | Bilgi | 5.1.1(ix) | `lib/services/subscription_service.dart:26-29`, `:57`, `:61`; `lib/utils/app_links.dart:3-6` | Eski yorumlar: "no real App Store Connect product… yet", "(not yet created)", "pages currently carry placeholder content". Kullanıcıya görünmüyorlar, ama gelecekteki bir denetimi yanıltabilirler. | Bir temizlik commit'inde güncellenebilir. |
| 20 | Bilgi | 2.1(a) | `lib/` geneli | Kullanıcıya görünen "coming soon", TODO ya da placeholder metin yok. Tek "coming soon" izi bir yorumda (`app_messenger.dart:19`, kaldırılmış Streak/Voice mesajını anlatıyor). Redeem/promo kodu bilinçli olarak yok (`premium_screen.dart:43`). | Gerekmiyor. |
| 21 | Bilgi | 2.3.7, 2.3.14 | `screenshots/1.3.0/README.md` | Screenshot başlıklarında fiyat, indirim, başka uygulamaya referans ya da doğrulanamayan iddia yok; paywall store karelerinde yer almıyor. "Every answer explained." iddiası doğru: Daily Test 2026-09-24'ten beri her soruya açıklama veriyor. Yine de bilinen bir kusur var: doğru cevapların bir kısmı yanlış sayılıyor (README, "Known flaw"). iPad karelerinde sistemin pencere tutamacı boyanarak gizlenmiş; bu sistem arayüzüdür, uygulama işlevini değiştirmez. Store açıklama metni repoda yok, bu yüzden incelenemedi. | Açıklama metnini ASC'de "unlimited", "#1", "guaranteed" ve fiyat ifadeleri için gözden geçirin. Premium uygulamada da "unlimited" demiyor (`premium_copy.dart:3-5`). |

---

## 3. AI veri akışı tablosu

Client hiçbir zaman doğrudan Anthropic'e bağlanmıyor. Tüm çağrılar `https://api.ahmettayfur.com` (Cloudflare Worker) üzerinden geçiyor. Proxy'nin Anthropic'e çağrısı: `proxy/src/anthropic.ts:736` (`https://api.anthropic.com/v1/messages`).

| # | Client çağrısı | Proxy → Anthropic | Model | Client'ın gönderdiği | Anthropic'e giden | Kişisel veri? | İzin kontrolü | Saklama |
|---|---|---|---|---|---|---|---|---|
| 1 | `lib/services/claude_service.dart:105-119` `generatePracticeSet` ← `lib/screens/practice_launch.dart:150` | `anthropic.ts:343` `buildGeneratePracticeSetBody` | `claude-sonnet-4-6` (`anthropic.ts:24`) | `deviceId` (rastgele 16 bayt, `storage_service.dart:772`), `topicId`, `count` | Yalnızca konu başlığı/açıklaması ve soru sayısı (`anthropic.ts:375-381`). `deviceId` **gitmiyor**. | Anthropic'e: hayır. Proxy'ye: anonim cihaz kimliği. | Evet, `ensureAiConsent` (`practice_launch.dart:118`) çağrıdan önce. | Proxy: `deviceId` yalnızca kota anahtarında (`d:{gün}:{deviceId}`, 48 saat TTL, `quota.ts:3`, `:36`). Loglar yalnızca sayı ve isim içeriyor (`usage_log.ts:57-73`). |
| 2 | `claude_service.dart:165-190` `scoreAnswers` ← `lib/screens/practice_screen.dart:137` | `anthropic.ts:616` `buildScoreAnswersBody` | `claude-sonnet-4-6` | `deviceId` ve her soru için `id`, `type`, `prompt` (soru metni), `userAnswer` (**kullanıcının yazdığı metin**) | `id`, `type`, `prompt`, `userAnswer` (`anthropic.ts:641-653`). `deviceId` **gitmiyor**. | **Evet:** kullanıcının serbest metni (içine kişisel bilgi yazabilir; izin ekranı bunu yapmamasını istiyor). | Dolaylı: aynı oturumun başında alınan izin (bkz. bulgu #6). | Proxy metni saklamıyor ve loglamıyor (`usage_log.ts`, `error_log.ts` privacy contract). Anthropic tarafındaki saklama Anthropic'in koşullarına tabi; politika bunu linkle anlatıyor. |
| 3 | `claude_service.dart:137-163` `fetchSharedDailyTest` ← `daily_test_service.dart` | Anthropic'e gitmiyor; KV okuması (`shared_read.ts`) | — | Yalnızca tarih ve app token. `deviceId` yok. | — | Hayır | Gerekmiyor | — |
| 4 | Yok (sunucu cron'u, `index.ts:131`) | `buildGenerateSharedDailyTestBody` (`anthropic.ts:487`), `buildCheckSharedDailyTestBody` (`:589`) | Üretici `claude-sonnet-5-5` (effort low, `shared_daily_test.ts:82`), denetleyici `claude-sonnet-5` (`shared_check.ts:29`) | — | Yalnızca sunucu tarafında üretilmiş sorular | Hayır, kullanıcı verisi yok | Gerekmiyor | Setler `DAILY_SETS_KV`'de |
| 5 | Yok (yalnızca 1.0.0 için eski route) | `buildGenerateDailyTestBody` (`anthropic.ts:468`) | `claude-sonnet-4-6` | 1.3.0 çağırmıyor | Yalnızca soru sayısı | Hayır | — | — |

**Diğer üçüncü taraflar (AI değil):**

| SDK | Ne topluyor (kod + politika) | Kullanıcıya bağlı mı | İzleme |
|---|---|---|---|
| Firebase Analytics (`lib/services/analytics_service.dart`) | App instance ID, olaylar (ekranlar, oturum sayıları, paywall adımları, `ai_consent_result`), user property `learning_goal`, `text_size`, `first_step_dom`; otomatik: cihaz modeli, OS, sürüm, yaklaşık bölge. İsim, cevap ya da `deviceId` göndermiyor. | Hayır (hesap yok) | Hayır; IDFA yok, ATT gerekmiyor |
| Firebase Crashlytics (`lib/main.dart:95-101`) | Crash/hata kayıtları, cihaz ve uygulama bilgisi | Hayır | Hayır |
| RevenueCat (`lib/services/subscription_service.dart`) | Anonim app user ID, satın alma/abonelik durumu, cihaz/OS | Hayır | Hayır |
| Cloudflare (proxy host) | IP, istek meta verisi (Workers Logs, yaklaşık 3 gün) | Hayır | Hayır |

**İzin akışı değerlendirmesi (Kontrol 2.2):**

- **Önceden açık onay:** Var. `ensureAiConsent` (`ai_consent_screen.dart:216`), oturum oluşmadan ve herhangi bir AI çağrısından önce, tam ekran bir izin ekranı açıyor. Ekran alıcıyı ("Anthropic, the company that makes Claude"), gönderilen veriyi ("The answers you type, together with the question…") ve gönderilmeyenleri açıkça yazıyor; Privacy Policy linki de var. Onay butonu "Agree and continue".
- **Reddedilirse:** "Not now" ya da geri tuşu red sayılıyor ve red kaydediliyor. Oturum başlamıyor, kota harcanmıyor, Daily Test etkilenmiyor. Bir sonraki practice denemesinde ekran yeniden gösteriliyor.
- **Geri alma:** Profile → Data → "AI feedback" anahtarı (`data_screen.dart:76-117`). Kapatmak hemen etki ediyor; açmak izin ekranını yeniden gösteriyor.
- **Kalıcılık ve kontrol:** `ai_consent` tablosunda tek satır olarak saklanıyor; sürümlü (`AiConsent.currentVersion`, `models/ai_consent.dart:11`). "Reset progress" bu kaydı silmiyor. Okuma hatasında fail-closed: izin yok sayılıp yeniden soruluyor.
- **Eksik:** Metin özelliğin adını yanlış veriyor (bulgu #1). Cevaplar gönderilirken izin yeniden kontrol edilmiyor (bulgu #6).

**Gizlilik politikası (Kontrol 2.3), canlı sayfa, "Last updated 16 October 2026":** Anthropic'i adıyla anıyor; gönderilen veriyi (soru ve kullanıcının cevabı) ve sunucunun metni saklamadığını yazıyor; Anthropic'in saklama koşullarını linkliyor. Anonim cihaz kimliğini, 48 saatlik sayaçları, yaklaşık 3 günlük Cloudflare loglarını, Firebase/Crashlytics/RevenueCat'in topladıklarını, learning goal'ü ve "IDFA yok, takip yok" bilgisini anlatıyor. Eksikler: AI kapsamını yalnızca "Topic Practice" olarak tanımlıyor (bulgu #1); IP adresinden söz etmiyor (bulgu #9).

**Info.plist purpose string'leri:** Gerekmiyor. Uygulama kamera, mikrofon, fotoğraf, konum, kişiler ya da takip izni kullanmıyor; Info.plist'te `NS…UsageDescription` yok ve olması da gerekmiyor. `ITSAppUsesNonExemptEncryption = false` mevcut.

**App Privacy için beklenen beyan (ASC'deki ile karşılaştırılacak, emin değilim):**

- *User Content → Other User Content:* practice cevapları (Anthropic). Amaç: App Functionality. Kullanıcıya bağlı değil. Takip: hayır.
- *Identifiers → Device ID:* proxy kotası için anonim `deviceId` ve Firebase app instance ID. App Functionality ve Analytics. Bağlı değil.
- *Identifiers → User ID:* RevenueCat'in anonim app user ID'si. App Functionality. Bağlı değil.
- *Purchases → Purchase History:* RevenueCat. App Functionality.
- *Usage Data → Product Interaction:* Firebase Analytics. Analytics.
- *Diagnostics → Crash Data, Performance Data, Other Diagnostic Data:* Crashlytics/Firebase. App Functionality ve Analytics.
- *Other Data:* learning goal (anket benzeri cevap). Analytics. Bağlı değil. Roadmap'te açık madde: `docs/roadmap.md:415`.
- *Coarse Location:* Firebase IP'den bölge çıkarıyor. Google'ın kendi App Store rehberi bunu ayrı bir kalem olarak listeleyebiliyor; Firebase'in güncel "Data disclosure" sayfasıyla karşılaştırın.

---

## 4. Feature flag listesi

Uygulamada Firebase Remote Config ya da kendi config endpoint'i **yok**. Sunucudan değer alarak sonradan açılabilen bir ekran ya da akış da yok. Aşağıdakilerin hepsi derleme zamanı sabiti ya da yalnızca debug'da çalışan araç; listede tek sunucu değişkeni var.

| Flag | Ne kontrol ediyor | Şu anki değer (release / App Store) | Reviewer görebilir mi |
|---|---|---|---|
| `kDebugMode && DebugTools.enabledForTesting` (`settings_screen.dart:623`, `app.dart:105`, `daily_test_screen.dart:297`, `subscription_service.dart:265`, `storage_service.dart:1373/1387/1537`) | Settings "Developer" bölümü: entitlement override (Real/Free/Full), paywall fiyat önizlemesi, onboarding sıfırlama, tema önizleme; Daily Test'te ham hata metni | `false` (derleme sabiti, kod siliniyor) | Hayır, release'de yok |
| `!kReleaseMode && DebugTools.enabledForTesting` (`settings_screen.dart:779`, `climb_debug_controls.dart:33`, `climb_debug_milestone.dart:77/81`, `climb_debug_theme.dart:39`, `climb_debug_day.dart:38`, `debug_sample_collection.dart:41`, `storage_service.dart:1490`) | "Debug" paneli (gün/tema/milestone/month card tekrarı, örnek madalya koleksiyonu, multi-blank örnek setleri, tüm yerel veriyi silme) | `false` | Hayır (yalnızca debug ve profile build'lerde) |
| `ClimbDebugMonthCard.value` (`climb_debug_month_card.dart:54`, `!kReleaseMode`) | Month card / zoom tekrarı | `null` | Hayır |
| `--dart-define` `CLIMB_DEBUG_DAY`, `CLIMB_DEBUG_THEME`, `CLIMB_DEBUG_MILESTONE`, `CLIMB_DEBUG_MONTH_CARD(_EVENTS)` | Climb sahnesini test etmek | Release'de tanımsız; tanımlansa bile `!kReleaseMode` yüzünden yok sayılır | Hayır |
| `--dart-define` `CLIMB_PREVIEW_DARK`, `MEDAL_PREVIEW_DARK` (`lib/preview/*.dart`) | Ayrı giriş noktalı önizlemeler (`flutter run -t`), `!kDebugMode` ise `StateError` atıyor | Uygulamanın `main.dart`'ı bunları import etmiyor | Hayır |
| `--dart-define` `ANALYTICS_DEBUG_EVENTS` (`analytics_service.dart:48`) | Debug build'de analytics toplama | Release'de analytics her zaman açık (`kReleaseMode`) | İlgisiz |
| `--dart-define` `PROXY_BASE_URL`, `APP_TOKEN`, `REVENUECAT_API_KEY` (`app_config.dart`) | Bağlantı yapılandırması, özellik değil | `config/prod.json`'dan | İlgisiz |
| Sunucu: `SHARED_DAILY_TEST_ENABLED` (`proxy/wrangler.jsonc:29`) | Paylaşılan Daily Test üretimi (kapalıysa fallback havuzu kullanılır) | `"true"` | Evet, Daily Test her durumda görünür; yeni bir özellik açmıyor |
| Sunucu: `DEVICE_DAILY_LIMIT` / `GLOBAL_DAILY_LIMIT` (`wrangler.jsonc:23-24`) | AI çağrı kotası | 15 / 300 | Limit aşılırsa reviewer bir mesaj görür (bulgu #8) |
| `StorageService.freeDailyPracticeLimit` / `dailySessionLimit` (`storage_service.dart:62`, `:49`) | Ücretsiz 1 practice/gün; herkes için en fazla 5 oturum/gün | 1 / 5 | Evet, paywall'da ve mesajlarda açıkça yazıyor |

**Gizli jest kontrolü:** Uzun basma (`onLongPress*`) tek bir yerde var: `topic_hint_card.dart:328-330`, topic hint'i gösteriyor ve UI'da görünen bir özellik. Shake, çoklu dokunma ya da logoya tıklama sayacı yok. `GestureDetector`'ların hepsi klavye kapatma ya da avatar seçimi gibi görünür işler yapıyor.

**Router:** İsimli route yok (`routes:` / `onGenerateRoute` kullanılmıyor). Ekranlara yalnızca `MaterialPageRoute` push'larıyla gidiliyor. UI'dan erişilemeyen ekranlar, `DebugPanelScreen` ve `ThemePreviewScreen`, yalnızca kapılı bloklardan açılıyor.

---

## 5. Önerilen aksiyonlar (öncelik sırasıyla)

| # | Aksiyon | Ne zaman | Not |
|---|---|---|---|
| 1 | Gizlilik politikasında AI kapsamını "Topic Practice"tan "practice sessions (Topic Practice and weak-spot practice)" ifadesine çevirin (bulgu #1). İsterseniz IP cümlesini de ekleyin (bulgu #9). | **İnceleme sürerken** (site, build gerekmez) | Roadmap `:412` maddesini kapatır. |
| 2 | ASC → App Privacy'yi Bölüm 3'teki listeyle karşılaştırın; learning goal ve practice cevaplarının beyan edildiğini doğrulayın (bulgu #3). | **İnceleme sürerken** | Roadmap `:415` maddesini kapatır. |
| 3 | ASC'de 1.3.0 açıklamasında Terms of Use (EULA) ve Privacy linklerinin olduğunu doğrulayın (bulgu #4). | **İnceleme sürerken** | 1.0.0 bu yüzden reddedilmişti. |
| 4 | Notes for Review'ı Bölüm 6'daki taslakla güncelleyin. | Sürüm "Waiting for Review" durumundaysa hemen. "In Review" ise bir sonraki gönderimde ya da Resolution Center yanıtında (emin değilim: ASC "In Review" durumunda sürüm bilgisini düzenlemeye izin vermeyebilir). | Reviewer'ın ücretsiz AI yolunu ("Practice this") bulmasını sağlar. |
| 5 | iPadOS 26'da yeniden boyutlandırılabilir pencereyi simülatörde kontrol edin (bulgu #5). | İnceleme sürerken (yalnızca test) | Sorun çıkarsa sonraki build. |
| 6 | İnceleme süresince proxy kotasını izleyin (bulgu #8). | İnceleme sürerken | Gerekirse dashboard'dan geçici artış. |
| 7 | Release IPA'da `strings` ile debug metinlerinin olmadığını doğrulayın (bulgu #10). | İnceleme sürerken (yalnızca doğrulama) | Bulunursa bile risk düşük; sonuç rapora eklenir. |
| 8 | İzin ekranı ve onboarding metnini "practice sessions" olarak düzeltin (bulgu #1). | **Sonraki build**; 1.3.0 bu yüzden reddedilirse aynı build'de | Kod değişikliği; testlerde metin kontrolleri olabilir. |
| 9 | Profile → App information'a Privacy Policy (ve Terms of Use) satırı ekleyin (bulgu #2). | **Sonraki build**; reddedilirse aynı build'de | |
| 10 | `scoreAnswers` öncesi izin kontrolü (bulgu #6), snackbar'da `e.message` (bulgu #7). | Sonraki build | |
| 11 | Eski yorumları temizleyin (bulgu #19); eski proxy route'unu kaldırmayı değerlendirin (bulgu #14). | Sonraki build / sonraki proxy deploy'u | |

---

## 6. Notes for Review taslağı (İngilizce, App Store Connect'e yapıştırmak için)

> Prices, trial lengths and limits below match build 6 as tested in the sandbox. Check the trial lengths against App Store Connect before pasting.

```
GrammarLens is an English grammar coach for people who learned English by speaking it. There are no accounts and no sign-in: everything is stored on the device. No demo account is needed.

HOW TO TEST THE MAIN FEATURES
1. Launch: Welcome → two-step onboarding (pick an avatar and type any name, then pick a learning goal or tap "Skip goal & start").
2. Daily Test (free): 5 grammar questions per day, the same set for everyone on a given date. Answers are graded on the device and each answer comes with a one-sentence explanation. Daily Test answers are never sent off the device. If the day's set cannot be loaded, the app shows a set bundled in the app.
   Question screen: the topic is shown on each question; slide the "hint" slider (or long-press it) to see the topic's grammar pattern; questions with several blanks have one box per blank; "Skip" moves on.
3. Monthly Climb (free): each completed Daily Test moves the avatar one step up this month's mountain on Home. A month's score earns a Bronze, Silver or Gold medal; medals appear in Profile → Medal collection. The first Daily Test also earns a Welcome badge.
4. Review (free): wrong answers are saved as "weak spots" grouped by topic (Review tab). To create one, answer at least one Daily Test question wrongly (for example, leave an answer blank or type a wrong word).
5. AI feedback on a weak spot (free, once per day): Review → open a weak spot → "Practice this". Before anything is sent, a permission screen explains that the typed answers and their questions are sent to Anthropic (Claude) through our server for feedback. Tap "Agree and continue" to proceed or "Not now" to decline (declining has no other effect). The 3-question session is generated, and after "Submit" each answer gets AI feedback. The permission can be withdrawn any time in Profile → Data → "AI feedback".
6. Topic Practice (Premium): Home → Topic Practice → choose one of 5 topics (Gerund vs. Infinitive, Modal Verbs, Modal Past Forms, Tense Selection, Articles) → choose 3, 5 or 10 questions → AI-generated questions with AI feedback on every answer. The same AI permission applies.
7. Other: Profile → appearance (light/dark/system), text size, change avatar, Data (AI permission switch, "Reset progress"), Credits.

IN-APP PURCHASES (auto-renewable subscriptions, one group, entitlement "Premium")
- grammarlens_premium_monthly: monthly, 3-day free trial for eligible users.
- grammarlens_premium_annual: yearly, 7-day free trial for eligible users.
Where to find the paywall: Home → the locked Topic Practice card, or the Premium card on a practice result screen. A free user also sees it once after the first Daily Test (dismiss with "Maybe later"). Prices and trial wording come from the App Store; a trial is only offered when StoreKit reports the user eligible. The paywall shows Restore Purchases, Terms of Use and Privacy Policy. Premium unlocks Topic Practice on all 5 topics and up to 5 practice sessions a day (it is not unlimited).

AI USE AND DATA
- AI provider: Anthropic (Claude), called only from our own server (api.ahmettayfur.com, a Cloudflare Worker). The app never calls Anthropic directly and contains no AI API key.
- What is sent to Anthropic: only in practice sessions (weak-spot practice and Topic Practice), and only after the user agrees on the permission screen: the question text and the user's typed answers. The user's name, avatar, learning goal and Daily Test answers are never sent.
- Our server receives a random anonymous device identifier used only to enforce daily usage limits; it is not forwarded to Anthropic and expires after 48 hours. The server does not store question or answer text.
- Analytics and crash reporting: Firebase Analytics and Crashlytics, no advertising identifier, no tracking, no ads.

LIMITS YOU MAY HIT WHILE TESTING
- 1 Daily Test per day; 1 free practice session per day; at most 5 practice sessions per day per device for everyone. If you need more sessions on the same device, please test the next day or contact us.

There are no hidden, debug or developer features in the release build, no remote configuration, and no promo or redeem codes.

Contact: support@ahmettayfur.com
```

**What's New:** 1.3.0 ilk public sürüm olduğu için What's New alanı yok (sahibin 2026-10-16 kararı). Sonraki sürüm için başlangıç listesi olarak yukarıdaki "HOW TO TEST" maddeleri kullanılabilir.

---

### Kısıtlar ve emin olunmayan noktalar

- Release binary'si incelenmedi. "Kod release'de siliniyor" ifadesi Dart AOT'nin sabit katlama ve tree-shaking davranışına dayanıyor; doğrulama için aksiyon #7.
- App Store Connect'teki açıklama, App Privacy cevapları, mevcut Review Notes ve abonelik ürünlerinin gerçek ayarları repoda yok. Bulgu #3, #4 ve Bölüm 6'daki trial süreleri bu yüzden doğrulanamadı.
- Gizlilik politikası 20 Ekim 2026'da canlı sayfadan okundu; özetleyici bir araç üzerinden okunduğu için kelimesi kelimesine karşılaştırılmadı.
