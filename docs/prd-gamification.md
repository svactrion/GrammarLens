# PRD — Monthly Climb

> **Status 2026-09-24: historical plan.** Merged into `main` (`a0723c6`). Current state lives in `docs/roadmap.md`.

**Durum (2026-09-18):** Aşama 1 görsel önizleme kullanıcı tarafından incelendi;
Aşama 2 veri bütünlüğü temeli uygulandı. Aşama 3'ün ilk diliminde üretim Home'a
kalıcı aylık ilerleme ve seçili avatar bağlandı; cihazda Home incelemesi bekliyor.
Profile/nav entegrasyonu ile kilitli boş madalya koleksiyonu uygulandı; madalya
puanı, eşikleri ve kalıcı kazanım motoru kural v1 ile uygulanıp cihaz incelemesine
hazırlandı. Onaylı yön, açık ürün kararları ve teknik
öneriler aşağıda ayrıdır. Tarihsel Weekly Climb taslağı bu dosyanın sonunda
aynen korunur; onun eşikleri ve varsayımları aktif şartname değildir.

## M1. Kaynak ve amaç

Amaç, mevcut Daily Test'e günlük dönüşü ve bağlılığı artırmaktır. Bu hâlâ
kullanıcı araştırmasıyla doğrulanmamış bir ürün bahsidir; öğrenme kalitesi
artışı iddia edilmez. Mevcut davranışın kaynağı kod, geliştirme durumunun
kaynağı roadmap/build-log, aylık ürün yönünün kanonik kaydı bu bölümdür.

Kaynaklar: 2026-09-16 `monthly-climb-development-handoff.md` ve
`monthly-climb-approved-direction.html` (ChatGPT proje outputs alanı;
tam konumlar `gamification-handoff.md` içinde). HTML bir tasarım referansıdır,
Flutter uygulaması veya piksel ölçü şartnamesi değildir. 30 gün, 8→9 adım
ve örnek madalyalar demo verisidir; madalya eşiklerini belirlemez.

## M2. Onaylı ürün ve görsel yön

- Daily Test ve dağ aynı deneyimdir: yeni mod, soru seti veya ek LLM çağrısı yok.
- Tamamlanan günlük test bir adım ilerletir. Doğru sayısı patika hareketini
  değiştirmez; doğru/yanlış sonuçları ayrı puan için saklanır. En az bir
  boş olmayan cevap gerekir; tamamen atlanan test tamamlanır ama adım vermez.
- Döngü takvim ayıdır; ayın gün sayısı kadar günlük adım (28–31), ay bazında
  değişen dağ görünümü. Yanlış cevapta geri düşüş veya ceza animasyonu yok.
- Aylık bronz/gümüş/altın madalya puana bağlıdır; formül henüz belirlenmedi.
- Mevcut 12 hayvan avatarından seçili olan piyon olur; şeffaf zemin, hafif
  gölge. Sabit patikada kesintisiz kısa hareket; fiziksel tırmanma animasyonu yok.
- Geniş yamaçlar, sivri zirve ve bayrak. 7/14/21/28. adımlarda geniş dönüşler
  ve sırasıyla kamp ateşi, çadır, dağ evi, seyir terası; uzun durak etiketleri yok.
- Home: büyük GrammarLens başlığı, karşılama/avatar, avatar yanında yalnız
  madalyon simgesi, Daily Test/dağ, gün göstergesi, hata önizlemesi,
  Topic Practice ve uygun kullanıcıya Premium satırı.
- Madalyon Profile koleksiyonunu açar; avatarın picker'a Hero geçişi korunur.
  Navigasyon Home / Review / Profile olur. Review görevi ve Settings'in
  mevcut işlevlerine erişim korunur; debug alanları release'e açılmaz.
- Arayüz İngilizce; turuncu, parlament mavisi ve kırık beyaz kimlik.
  Dark mode'da turuncu geniş yüzey olmaz.
- Dağ vektör geometrisi, tema paleti ve küçük dekoratif katmanlarla kurulur;
  raster sahne seti veya HTML WebView kullanılmaz.

## M3. Teknik sınırlar ve koddan doğrulanan başlangıç

2026-09-17, base `84deb915d6c812088b1c83f1e4031cfc209a3005`:

- Mevcut StatefulWidget/setState ve constructor üzerinden servis aktarımı
  korunur; yeni state-management mimarisi gerekmiyor.
- Daily Test beş soru; `getTodaysSet` günlük cache'i kullanır, değerlendirme
  `checkDailyTestAnswer` ile yereldir. Cevap eşleştirme kuralları değişmez.
- `DailyTestSet.day` var; `markDailyTestCompleted` ise bitiş anındaki yerel
  `_todayKey` ile yazar. Gece yarısı/ay sonu riski çözülmüş değildir.
- Yarım cevaplar ekran belleğindedir. Kalıcı kaldığı yerden devam yoktur;
  eski haftalık taslaktaki soru başına kalıcı kazanım uygulanmış değildir.
- Sonuç ekranı hata yazımı ve tamamlanmayı ayrı çağrılarla başlatır.
  Aylık kazanım için hata profili ikinci kez yazılmayacak.
- StorageService v14 yükseltmesi tabloları silip yeniden kurar. Yeni geçiş
  veri koruyan migration olmalı: profil, avatar, hata geçmişi, tema, cache,
  günlük haklar ve cihaz kimliği korunmalı.
- Günlük kazanım unique olmalı; yeniden açılan sonuç ikinci adım/puan
  yaratmamalı. Mevcut tamamlama ve aylık kayıt transaction veya dayanıklı
  reconciliation ile tutarlı olmalı. Kalıcı kayıt animasyondan bağımsızdır.
- Puan, tema ve madalya kuralları sürümlenmeli; eşik değişimi geçmiş
  madalyaları sessizce yeniden hesaplamamalı.
- Home resume gün yenilemesi açık hatadır. BrandScaffold, FloatingNavShell
  ve ölçülen NavBarClearance kullanılmalı; Home üst alanı yerel uyarlanmalı.
- Firebase initialization ve analytics servisleri mevcut; canlı event
  doğrulaması ayrı iştir. RevenueCat yapılandırılmış olarak kayıtlıdır,
  ürün/offerings ve gerçek satın alma bu incelemede doğrulanmamıştır.
- Free hedefli pratik günlük 1 haktır. Home weak-spot tıklaması free kullanıcıyı
  paywall'a götürür; Review erişimi ve yeni pratik kotası birbirine karıştırılmaz.
- İlk gün onboarding testi aynı kazanım yolunu kullanmalı; onboarding ve
  paywall navigasyonu korunmalı. `proxy/`, `config/`, abonelik koşulları ve
  soru formatları kapsam dışıdır. Yeni hesap/backend/liderlik tablosu yok.

### M3.1 Uygulanan veri temeli — 2026-09-17

Yukarıdaki base incelemesindeki tamamlama/migration/resume sorunları bu branch'te
şu değişikliklerle ele alındı:

- Climb tablosu şema v15'te eklendi; v14 → v15 yalnız `climb_daily_entries`
  ekler. Şema v16 yalnız bağımsız `text_size_settings` tercihini ekler. Daha eski
  şemalarda eksik tablo/sütunlar eklenir; kullanıcı tabloları silinmez.
- `DailyTestCompletion` mevcut yerel eşleştirmeyi bir kez yapar; aynı sonuç
  nesneleri hem ekranı hem hata kaydını besler. Doğru/yanlış/atlanan ayrımı ve
  klavye varyantlarının doğru sayılması değişmez.
- Tamamlanma, hata profili ve günlük kazanım tek SQLite transaction'ındadır.
  DB içinde tamamlanmış gün kontrolü ve günlük primary key tekrarı engeller.
  Yazma başarısız olursa sonuç ekranı açık hata ve yeniden kaydetme düğmesi gösterir.
- Kayıt anahtarı setin özgün günüdür. Üretim çağrısından önce gün yakalanır;
  gece yarısı süren üretim bunu değiştirmez. Aynı gün yeniden cache yazımı
  ilk seti veya tamamlanmış sonucu ezmez.
- Günlük tablo `day`, `completed_at`, `step`, doğru/yanlış/atlanan sayıları ve
  `rule_version=1` tutar. Madalya puan ağırlıkları henüz yoktur.
- Tamamlanmış eski v2 setleri geriye dönük kazanım almaz. Ay toplamları gün
  kayıtlarından okunur; ay başında eski kayıtlar silinmez. Telafi testi yoktur.
- Home resume'da cache ve selamlama yenilenir; ağ çağrısı yapılmaz. Aylık
  ilerleme henüz Home'a bağlanmadı. Yarım cevapların kalıcı devamı eklenmedi.
- Mevcut Settings "reset progress" kapsamı (hata/pratik geçmişi) genişletilmedi;
  yeni aylık kayıtları silmez. Madalya koleksiyonu sıfırlama davranışı bu aşamanın işi değildir.

## M4. Ürün kararları ve kalan kapılar

### Aşama 3 ilk dilim — 2026-09-18

Home mevcut `getClimbProgress` üzerinden takvim ayını okur; boş, yükleniyor,
hata/yeniden deneme ve zirve durumlarını gösterir. Testten/sonuçtan dönüşte,
kayıt tamamlandığında ve resume'da yerel veriler yenilenir. Kayıt sürerken
sonuç ekranından çıkılması da tamamlanma bildirimiyle güncellenir. Ay anahtarı
dağı yeniden kurar; eşit uzunluktaki aylar arasında geri iniş animasyonu olmaz.
Mevcut storage/migration/transaction implementasyonları değiştirilmedi.
Home'un mevcut Daily Test, Topic Practice, weak-spot/paywall ve avatar Hero
yolları korunur; hata önizleme erişim kararı ve Profile/madalya işi hâlâ açıktır.
Bu dilim tam Home yeniden tasarımının veya Aşama 3 cihaz kabulünün tamamlandığı
anlamına gelmez. Çalışma `monthly-climb-v2` branch'indedir. (Updated 2026-09-19: this is now the
launch branch — it merges to `main` on the owner's explicit approval and ships
as the first App Store release; see `roadmap.md`, "Launch scope".)

2026-09-18 cihaz geri bildirimi paket 1: Sonuç sonunda kayda bağlı
`See your climb` / `Back to Home` butonu uygulanmıştır. Kalıcı yazım bekletilmez;
yalnız piyonun görsel ilerlemesi sonuç rotası kapandıktan ve Home/dağ görünür
olduktan sonra oynar. Tekrar açılan sonuç yeni hareket yaratmaz. İlk günün
mevcut CTA'sı korunur; bu pakette yeni paywall yönlendirmesi yoktur.

Paket 1 kullanıcı tarafından cihazda sorunsuz doğrulandı. Paket 2'de Home'un
dağ alanı dikey kaydırmayı sayfaya bırakır; piyonun otomatik takibi korunur.
Alt açıklama kaldırılmış, aylık sayaç başlık alanına taşınmıştır. Haftalık
katılım şeridi eklenmemiştir; standalone önizleme rotası hâlâ gezilebilir.

| Karar | Açık kapsam | Gerekli aşama |
|---|---|---|
| Madalya — onaylandı/uygulandı | Doğru +2, yanlış +1, atlanan +0; tam ay maksimumunun %25/%50/%75'i; ayrı minimum gün yok | 4 |
| Tamamlanma — onaylandı | En az bir cevap gerekli; tümü atlanırsa tamamlanır ama adım yok | 2 uygulandı |
| Kısmi ay — onaylandı/uygulandı | Telafi ve oranlama yok; tam ay eşiği korunur, kullanıcı ulaşabildiği seviyeyi alır | Madalya: 4 |
| Gün/ay — onaylandı | Saat dilimi değişse/ay geçse de setin özgün günü sabit | 2 uygulandı |
| Geriye dönük kazanım — onaylandı | Eski tamamlanmış v2 testlerine adım verilmez | 2 uygulandı |
| Geometri — karara bağlandı 2026-09-17 | 28 günlük ayda seyir terası son adımda, bayrak aynı bitiş alanında | 1 |
| Temalar — kısmen karara bağlandı 2026-09-17 | İlk önizleme Green Slope light/dark; aylık sıra ve diğer temalar açık, volkan onaylı değil | Sonraki tema aşaması |
| Home hata önizlemesi | Review'a serbest inceleme bağlantısı mevcut paywall yolunu değiştirir mi? | 3 |
| Streak Mode | Monthly Climb eski backlog maddesinin yerine geçer mi? | Roadmap kararı |
| Yayın ve ölçüm — decided 2026-09-19 | Ships with the first release; no baseline, so at least 4 weeks of observation (and a week past the first month-end), thresholds set afterwards. See `docs/analytics-plan.md` §5 | 5 |

İzole worktree/branch seçimi kullanıcı tarafından kesinleştirilmiştir;
merge/yayın tarihi bundan türetilmez. Açık kararlar teknik varsayımla kapatılmaz.

## M5. Aşamalar ve doğrulama

0. İzole worktree/branch, kanonik belgeler, test/analyze ve simülatör başlangıç
   kontrolü. Yeni özellik kodu yok; sonuçlar build-log'a yazılır.
1. Üretim Home'a bağlanmayan Flutter görsel önizlemesi: ortak Path üzerinden
   rota, avatar ve duraklar; 28–31 gün, light/dark, reduced motion.
2. Veri koruyan migration, gün anahtarı, unique kazanım, ay rollover ve resume.
   Bu aşama mevcut tamamlama davranışına dokunur; değişiklik kapsamı görünür
   yazılır, cevap değerlendirmesi ve hata profili çıktısı korunur.
3. Home entegrasyonu: gerçek test/cache/sonuç, tek adım, seçili avatar,
   loading/empty/error/completed durumları, mevcut erişim kuralları.
4. Formül kararından sonra madalya motoru, mevcut ay geçici seviyesi, ay sonu
   kalıcı kazanım, Profile koleksiyonu ve geçmiş ay detayları.
5. Ölçüm ve yayın: event sözleşmesi baştan planlanır, ilgili aşamalarda eklenir;
   canlı doğrulama, cihaz regresyonu ve ayrı yayın kararı burada tamamlanır.

Kabul kontrolleri: migration sonrası v2 verileri; aynı sonucun tekrar açılması;
kill/restart; gece yarısı, ay/yıl ve saat dilimi geçişi; 28–31 gün; yarım/atlanan
cevaplar; ek üretim çağrısı olmaması; free/trial/full erişim; Day-0, Review,
Topic Practice, paywall ve avatar Hero; küçük/büyük ekran, büyük metin,
ekran okuyucu, reduced motion, light/dark, iç/dış kaydırma ve nav clearance.
Analytics hatası kullanıcı akışını durdurmamalı; cevap metni/PII gönderilmemeli.

Ölçüm mevcut Firebase üzerine kurulacak. D1/D7, Daily Test tamamlama,
ay içi katılım ve madalya dağılımı aday ölçütlerdir; event adları, paydalar,
baseline ve başarı eşiği henüz kesin değildir. (Updated 2026-09-19: event names
and parameters are now fixed in `docs/analytics-plan.md` and implemented; there
is no baseline, and thresholds are deliberately set only after the observation
window.) Home redesign ve gamification
birlikte açılırsa etki yalnız gamification'a atfedilemez. Eski haftalık rozet
metrikleri ve analytics sağlayıcı seçimi aktif gereksinim değildir.

Her aşamada küçük kapsam → uygulama → uygun test → light/dark cihaz kontrolü
→ kullanıcı incelemesi → kodla birlikte belge kaydı. Yapılmayan doğrulama
geçmiş gibi yazılmaz; commit/push/merge ayrı bildirilir.

## M6. Decisions (2026-09-19)

Approved during a Claude Code review pass (`docs/gamification-handoff.md`
§10–11, Batch 2). Written in English per that session's own instruction,
even though the rest of this active section is Turkish — later entries in
this section should follow the same convention unless told otherwise.

### M6.1 Scoring deliberately favors habit over accuracy

**Decision:** the approved rule v1 (`docs/gamification-handoff.md` §1:
correct `+2`, wrong `+1`, skipped `+0`) means a user who shows up and
writes *something* non-blank every day — even answers that are never
actually correct — still reaches Silver. Concretely: a full month of
always-wrong-but-answered days scores `1 × 5 questions × daysInMonth`,
exactly 50% of `maxScore` (`daysInMonth × 10`), which meets the Silver
threshold (`ceil(50%)`) on its own. **This is not a bug — it is a
deliberate tradeoff, not an oversight to fix.**

**Rationale:** Monthly Climb's stated purpose (§M1) is daily return and
habit formation, not an accuracy measurement — accuracy is already
measured elsewhere (the error profile and the Review tab), and Daily
Test's own grading is unaffected by this. Rewarding mere participation
over correctness is the same design stance the superseded Weekly Climb
draft argued for explicitly (§3.1 of the historical appendix below:
"the mountain is climbed as much by showing up as by knowing the
answer") — carried forward into the monthly rule rather than re-argued
from scratch. A scoring rule that let inconsistent-but-correct users
out-climb consistent daily users would undermine the one thing this
feature is actually for.

### M6.2 A month's highest tier also unlocks the lower tiers in the collection

**Decision:** a finalized month's highest tier visually unlocks every
tier at or below it in `MonthlyMedalCollection` — a Gold month shows
Bronze, Silver, *and* Gold as earned, not Gold alone. Supersedes the
"deviation" noted in the original handoff (§5 of this doc's own
predecessor, `docs/gamification-handoff.md` §5: "`MonthlyMedalCollection`
marks a tier earned only if a finalized result has exactly that highest
tier — a Gold result does not also visually unlock Bronze and Silver
specimens"). Implemented in Batch 2 (see build-log/handoff for the
commit).

**Rationale:** a tiered scoring ladder (Bronze ⊂ Silver ⊂ Gold by
threshold, `MonthlyMedalRules.tierFor`) is a strict ordering, not three
independent achievements — reaching Gold already means the Bronze and
Silver thresholds were also cleared that month. Showing Bronze/Silver as
still-locked under a tier the user already exceeded reads as a bug or an
insult ("why haven't I earned the easy one?"), not as a reward, and
forces the user to do unnecessary mental math to realize they already
have it. This also matches how tiered achievement collections
conventionally work outside this app.

### M6.3 Mountain theme rotation: undecided, draft only

**Decision:** no mountain theme beyond Green Slope is approved or
implemented. A future rotation (by calendar month, or otherwise) remains
an open, undecided idea — formalizing what §M4's own table already
listed as open ("Temalar — kısmen karara bağlandı … aylık sıra ve diğer
temalar açık, volkan onaylı değil"). This decision changes nothing in
code; it exists so this stays legible as a deliberate deferral, not a
forgotten TODO.

**Rationale:** committing to a specific rotation/sequence before any user
has seen even the first theme on a device risks locking in an untested
visual direction. Green Slope alone is sufficient to unblock every other
Monthly Climb milestone (medal engine, Profile integration, device
acceptance) — the theme rotation is decoupled work that can follow once
there is real feedback to design against.

### M6.4 Medal artwork is a temporary placeholder

**Decision:** the current medal visuals (the tier-colored
`Icons.landscape_rounded` circles in `MonthlyMedalCollection`) are
functional placeholders, not the final design. Final medal illustration
assets are expected to come from an external design source later.

**Rationale:** the placeholder unblocks every non-visual milestone (the
scoring engine, storage, Profile integration, accessibility/text-size
coverage) without waiting on art that doesn't exist yet — the same
posture this project already took with the app icon and avatar
illustrations before their own final assets landed. Swapping the icon
for real artwork later is expected to be a self-contained, low-risk
change to `_MedalSpecimen`/`_MedalHistoryRow`, not a structural one.

### M6.5 Welcome badge — ASSUMPTION, unmeasured; implemented (rule revised)

**Decision:** a "Welcome" badge is part of the direction, on the following
spec — but its value is an **assumption**, not a validated product
decision (see the rationale below). It was implemented in Batch 3
(`docs/gamification-handoff.md` §13); the earning rule was then revised
(§14), and the spec below is the current one. The original wording —
"earned on the first *completed* Daily Test" — and the plan in
handoff §12 are superseded where they differ.

**Spec:**
- Earned exactly once, when a `climb_daily_entries` row with `step = 1`
  is first written — i.e. the user's first Daily Test with at least one
  non-blank answer, the same condition that moves the avatar one step
  (§M2). Merely opening the app, or completing a test with every
  question skipped, is not enough. An all-skipped test still completes
  and still writes its ledger row, but it neither earns the badge nor
  uses it up: the first later test with an answer earns it.
- Independent of and does not replace the monthly medals; a user can
  hold both a Welcome badge and any number of monthly medals
  simultaneously.
- A one-time win moment is shown on the result screen of the test that
  earned it. A backfilled badge (below) gets no win moment.
- Visible in the Profile medal collection, as its own item above the
  Bronze/Silver/Gold row (not a fourth tier); locked and "Not earned"
  until earned.
- The award rule is versioned, the same convention `MonthlyMedalRules`
  already uses (`ruleVersion`), so the earning criteria can change later
  without silently reinterpreting a badge already on record.
- Backfilled once, inside the v18 schema migration only, to existing
  users who already have at least one ledger row with `step = 1`; the
  badge is dated to the earliest such row and marked `backfilled`.
  All-skipped (`step = 0`) rows are ignored. There is no other backfill
  path.

**Rationale for the `step = 1` rule (approved 2026-09-19, replacing "first
ledger row of any kind"):** the badge should reward a real action.
Under the first version, a user who opened the Daily Test and skipped
every question — no engagement with the content at all — was greeted
with "Welcome to the climb" and a permanent badge, while the avatar
correctly did not move. That mismatch made the badge easy to earn
without doing anything and contradicted the product's own definition of
progress (§M2: at least one non-blank answer is required for a step; a
fully skipped test completes but earns no step). Keying the badge to
`step = 1` makes the two agree by construction — the badge is earned
exactly when the user first makes the climb move — so there is one
definition of "took part" across the avatar, the monthly score and the
badge, rather than two that can disagree.

**Rationale (why this is a hypothesis, not a confirmed decision):** there
is no analytics instrumentation live yet (`docs/gamification-handoff.md`
§8; `prd-gamification.md` §M5's own "Ölçüm" section states the same
precondition for Monthly Climb itself) — this cannot be measured before
it ships, only after. The hypothesis being tested: a badge earned on day
one turns a mid-month starter's first partial month from "an
unreachable goal" (no monthly medal is realistically reachable starting,
say, the 20th of a 30-day month — see M2/M4's "no proration" decision)
into "I already earned something," supporting early retention for
exactly the population the no-proration monthly-medal design otherwise
leaves with nothing to show for their first days. This must be verified
against real D1/D7 data once analytics exists, the same "Faz 1 sayıyı
kıpırdatmıyorsa" evidentiary standard §M5/§9 already applies to Monthly
Climb itself — not assumed true because it sounds plausible.

---

# Tarihsel ek — Weekly Climb (superseded)

Aşağıdaki özgün metin gerekçeleri korumak için değiştirilmeden saklanmıştır.
"Bağlayıcı", "şu anda" ve açık karar ifadeleri yazıldığı döneme aittir;
aktif aylık bölümle çelişirse M1–M5 geçerlidir.

# PRD — Weekly Climb (Haftalık Tırmanış)

> **Status note (2026-09-16, added during a docs sync, not part of the
> original PRD body below):** this is the earlier **weekly**-cycle draft.
> Direction has since moved to a **monthly** cycle ("Monthly Climb"); that
> redesign is being done outside this repo and has not been committed here
> yet. Nothing in this PRD has been approved or implemented — no
> gamification code exists anywhere in this codebase as of this note. Read
> the body below as historical/superseded context, not current spec.

**Modül:** Daily Test üzerine oyunlaştırma katmanı
**Durum:** Taslak, 2026-09-10
**Kapsam:** Faz 1 bağlayıcı; Faz 2 taslak, karar verilmedi
**İlgili dokümanlar:** `prd-v2.md` §3 (kanıt durumu), §5 (guest-first), §7.1–7.4,
§8, §12.2, §13.5, §13.7; `roadmap.md` "D — Gamified Daily Challenge"

Bu doküman, 2026-09-10 tarihli "Mountain of Language" taslağının
değerlendirilmesi sonucunda yeniden kurgulanmış halidir. Orijinal taslağın
reddedilen parçaları ve gerekçeleri §11'de kayıtlıdır — silinmemiştir, çünkü
aynı öneriler ileride tekrar gündeme gelirse gerekçenin kaybolmaması gerekir.

---

## 1. Ne yapıyoruz

Daily Test'in üzerine, haftalık sıfırlanan kapalı bir dağ tırmanışı katmanı.
Kullanıcı zaten günde bir kez 5 soruluk testi çözüyor; bu katman o çözümü
kalıcı bir ilerleme çizgisine bağlıyor. Doğru cevaplar daha çok, yanlış
cevaplar daha az yükseklik kazandırıyor; ceza yok. Hafta pazartesi sıfırlanıyor,
kazanılan rozetler ise hiç sıfırlanmıyor.

**Amaç:** D1/D7 retention. Öğrenme kalitesini artırmak bu özelliğin işi değil —
o işi Topic Practice ve hata profili yapıyor.

### 1.1 Neden yeni bir mod değil, katman

Taslağın tarif ettiği oyun döngüsü (günde 1 oturum, 5 soru, ücretsiz) zaten
Daily Test'in birebir tanımı. Ayrı bir mod olarak kurulsaydı her ücretsiz
kullanıcı günde ikinci bir üretim çağrısı tetikleyecekti; §13.7'ye göre günlük
açan ücretsiz bir kullanıcının maliyeti ~$0.63/ay ve geri dönüşü sıfır — bu
rakam ikiye katlanırdı. Katman olarak **marjinal LLM maliyeti sıfırdır.**

### 1.2 Kanıt durumu

**Bu özelliğin tamamı bir bahistir.** Hiçbir kullanıcı istemedi, hiçbir
araştırma turunda çıkmadı. `prd-v2.md` §3'ün "deliberate bets — zero user
evidence" listesine aittir ve orada yazılı gerilim burada da geçerlidir:
doğrulanmış değer sakin, acelesiz, hata odaklı öğrenmedir; oyunlaştırma
doğası gereği baskı üretir. Bu PRD'deki ceza-yokluğu, +5 tabanı ve sakin
görsel dil kararlarının hepsi bu gerilimi yönetmek içindir.

Bahsin doğrulanma yeri Faz 1'in ölçümüdür (§9), lansman öncesi bir tartışma
değil.

---

## 2. Faz ayrımı

| | Faz 1 | Faz 2 |
|---|---|---|
| Ne | Tırmanış, kamplar, rozetler, 4 dağ rotasyonu | Hesap, liderlik tablosu, ödül |
| Veri | Yalnızca cihazda (sqflite) | Supabase |
| Backend | Yok | Var |
| Hesap | Yok (guest-first korunur) | Zorunlu |
| Anti-cheat | Gerekmez (ödül yok, hile teşviki yok) | Zorunlu |
| Ne zaman | Lansmandan sonra | **Yalnızca Faz 1 D1/D7'yi gerçekten oynatırsa** |

Faz 2 bu dokümanda bağlayıcı değildir; taslağı §12'dedir. Faz 1 sayıyı
kıpırdatmıyorsa Faz 2 de kıpırdatmaz ve hiç yazılmamış bir backend'den
tasarruf edilmiş olur.

Faz 1'in tamamen lokal olması `prd-v2.md` §5'in guest-first kararını ve §8'in
"liderlik tabloları kapsam dışı" maddesini bozmadan ilerlememizi sağlıyor.
Ayrıca §5, "kullanıcıda anlamlı bir geçmiş biriktiği an" hesap eklemenin doğal
tetikleyicisidir diyor — kalıcı rozet koleksiyonu tam olarak o geçmiştir. Yani
Faz 1, Faz 2'nin gerekçesini kendi üretiyor.

---

## 3. Puanlama

| Olay | Değer |
|---|---|
| Doğru cevap | **+10 m** |
| Yanlış cevap | **+5 m** |
| Ceza / düşüş | **Yok** |

Günlük aralık: **25–50 m** (gün = 25 + 5 × o günün doğru sayısı).

Yedi gün de oynayan bir kullanıcı için:

> **Haftalık toplam = 175 + 5 × (35 sorudan doğru sayısı)**

Taban 175, tavan 350.

### 3.1 Neden yanlış cevap da puan veriyor

175, 350'nin tam yarısı. Yani **dağın yarısı gelmekle, yarısı bilmekle
tırmanılıyor.** Bu bilinçli bir konumlandırma: özelliğin işi günlük dönüşü
artırmak, doğruluğu ölçmek değil. Doğruluğu zaten hata profili ve Review
sekmesi ölçüyor.

Pratik sonucu: her gün gelip soruların %60'ını bilen (≈250 m), dört gün gelip
kusursuz oynayanın (200 m) önünde bitirir. Sistemin ödüllendirdiği davranış
tam olarak istediğimiz davranıştır.

Ayrıca tüm değerler 5'in katı olduğu için kamp eşiklerine tam oturma yaşanır —
"1 metre kalmıştı" gibi rastlantısal hayal kırıklıkları oluşmaz.

### 3.2 Neden ceza yok

`prd-v2.md` §3'te kayıtlı: T3 uygulamayı "çok sınav gibi" buldu ve doğrulanmış
değer sakin, hata odaklı öğrenme. Yanlış cevabı geri düşüşle cezalandırmak bu
konumlandırmanın tam tersidir. Somut zararı da var: kötü geçen bir ilk gün
kullanıcıya "bugün geldim ve geriye gittim" mesajı verir — D1'i artırmak için
yapılan özellik D1'i düşürür.

Ceza kalkınca taslaktaki premium "Güvenlik Kancası" da düşer; zaten yalnızca
ceza var olduğu için vardı ve pay-to-win'di.

---

## 4. Kamp merdiveni ve rozetler

### 4.1 Eşikler

| Yükseklik | İstasyon | Rozet |
|---|---|---|
| 40 m | Trailhead | — |
| 75 m | Camp I | — |
| 125 m | Camp II | — |
| 175 m | Camp III | — |
| 225 m | Camp IV | — |
| **275 m** | **O haftaki dağın kendi noktası** | **Dağ rozeti** |
| 325 m | High Camp | — |
| **350 m** | **Summit** | **Perfect Week** |

Eşikler 50'nin katlarından bilinçli olarak **25 kaydırılmıştır.** Sonucu:
kusursuz oynayan bir kullanıcı her günü bir sonraki kampa tam 25 m kala
bitirir (50→75, 100→125, 150→175, …). Günü "az kala" bitirmek geri dönüş
kancasının kendisidir ve bu merdiven onu yapısal olarak üretir.

Orta seviye oyuncuda da çalışır — günde 3 doğru (40 m/gün): 40 ✓, 80 ✓,
120 (125'e **5 m** kala), 160 ✓, 200, 240 ✓, 280 ✓.

40 m'deki Trailhead sonradan eklendi: onsuz haftanın ilk günü hiçbir işaret
üretmiyordu (bir günün tavanı 50, ilk kamp 75'ti) ve haftanın ilk günü — yeni
kullanıcı için uygulamayla geçirdiği ilk gün — kullanıcı kaybetmeye en açık
gündür.

Not: yedi gün gelen herkes en az 175 yaptığı için 40/75/125 kampları devam eden
bir kullanıcı için **bitiş noktası değil, hafta içi ara işaretlerdir.** Görevleri
2. ve 3. günü çekmektir. Bitiş noktası olarak ancak gün kaçıranlar için
anlamlıdırlar.

### 4.2 Neden dağ rozeti 275'te, zirvede değil

350'ye ulaşmak 35 sorunun 35'ini doğru yapmayı gerektirir. Pazartesi günü tek
bir yanlış, zirveyi o hafta matematiksel olarak kapatır.

| Kullanıcının doğruluk oranı | Kusursuz hafta olasılığı |
|---|---|
| %95 | ~%17 |
| %90 | ~%2,5 |
| %80 | ~%0,04 |

Bu "zor" değil, **kırılgan**: zorluk çabayla aşılır, kırılganlık ilk hatada
biter — üstelik haftanın birinci gününde biter. Haftalık hedef olarak
konsaydı, retention için tasarlanan özellik hedefini pazartesi öğlen
öldürürdü. Dahası §5.3'teki dört-rozet koleksiyonu hiç tetiklenmezdi.

**Karar:** 275 m haftanın gerçek hedefi ve dağ rozetinin kaynağıdır;
350 m nadir bir prestij rozetidir (Perfect Week). Zirve zor kalır, ama
başarısızlık tanımı olmaktan çıkar.

275'in anlamı: 35 sorudan 20 doğru (%57) **ve** en fazla bir gün kaçırmak.
İki gün kaçıran ulaşamaz (tavan 250). 325 alternatifi elenmiştir: 30/35 doğru
**ve** hiç gün kaçırmamak gerekir, bir gün kaçıranın tavanı 300'dür — yani
350'nin kırılganlığının hafiflemiş hali, aynı sorun.

**Geri çekilme kolu:** ilk ayın verisi rozet kazanan oranını çok düşük
gösterirse eşik 225'e (10 doğru, %29 — iki gün kaçırmayı bile affeder)
indirilir. Tek sabit değişikliği.

### 4.3 Rozetler ve kalıcı defter

İki ayrı defter tutulur:

- **Haftalık defter** — tırmanış. Her pazartesi sıfırlanır. Görevi taze ve
  kazanılabilir bir hedef sunmaktır.
- **Kalıcı defter** — rozetler, tamamlanan dağ sayısı, toplam tırmanılan
  metre. Hiç sıfırlanmaz.

Sıfırlamanın bir kayıp değil yeni bir hafta olarak okunmasını sağlayan şey
kalıcı defterdir. Rozet setleri:

- **Dağ rozeti** (275 m) — o haftaki dağın adını taşır, dört çeşittir.
- **Perfect Week** (350 m) — dağdan bağımsız, nadir.
- **Four Peaks** — bir rotasyon döngüsünde dört dağ rozetinin dördünü de
  toplamak. Haftalık hedefin üstünde dört haftalık ikinci bir hedef katmanı
  üretir ve tam olarak yenilik yorgunluğunun en yüksek olduğu 3.–4. haftada
  devreye girer.

Uyarı, kabul edilmiş sonuç: guest-first olduğu için rozetler cihazdadır;
uygulama silinirse giderler. Faz 1'de kabul edilebilir — ve Faz 2'nin
gerekçesidir.

---

## 5. Dağ rotasyonu

### 5.1 Mekanizma

**Dağ = ISO hafta numarası % 4.** Aya bağlanmaz.

Aylar ~4,35 haftadır; haftalar ay sınırlarını aşar ve "ayın 4. haftası"
5 haftalık aylarda tanımsız kalır. ISO hafta numarası aynı hissi (dört haftada
bir dönen dört dağ) sıfır tarih karmaşasıyla verir.

Kullanıcı bazlı bir sayaç yerine ISO hafta seçilmesinin sebebi: **herkes aynı
hafta aynı dağdadır.** Faz 2'nin sosyal anlatısı ve ileride bir içerik takvimi
buna bağlıdır. Bedeli, yeni kullanıcının rotasyonun ortasından başlaması —
dağlar arasında zorluk farkı olmadığı için (§5.3) bu bir dezavantaj değildir.

### 5.2 Dört dağ

| # | Dağ | Değişen |
|---|---|---|
| 0 | Green Slope | Temel palet |
| 1 | Snow Peak | Soğuk palet + zirve kar katmanı |
| 2 | Misty Pass | Gri palet + sis katmanı |
| 3 | Night Sky | Koyu palet + yıldız katmanı |

**Tek siluet, dört tema.** Aynı dağ geometrisi, aynı istasyon yerleşimi, aynı
animasyon; değişen yalnızca palet ve bir-iki katman. Maliyet dört kat değil,
yaklaşık 1,5 kattır. Dört ayrı siluet çizilirse her biri light/dark temada
ayrıca çalışmak zorunda olduğu için iş sekiz varyanta çıkar ve Faz 1'i tek
başına şişirir.

Her dağın 275 m noktası kendi adını taşır (Green Slope → *The Meadow*,
Snow Peak → *The Cornice*, Misty Pass → *The Gate*, Night Sky → *The
Overlook*), böylece dört rozet birbirinden gerçekten ayrışır.

### 5.3 Dördü de eşit zorlukta

Görsel bir diziliş (normal → karlı → taşlı → volkanik) "gittikçe zorlaşıyor"
beklentisi yaratır; mekanik her hafta aynı olduğu için görsel yalan söylemiş
olur. Zirve yüksekliğini haftaya göre değiştirmek ise §9'un ölçümünü kirletir —
3. haftadaki düşüşün sebebinin yenilik yorgunluğu mu yoksa o haftanın yüksek
eşiği mi olduğu ayrılamaz hale gelir.

**Karar: dördü de aynı puanlama, aynı eşikler, aynı zirve. Değişen yalnızca
manzara.**

Volkan/lav dağı bu sebeple ve ton sebebiyle temel dörtlüye alınmadı (§11).

---

## 6. Ekran ve etkileşim

### 6.1 Nerede yaşıyor

Ayrı bir sekme açılmaz. `prd-v2.md` §13.5 Home'u bir menü değil "bugün ekranı"
olarak tanımladı; tırmanış oraya bağlanır:

- **Home / Today bloğu** — mevcut Daily Test durumunun yanında küçük bir
  ilerleme göstergesi: güncel yükseklik, o haftanın dağı, sonraki kampa kalan
  mesafe. Tıklanınca tam dağ ekranı açılır.
- **Tam dağ ekranı** — günün testi tamamlandığında sonuç ekranıyla birlikte
  gösterilir; ayrıca Home'daki göstergeden her zaman açılabilir.

### 6.2 Dağ ekranı

- Tek dağ silueti, üzerinde sekiz istasyon işareti. Geçilen istasyonlarda
  bayrak, geçilmemişler sönük.
- Karakter mevcut yükseklikte durur. Tırmanış animasyonu **gün sonunda tek
  seferde** oynar (o günün toplam kazanımı), soru başına değil — tek ve güçlü
  bir an, beş küçük an yerine.
- Yanlış cevapta düşüş yok, sarsıntı yok, kırmızı yok. Yalnızca daha kısa bir
  ilerleme.
- Kamp geçildiğinde kısa bir vurgulama ve istasyon adı.
- 275 geçildiğinde dağ rozeti verilir ve tırmanış devam eder (325 ve 350 hâlâ
  açıktır).
- Haftanın yedi günü ekranda görünür durumdadır; kaçırılan gün sönük bir
  işaretle gösterilir — cezasız ama görünür.

### 6.3 Dil

Uygulama arayüzü İngilizcedir (`roadmap.md` backlog: Türkçe arayüz seçeneği
henüz yok). Tüm istasyon, dağ ve rozet adları İngilizce yazılır. Bu doküman
Türkçedir; kopya metinler İngilizce üretilecektir.

---

## 7. Veri modeli (Faz 1, yalnızca cihazda)

Mevcut `sqflite` kurulumuna eklenir. Hiçbir şey sunucuya gitmez.

```
climb_week
  week_key           TEXT PK      -- ISO yıl-hafta, örn. "2026-W38"
  mountain_id        INTEGER      -- 0..3, ISO hafta % 4
  height             INTEGER      -- kazanılan toplam metre
  days_played        INTEGER
  questions_correct  INTEGER
  questions_total    INTEGER
  camps_reached      TEXT         -- ulaşılan eşiklerin listesi
  started_at         TEXT
  updated_at         TEXT

climb_badge
  badge_id           TEXT PK      -- "mountain:1", "perfect_week", "four_peaks"
  week_key           TEXT
  mountain_id        INTEGER
  earned_at          TEXT
```

Haftalık kayıtlar silinmez (yılda 52 satır). Toplam metre, tamamlanan dağ
sayısı gibi kalıcı defter değerleri bu tablodan türetilir; ayrı bir sayaç
tutulmaz — iki kaynak arasında tutarsızlık oluşmasın diye.

**`mountain_id` ilk günden yazılmalıdır.** Olmadan, 3. haftadaki bir düşüşün
sebebinin yenilik yorgunluğu mu yoksa "Misty Pass kötü çalışıyor" mu olduğu
asla ayrılamaz ve geriye dönük kurtarılamaz.

Dağ tanımı koda gömülmez, veri olarak tutulur:

```
Mountain { id, name, landmarkName, badgeName, palette, layers, summitHeight }
```

Beşinci bir dağ, mevsimlik veya etkinlik dağı eklemek böylece kod değişikliği
değil veri eklemek olur.

---

## 8. Edge case'ler

1. **Gün tanımı.** Tırmanış, Daily Test'in gün tanımını **birebir** kullanır.
   İki ayrı gün kavramı olmamalıdır. (Daily Test'in mevcut tanımının kodda
   doğrulanması gerekiyor — §10.)
2. **Hafta sınırı.** Hafta pazartesi 00:00 yerel saatte döner. Oturum pazar
   23:58'de başlayıp pazartesi 00:03'te biterse **oturumun başladığı hafta**
   sayılır.
3. **Yarıda kesilen oturum.** Yükseklik soru başına kalıcı yazılır (animasyon
   gün sonunda oynasa da). Kullanıcı 3. soruda çıkarsa kazandığı metre durur;
   aynı gün dönerse Daily Test'in mevcut devam davranışı geçerlidir.
4. **Yükseklik asla azalmaz.** Aynı `week_key` içinde geriye gitme yoktur.
   Cihaz saati değiştirilse bile.
5. **Hile.** Faz 1'de ödül olmadığı için hile teşviki yoktur; anti-cheat
   gerekmez. Faz 2'de zorunlu hale gelir (§12).
6. **Uygulama silinirse** tüm tırmanış ve rozetler gider. Guest-first'ün kabul
   edilmiş sonucu.
7. **Hafta ortasında başlayan yeni kullanıcı.** Cuma başlayan bir kullanıcının
   o haftaki tavanı 150'dir; hiçbir rozet alamaz ve ilk haftası kesin
   başarısızlıkla biter. **Öneri:** kısmi haftalarda rozet eşiği kalan güne
   orantılanır — `275 × (kalan gün / 7)`, 25'e yuvarlanmış (cuma başlayan
   için 125). Tırmanış ve kamplar normal çalışır. *Açık madde — §10.*
8. **Offline.** Faz 1 tamamen lokal olduğu için tırmanış tarafında ağ
   bağımlılığı yoktur. Daily Test'in mevcut offline davranışı değişmez.

---

## 9. Ölçüm

### 9.1 Ön koşul — bu olmadan özellik yapılmamalı

**Şu anda hiçbir analytics yok.** Firebase iskeleti hiçbir projeye bağlı değil
ve hiçbir şey toplamıyor (`prd-v2.md` §7.4, `roadmap.md`). Bu haliyle Faz 1
yapılırsa hiçbir şey ölçülemez, dolayısıyla Faz 2 kararı da verilemez ve
buradaki faz mantığının tamamı çöker.

**Bir event tracking katmanı Faz 1'in ön koşuludur.** §7.4 bunu "Phase 6 /
public launch" zamanına koymuştu; tırmanış onu zorunlu hale getiriyor.

### 9.2 Baseline

> **Superseded 2026-09-19.** This weekly-era appendix assumed the climb ships
> after launch, so a baseline would exist. The plan changed: the climb ships
> with the first release and there is no baseline; see `docs/analytics-plan.md`
> §5. The original text follows unchanged.

Lansmandan sonra, tırmanış devreye girmeden önceki dönemin D1/D7'si. Özellik
lansmanla aynı anda çıkarsa baseline oluşmaz — bu yüzden tırmanış lansmanın
parçası değildir.

### 9.3 Bakılacak sayılar

- D1 / D7 retention — baseline'a karşı
- Haftalık rozet kazanma oranı (275'e ulaşan kullanıcı yüzdesi)
- Hafta içi gün dağılımı — kaç gün oynanıyor, hangi günlerde düşüyor
- **`mountain_id` kırılımı** — dağlar arasında tamamlama farkı var mı
- **3. ve 4. hafta tamamlama oranı** — yenilik yorgunluğunun ölçüldüğü yer;
  Four Peaks rozetinin işe yarayıp yaramadığı buradan okunur
- Daily Test tamamlama oranı — tırmanış onu artırıyor mu, yoksa yalnızca
  görünürlük mü ekliyor

### 9.4 Faz 2'ye geçiş şartı

Faz 1, baseline'a göre D7'yi anlamlı biçimde yükseltmediyse Faz 2 yapılmaz.
Eşik, baseline görüldükten sonra yazılır — şimdi uydurulmaz.

---

## 10. Açık maddeler

1. **Kısmi ilk hafta** — §8.7'deki orantılı eşik önerisi onaylanacak mı, yoksa
   ilk hafta rozetsiz "ısınma haftası" olarak mı bırakılacak?
2. **Daily Test'in mevcut gün ve devam davranışı** kodda doğrulanacak; bu PRD
   ona uyacak, tersi değil.
3. **Trailhead (40 m)** eşiği bu incelemede eklendi, Ahmet tarafından henüz
   onaylanmadı.
4. **Streak Mode'un yerine geçme kararı** — §11.3.
5. **Analytics sağlayıcı seçimi** — §9.1'in ön koşulu; vendor kararı bu
   dokümanın kapsamı dışında.
6. **Zirve üstü davranış** — 350'ye ulaşan kullanıcı haftanın kalanında ne
   görür? (Şu an: tırmanış biter, ekran zirvede kalır. Alternatif yok, ama
   kopya metin yazılmadı.)

---

## 11. Reddedilenler ve gerekçeleri

Orijinal taslaktan çıkarılanlar. Aynı öneriler tekrar gelirse gerekçe
kaybolmasın diye burada duruyorlar.

### 11.1 Çoktan seçmeli / boşluk doldurma soru formatı
İki araştırma turunda 7 kişiden 5'i MC/gap-fill'i reddetti. `prd-v2.md` §3 bunu
"v2'nin yapmaması gereken tek şey" olarak işaretliyor ve projenin araştırmayla
desteklenen dört bulgusundan biri. **Tırmanış mevcut üretim tabanlı soru
tipleriyle çalışır, yeni bir format getirmez.**

### 11.2 Supabase + hesap + haftalık liderlik tablosu (lansman öncesi)
`prd-v2.md` §5 guest-first kararına ve §8'in "liderlik tabloları kapsam dışı"
maddesine aykırı. Supabase kod tabanında hiç yok. §7.4 zaten aynı yığının
(Supabase + RevenueCat + PostHog + …) başka bir AI aracı tarafından önerildiğini
ve reddedildiğini kaydetmiş. Taslak ayrıca RevenueCat'i çalışır varsayıyordu;
gerçekte yalnızca iskelet var, hesap ve ürün yok. → Faz 2.

### 11.3 Streak Mode
Bu özellik, roadmap'teki Streak Mode ile **aynı bahsi** oynuyor: hızlı, düşük
sürtünmeli bir günlük alışkanlık. Streak Mode ise şu maliyetlerle geliyor: ayrı
bir mod, soru başına LLM çağrısı (`prd-v2.md` §7.1'in çözülmemiş maliyet
kararı), ücretsiz kullanıcı için rewarded video reklam SDK'sı ve "yanlışta
biter" mekaniğiyle sınav gerilimi.

**Öneri: tırmanış Streak Mode'un yerine geçsin.** Kabul edilirse roadmap'ten
4. ve 5. maddeler düşer ve §7.1'in maliyet kararı süresiz ertelenebilir.
*Karar verilmedi — §10.4.*

### 11.4 Yanlış cevapta −5 m ceza ve premium "Güvenlik Kancası"
§3.2. Ceza konumlandırmaya aykırı; kanca yalnızca ceza var olduğu için vardı ve
pay-to-win'di.

### 11.5 "Bu hafta hero'yu kurtardın" anlatısı
Tırmanışla yarışan ikinci bir metafor. Dedektif teması bilinçli olarak
temizlenmişti; yeni bir anlatı katmanı aynı borcu geri getirir. Ayrıca dil
öğrenimiyle bağı olmayan bir kahramanlık hikâyesi, App Store metni ve portföy
anlatısındaki "sakin, hata odaklı öğrenme" tonuyla çelişir. Rozetler dağın
dilinde konuşur.

### 11.6 Volkan / lav dağı
Tehdit ve aciliyet çağrıştırır; ceza mekaniğini kaldırarak çıkardığımız tonu
başka kapıdan geri sokar. **Atılmadı, ertelendi** — ileride özel/etkinlik dağı
olarak en güçlü aday, ve o zaman özel olmasının bir anlamı olur.

### 11.7 Aya bağlı rotasyon
§5.1.

### 11.8 Sonsuz tırmanış
Orijinal taslak sınırsız yükseklik öneriyordu. 50 m/gün ile üç ay sonra
4000 m'de, ekranda hâlâ aynı yamaç kayar; sonsuz arka plan bir yerden sonra
ilerleme olarak okunmaz ve sayı anlamını kaybeder. Haftalık kapalı tırmanış
hem bunu çözer hem de tek bir dağ asset'iyle çalışılabilir hale getirir.

### 11.9 Gün sonu AI raporu / paywall — kapsam dışı
Taslak, Daily Test sonucuna premium bir AI açıklaması ve ücretsiz kullanıcı
için bulanıklaştırılmış bir CTA öneriyordu. Fikir savunulabilir ve ayrıca
değerlendirilmelidir, ama **bu PRD'nin kapsamı dışındadır**: tırmanışla aynı
anda devreye girerse §9'un ölçümü iki değişkeni birden taşır ve retention
değişiminin sebebinin oyunlaştırma mı yoksa yeni paywall yüzeyi mi olduğu
ayrılamaz. Ayrı karar, ayrı zamanlama.

---

## 12. Faz 2 taslağı (bağlayıcı değil)

Yalnızca §9.4'ün şartı sağlanırsa açılır. Şimdiden bilinen problemler:

- **Sıralama metriği yükseklik olamaz.** 275'e ulaşan herkes aynı bantta,
  350'ye ulaşan herkes tam olarak aynı skorda biter; tablo baştan aşağı
  beraberlik olur. Alternatifler: kaçıncı günde 275'e ulaşıldığı, üst üste kaç
  hafta dağ rozeti alındığı, doğruluk oranıyla eşitlik bozma.
- **Anti-cheat zorunlu.** Yükseklik cihazda hesaplanıp sunucuya yazılırsa
  herkes istediği skoru yazar. Ödül gerçek para değeri taşıyacaksa (promosyon
  premium) skorun sunucuda doğrulanması, dolayısıyla cevapların sunucuya
  gitmesi gerekir — mimari büyür. Bu maliyet Faz 2 kararına dahil edilmelidir.
- **Ödül ekonomisi.** Haftalık ücretsiz premium dağıtmak, §13.7'ye göre kişi
  başı ~$1,43/ay maliyeti olan bir şeyi geliri olmayan kullanıcılara vermektir.
  Küçük ölçekte kabul edilebilir, ölçeklenmez.
- **Hesap geçişi.** Cihazdaki rozetlerin ve geçmişin hesap açılırken
  kaybolmaması gerekir; taşıma yolu Faz 2'nin ilk tasarım problemidir.
