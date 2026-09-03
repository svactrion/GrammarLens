# PRD v2 — GrammarLens

**Version:** 2.0 (draft)
**Author:** Ahmet Emin Tayfur
**Date:** August 2026
**Status:** Draft — scope agreed, open decisions listed in §7
**Supersedes:** nothing. `prd.md` (v0.1 MVP) stays as the historical record of
the MVP's problem definition, user research, and scope decisions. This
document covers what comes after it.

---

## 1. Why v2, and what changed

The MVP validated its core hypothesis. Across two research rounds (four
interviews in `prd.md` §2.1, three usability tests in §2.2), the strongest and
most repeated finding was that plain-language, personalized error feedback is
genuinely valued — all three usability testers praised it unprompted, and it
was the one thing nobody criticized in either round.

What the MVP did *not* establish is whether anyone comes back. Retention was
never measured, because the MVP never left the developer machine.

**Decision: skip "make the MVP try-able," go public with v2 instead.**
The MVP roadmap's next item was distributing the current build so people could
try it. That is now dropped. Rationale: seven people have already used or
discussed the core loop in person; another small private round would repeat
what we know. The more valuable test is a public one — and a public launch
needs the things a bare practice loop doesn't have (a reason to return, an
identity, a sense that the product is going somewhere). Those are v2.

This is a deliberate reversal of a documented plan, recorded here rather than
made silently.

---

## 2. What v2 is

A single-player grammar practice tool becomes a product with a reason to open
it daily:

- **Two practice modes** instead of one — the existing topic-based deep
  practice, plus a fast streak mode
- **A user identity** — lightweight onboarding, a name, personalization
- **A commercial frame** — users understand this will be a paid product, and
  that they're getting it free right now
- **Room for social** — a data model that doesn't have to be rebuilt when
  friend comparison and competition arrive

## 3. Evidence status — read this before building anything

This is the most important section of this document for anyone (including
future me) evaluating these decisions.

The MVP's features traced back to user research. **Most of v2's do not.** That
is a legitimate way to build — not every feature can wait for a user to
request it, and users rarely ask for things they haven't seen. But it must be
labeled honestly, because a bet that gets described as a research finding
corrupts every decision made downstream from it.

### Backed by research

| Feature | Evidence |
|---|---|
| Onboarding "why are you learning English" question feeding topic suggestions | T1 hesitated on topic selection and asked for guidance on where to start (§2.2 Theme 3). Single participant — directional, not saturated |
| Keeping plain-language feedback as the core of topic mode | 3/3 usability testers, consistent with §2.1 Theme 2. Strongest finding in the project |
| Some form of positive feedback on answering | T3 found the app "very exam-like" and wanted small acknowledgment (§2.2 Theme 6). Single participant |
| No multiple-choice question format anywhere in v2 | 5 of 7 people across both rounds rejected MC/gap-fill (§2.2 Theme 1, §2.1 Theme 3). This is the one thing v2 must not do |

### Deliberate bets — zero user evidence

Nobody in either research round asked for any of the following. They are
product bets based on category patterns and strategy, to be validated after
launch, not before:

- **Streak mode** — bet: a fast, low-friction mode creates a daily habit that
  deep practice alone doesn't
- **Accounts and social comparison** — bet: competing with friends drives
  return visits in this segment
- **Paywall framing before charging** — bet: signaling future paid status
  increases perceived value and urgency
- **Rewarded video to unlock streak runs** — bet: users accept a 30s ad for a
  free feature and it makes premium legible
- **AI voice practice mode** — bet: speaking practice is the premium-worthy
  feature. Note this reverses `prd.md` §5, which excluded speech as "a
  different problem, heavy integration cost." That reasoning still stands; the
  bet is that it's worth the cost as a paid differentiator

**Known tension to watch:** the validated core value is calm, unhurried,
mistake-focused learning. Streak mode is pressure, speed, and punishment for
error — and T3 already told us the app felt too exam-like. These two products
can coexist, but if streak mode starts shaping the tone of the whole app, v2
has damaged the one thing users actually praised. Post-launch, watch whether
streak users ever come back to topic mode, or whether the modes cannibalize
each other.

---

## 4. Screen architecture

```
First launch
  └─ Welcome / value intro
      └─ Onboarding (name + learning goal)
          └─ Home

Returning launch
  └─ Home

Home (mode selection, personalized greeting)
  ├─ Topic Practice  (existing MVP loop)
  ├─ Streak Mode     (new)
  ├─ Voice Practice  (premium — later phase, locked placeholder in v2)
  ├─ Review tab      (existing)
  ├─ Settings        (new)
  └─ Premium / early-access screen  (new)
```

### Home
Replaces the current topic-list-first home. Personalized greeting using the
onboarding name ("Welcome back, Ahmet"), then mode cards. Existing per-topic
progress stats move into topic mode's own screen rather than the top level.

### Onboarding
Two fields only: **name** and **learning goal** (exam prep / work / general).
Age and occupation are deliberately deferred to Settings or a later prompt.

*Rationale:* every field asked before the user has experienced value costs
completions, and this is an unknown app. Name earns its place by powering
personalization; learning goal earns its place by feeding topic suggestions —
which partially answers T1's "I don't know where to start." Age and occupation
are currently marketing data only, with no in-product use, so they don't
justify their friction yet.

### Settings
Does not exist today. Minimum: theme (light/dark/system), name edit, data
reset (currently only possible by deleting the app), and optional profile
fields (age, occupation) for users who want to fill them in.

### Premium / early-access screen
Shows what premium will include and states clearly that it's free right now.
**No payment flow in v2.** See §6.

---

## 5. Account model — guest-first

**Decision: guest-first, account optional.**

Onboarding does not require signup. The user enters a name, picks a goal, and
starts practicing immediately. Data stays local (existing sqflite error
profile). An account is only required for features that genuinely need a
server: friend comparison, competition, cross-device sync.

*Rationale:* requiring registration before any value is delivered is the
single most expensive thing a new app can do to its funnel, and this app has
no brand recognition to spend. Guest-first also means streak mode, onboarding,
personalization and the paywall screen can all ship without standing up
backend infrastructure — the largest and least reversible cost in v2.

*Consequence to accept:* until an account exists, uninstalling loses the error
profile and streak history. Acceptable during early access; becomes a real
retention problem once users have meaningful history, which is the natural
trigger for adding accounts.

---

## 6. Monetization framing (v2 = signal only, no revenue)

**Paywall screen with no payment flow.** The screen presents premium features
and positions current access as free early-access.

Copy direction — say "free during early access," **not** "free" or "free
forever." An unbounded promise made now becomes a constraint when pricing
actually launches. Framing that gives the user standing without over-promising:
*"You're one of our first users — everything is free while we're in early
access."*

**Rewarded video to start a streak run (free tier).** Free users watch a ~30s
rewarded video before a streak run; premium starts immediately.

*Note on the economics:* banner advertising cannot cover LLM inference costs
at any realistic impression volume for an app this size — rewarded video is
the only format where the math works at all, which is why it's the format
chosen. But at early user counts, ad revenue is not the point; bounding cost
is. The video gate's real function in v2 is making the premium value
proposition legible, not funding inference.

**Explicitly not in v2:** payment processing, subscription management, pricing
decisions, refunds. Those come when there's usage data to price against.

---

## 7. Open decisions

Recorded as open, with options, rather than decided by default.

### 7.1 Streak mode evaluation — how do we know an answer is correct?

Streak mode has to end the streak the moment an answer is wrong, which means
per-answer evaluation. The MVP evaluates in a batch at the end of a session
specifically to avoid this cost (roadmap backlog: "~5x more LLM calls").

| Option | Cost | Trade-off |
|---|---|---|
| Per-answer LLM call, Haiku | Low — a short verify call is a fraction of a cent; a 20-question run is roughly a cent | Fresh, generated questions; Haiku is well-matched to "is this right or wrong," which is far simpler than generating personalized explanations |
| Per-answer LLM call, Sonnet | ~2x Haiku | Only worth it if streak answers need real feedback, which arguably defeats the mode's speed |
| Pre-generated pool + deterministic checking in code | Near zero | Cheapest and instant, but questions repeat and lose the "always fresh" property that differentiates the product |

**Leaning:** Haiku for verification, Sonnet reserved for topic mode's feedback
— the actual differentiator. **Decision deferred to end of v2**, to be made
against measured cost-per-session rather than estimates.

**Prerequisite:** instrument token usage per session so this decision is made
on a real number.

### 7.2 Free-tier usage cap

A daily cap on free sessions would bound inference cost and give the premium
tier a natural shape. Not yet decided — needs the cost measurement from 7.1
first. If adopted, it should be the primary free/premium boundary rather than
inventing an artificial one later.

### 7.3 Streak content selection

"Random questions" was the initial idea. Alternative: draw from the user's own
error profile, which would connect streak mode to the validated
personalization value instead of running parallel to it. Unresolved — random
is simpler, error-profile-driven is more consistent with what users praised.

---

## 7.4 Infrastructure sequencing (rejected-for-now stack proposal)

A separate AI tool was asked to propose a production stack for this project
without visibility into this document — it recommended Supabase, RevenueCat,
PostHog, OneSignal, and Firebase Crashlytics, plus a Clean
Architecture/MVVM restructure and an ASO keyword strategy, all up front. None
of it traces to anything in §3's evidence table; it's generic "freemium app"
best practice, not GrammarLens-specific. Recorded here so the reasoning for
not doing this now isn't lost if the same proposal resurfaces.

| Tool | What it's for | Why not now | Right time |
|---|---|---|---|
| Supabase | Backend, DB, auth | Directly contradicts §5's guest-first decision, made deliberately to avoid standing up backend infra before it's needed | Post-v2, when accounts/social genuinely require a server (see §10 "Later phases") |
| RevenueCat | Subscription/IAP management | §6 explicitly excludes payment processing from v2 | Once a real pricing decision is made, after early-access data exists — likely post-launch |
| PostHog | Product analytics, paywall funnels | No traffic yet to analyze; would be tracking empty channels | Phase 6 (public launch) — this one does map to a real need, §9's success criteria (onboarding completion, D1/D7 retention, mode split) require *some* event tracking, so revisit vendor choice then rather than defaulting to PostHog now |
| OneSignal | Push notifications (streak-break reminders) | Not just premature — in tension with the validated value prop. §3 already flags that streak mode risks pushing the app toward pressure/exam-like feeling (T3's complaint); a "your streak is dying" push is that risk in its most direct form. Building the retention mechanic before the mode it retains users into even exists, and before knowing whether streak mode itself damages the calm/mistake-focused core, is backwards | After streak mode ships and its usage data is visible — and even then, reconsider the framing (not punitive) before defaulting to streak-break alerts |
| Firebase Crashlytics | Crash reporting | Lowest-risk of the five, but no urgency — single-developer testing on a simulator sees crashes directly | Reasonable to add around Phase 6 when usage moves outside the developer's own machine |
| Clean Architecture / MVVM restructure | Folder structure to modularly fit the above | Speculative generality — restructuring around five integrations none of which are being built yet | Introduce structure incrementally as each integration actually lands, not ahead of it |
| ASO / AppTweak keyword strategy | Store listing optimization | No store distribution channel has been decided yet | Right before actual store submission, once a distribution decision is made |

---

## 8. Out of scope for v2

- Payment processing and pricing (see §6)
- Friend comparison, leaderboards, competition modes — depend on accounts and
  a backend; v2's job is to not block them
- AI voice practice — premium placeholder only in v2; built in a later phase
- Multiple language pairs
- Spaced repetition scheduling (still in backlog from MVP)

---

## 9. Success criteria

The MVP's criteria were qualitative because it had no users. V2 launches
publicly, so these are measurable — **at launch**, not once a full analytics
vendor is in place (that's deferred, §7.4):

- **Onboarding completion rate** — what share of first launches reach Home
- **Day-1 / Day-7 return rate** — the retention question the MVP could never
  answer, and the actual reason we're launching before streak mode (§10)
- **Qualitative:** does the plain-language feedback still get praised once
  users arrive without a researcher sitting next to them? — via the feedback
  channel in §10.1
- **Deferred until streak mode ships (post-launch):** mode split, and
  whether streak mode complements or cannibalizes topic-mode use — can't be
  measured before the mode exists

**Measurement approach for launch:** no PostHog/analytics vendor (§7.4 — no
traffic to justify it yet, and vendor choice should follow first real usage,
not precede it). Minimum viable version: lightweight local event logging
(onboarding started/completed, session started/completed, return visits) that
can be reviewed manually. This is a real gap in earlier drafts of this
document — success criteria existed with no plan to measure them before
launch. Exact implementation (local log reviewed how? exported how?) is a
build-time decision, not specified further here.

---

## 10. Sequencing — lean launch

**Decision (2026-08-24): launch before streak mode, not after.** Earlier
drafts of this document sequenced launch after streak mode, rewarded video,
and cost analysis were all done. Revised: streak mode is a zero-evidence bet
(§3), and building it pre-launch delays the exact thing §1 says launching is
for — real retention signal on the one thing that *is* validated (topic mode
+ plain-language feedback). If nobody returns to topic mode, that's the
signal to have before deciding streak mode is the right investment, not
after.

1. **Onboarding + Home + Settings** — no backend, no new LLM cost, unblocks
   personalization and the new navigation. *(In progress.)*
2. **Premium / early-access screen** — a screen with copy, no payment flow.
   Makes the commercial frame real before any mechanic depends on it
3. **Pre-launch checklist** — §10.1 below
4. **Public launch** — topic mode + onboarding + premium teaser only, no
   streak mode yet
5. **Streak mode** — built as a fast-follow *after* launch, informed by real
   D1/D7 data rather than built blind. Instrument token usage here regardless
6. **Rewarded video gate** — after streak mode exists to gate
7. **Cost measurement + decisions 7.1 / 7.2** — with real numbers
8. *(Later phases)* accounts + backend → social/competition → AI voice mode

### 10.1 Pre-launch checklist

Gaps identified when actually planning the launch step — none of these were
fully resolved earlier in this document.

- **Distribution channel — still an open decision.** TestFlight (Apple
  Developer Program enrollment, $99/yr, build signing, ~24–48h Apple review
  for a public link) vs. a web build vs. both. Affects the timeline directly;
  needs a decision before step 4 can be scheduled concretely.
- **API key safety — real gap, not yet solved.** A public build puts the
  Anthropic key in front of strangers, embedded or (worse, on web) visible in
  network requests. Two paths: (a) a minimal server-side proxy that holds the
  key server-side — some backend, but far smaller than the full accounts
  system deferred in §5; (b) keep the key client-side, accept the risk,
  mitigate with a local daily session cap, a low spend limit/alert on the key
  in the Anthropic console, and a plan to rotate the key fast if abused. No
  decision made yet — needs one before launch.
- **Minimal retention measurement** — see §9. Must exist before step 4, or
  launching produces no answer to the question it's for.
- **Device/OS coverage** — testing so far is the developer's own
  device/simulator only; public users won't be.
- **Feedback channel** — usability testing had a researcher in the room;
  public users don't. Needs some low-effort in-app path (even a mailto link)
  to collect qualitative signal at all.
- **Privacy note** — onboarding collects name and learning goal. Even stored
  locally, a one-line notice is cheap and builds trust with strangers in a
  way it didn't need to with in-person testers.

---

## 11. Ideas parking lot (not committed)

Surfaced during Ahmet's own hands-on testing of Phase 1 (2026-08-24, same
treatment as a self-reported finding — see `prd.md`'s P4 precedent). Not
designed, recorded so they aren't lost or accidentally treated as decided.

- **Profile picture on Home, next to the personalized greeting — promoted,
  in progress (2026-08-24).** Building a first version now: local stock
  avatar picker (no upload pipeline), avatar shown next to the Home
  greeting. Upload-your-own-photo explicitly deferred to a later pass. Still
  a zero-evidence bet like the rest of §3's bet list — no participant asked
  for this, it's Ahmet's own design instinct — labeled as such, not as a
  research finding.
- **Settings nav icon becomes the user's avatar** instead of a generic gear
  icon, once avatars exist — still parked, not part of the current build.

---

## 12. v2.1 — Serbest / deneme / ücretli akış (2026-09-02, taslak — açık noktalar işaretli)

Bu bölüm, launch öncesi maliyet gerçeğinin netleşmesiyle ortaya çıkan bir ek karar
turu. §6 ve §7.1/§7.2'yi geçersiz kılmıyor, onları somutlaştırıyor. Kendi ilkemiz
gereği ("Open decisions in §7 get resolved in place") ayrı bir doküman açmak yerine
burada, gerekçesiyle birlikte işleniyor.

### 12.1 Neden bu değişiklik

Topic Practice, ödeme yapsın yapmasın her kullanıcı için gerçek bir Sonnet API
çağrısı tetikliyor (üretim + toplu değerlendirme). Ölçeklenmiş, kalıcı ve tamamen
ücretsiz bir Topic Practice, kullanıcı sayısı büyüdükçe doğrudan orantılı bir
maliyet demek — 100 günlük aktif kullanıcıda kaba tahminle aylık ~$90-270, 1000'de
~$900-2.700 (gerçek token ölçümü henüz yapılmadı, bkz. §7.1 önkoşulu). Bu, "her şey
erken erişimde ücretsiz" konumlandırmasını (§6) sürdürülemez kılıyor.

### 12.2 Yeni özellik matrisi

| | Free (kalıcı) | Trial (3 gün, yeni kullanıcıya bir kez) | Paid |
|---|---|---|---|
| Günlük test | Var — herkese aynı, günde 1 kez üretilir, sabit cevap anahtarı, LLM değerlendirmesi yok | Var | Var |
| Topic Practice | Yok | Var — tam kişiselleştirilmiş üretim + plain-language feedback | Var |
| Streak / Voice | Yok (henüz üretilmiş özellik yok) | Yok | Var olduklarında |
| Marjinal API maliyeti | ~0 (deterministik) | ~$0.03/seans (bkz. §12.4) | ~$0.03/seans |

Free tier artık "az özellikli Topic Practice" değil, yapısal olarak farklı bir
mekanik — bu yüzden maliyeti kullanıcı sayısıyla neredeyse hiç büyümüyor.

### 12.3 Ekran akışı (v2.1)

```
İlk açılış
  Welcome (değer anlatımı)
    -> Onboarding (isim + öğrenme amacı, local)
      -> Günlük Test (Day 0, herkes görür)
        -> Sonuç ekranı (statik, önceden yazılmış yorumlarla — §12.5)
          -> Paywall/Trial teklifi ("kişisel geri bildirim" çekirdek vaadiyle)
            - 3 gün dene -> Topic Practice tam açık (trial süresi boyunca)
            - Şimdilik geç -> Home, sadece Günlük Test + kilitli Topic Practice tile'ı

Sonraki açılışlar
  Home
    - Günlük Test (her zaman erişilebilir)
    - Topic Practice — trial/paid aktifse açık, değilse kilitli -> dokunulunca paywall
    - Streak / Voice — [AÇIK NOKTA, bkz. 12.6] henüz yok, App Store riski nedeniyle
         Home'dan tamamen kaldırılıp Premium ekranına taşınması öneriliyor
    - Review, Settings — değişmiyor
    - Trial bitti + ödeme yoksa -> sessizce Free'ye düşer [AÇIK NOKTA, bkz. 12.6]
```

### 12.4 Trial maliyeti (kaba tahmin, Sonnet 5 fiyatlandırmasıyla: $2/$10 MTok)

Seans başına ~$0.03 varsayımıyla, 3 günlük trial:
- Gerçekçi kullanım (1-3 seans/gün): toplam ~$0.09–$0.27
- En kötü senaryo (günlük cap'e dayanma): toplam ~$0.90

Trial başına maliyet, normal bir müşteri kazanım maliyeti seviyesinde — asıl risk
kalıcı/sınırsız ücretsiz kullanımdı, o artık §12.2'deki mekanikle kapanıyor.

### 12.5 Günlük Test'te "neden yanlış" yorumu — MC'ye dönmeden

Fikir: kullanıcının verdiği yanlış cevaba önceden yazılmış, esprili/açıklayıcı bir
yorum göstermek ("değer hissi" yaratmak için). Kabul edilebilir ve maliyeti sıfıra
yakın (günlük üretim sırasında, tek bir LLM çağrısıyla üretilip statik olarak
saklanıyor — kullanıcı sayısından bağımsız).

Ama literal "A yerine B'yi seçti" çerçevesi çoktan seçmeli formatı gerektiriyor —
bu, prd.md §2.2 Theme 1'de 7 kullanıcının 5'inin reddettiği, kesin kapatılmış bir
format. Free Test'te bile MC'ye dönmek bu bulguyu es geçmek olur.

Önerilen çözüm: format serbest metin kalır (fill-in-the-blank / error-correction,
mevcut tipler). Günlük üretim sırasında, LLM'den doğru cevabın yanında en yaygın
2-3 yanlış cevabı ve her biri için önceden yazılmış yorumu da üretmesini istiyoruz.
Kullanıcı cevabı yazınca: tam eşleşiyorsa doğru; önceden tahmin edilen yaygın
hatalardan biriyle eşleşiyorsa o hataya özel yorum; hiçbiriyle eşleşmiyorsa jenerik
"tam değil, doğrusu şu" mesajı. Format kullanıcıya hâlâ serbest yazım olarak
görünüyor, MC hissi yok — ama en sık yapılan hatalarda kişiselleşmiş gibi hisseden
statik bir yanıt var.

Not: bu, kimsenin talep etmediği bir bahis (§3'ün evidence tablosu anlamında) —
Ahmet'in ürün sezgisi, araştırma bulgusu değil. Böyle etiketlenmeli.

### 12.6 Kararlar (2026-09-02)

- **RevenueCat kullanılacak.** Ücretsiz (2.500$ takip edilen gelire kadar), receipt/
  entitlement yönetimini sıfırdan yazmaktan daha güvenli, ayrıca trial→paid dönüşüm
  gibi PM verisini hazır dashboard'da veriyor.
- **Trial mekanizması teyit edildi:** ödeme yöntemi trial başlarken alınıyor, 3 gün
  sonunda kullanıcı iptal etmediyse otomatik ücretlendirme oluyor — bu App Store'un
  auto-renewable subscription + introductory trial yapısının standart işleyişi,
  ayrıca bir "paywall hatırlatma ekranı" kurmamıza gerek yok, yenileme bildirimini
  Apple sistem seviyesinde zaten gönderiyor. Tek fark: bu, "trial'ı hiç başlatmadan
  Free'de kalan" kullanıcı için geçerli değil — onlara trial'ı tekrar teklif edip
  etmeyeceğimiz (ör. X gün sonra bir kez daha) hâlâ ayrı ve açık bir soru, bkz. 12.7.
- **Streak/Voice tile'ları Home'dan kaldırılacak.**
- **Günlük Test soru havuzu: hata-profiline-göre "cohort" yaklaşımıyla — bkz. 12.8.**
- **Nav bar: D önerisi onaylandı** (pill kabuğu kalır, iç blok kalkar, sadece ikon/
  renk/nokta ile aktif durum).
- Paywall ekranının App Store zorunlu unsurları (Restore Purchases, fiyat/süre net
  gösterimi, gizlilik/şartlar linki) — v2.1 kapsamına eklenmeli.

### 12.7 Trial'ı hiç başlatmayan kullanıcı — hatırlatma (açık, küçük öneri)

Teknik mekanizma zaten trial-başlatmış kullanıcı için bir hatırlatmaya ihtiyaç
duymuyor (12.6). Ama "no fake it" / güven inşası ilkemize uygun, zorunlu olmayan
bir ekleme: trial bitmeden ~1 gün önce, uygulama açıldığında "deneme yarın bitiyor,
ondan sonra X ücret alınacak, iptal buradan" diyen küçük bir in-app banner —
Apple'ın kendi sistem bildirimine ek, kullanıcının "beni bilgilendirmeden ücret
kesildi" hissetmesini engelleyen ucuz bir güven adımı. Zorunlu değil, önerilir.

### 12.8 Günlük Test soru havuzu — rastgele mi, profile göre mi, maliyet farkı

Fark şurada: tamamen paylaşımlı (mevcut plan) günde **1** üretim çağrısı demek —
kaç free kullanıcı olursa olsun sabit, neredeyse sıfır maliyet. Kullanıcı başına
tam kişiselleştirme ise günde **kullanıcı sayısı kadar** üretim çağrısı demek —
tam olarak az önce çözdüğümüz ölçeklenen-maliyet sorununu geri getirir (üretim-
sadece maliyeti bile 1.000 free kullanıcıda kabaca aylık $300-450 civarına çıkar).

Orta yol — **cohort/bucket yaklaşımı, önerilen:** her gün tek bir soru seti yerine,
hata kategorisi başına (ör. "artikeller", "zamanlar", "edatlar" gibi 5-8 kategori)
birkaç varyant üretilir. Free kullanıcının hata profili varsa (geçmiş pratikten),
en sık hatasına en yakın varyanta deterministik olarak atanır; profili yoksa
(yeni kullanıcı) rastgele/varsayılan varyant. Günlük üretim çağrısı sayısı 5-8'de
sabit kalır — kullanıcı sayısından bağımsız, aylık maliyet birkaç dolar civarında
kalır — ama kullanıcı "bana göre" hissini büyük ölçüde alır. Maliyetsiz gerçek
kişiselleştirme yok; ama bu, hissi neredeyse aynı verip maliyeti sabit tutan bir
uzlaşma.

**Karar (2026-09-02): cohort/bucket yaklaşımı onaylandı.** §12'deki tüm açık
noktalar bu turla kapandı.

**Düzeltme (2026-09-02, aynı gün):** Yukarıdaki cohort/bucket maliyet mantığı
yanlıştı — "günde 1 üretim, herkese paylaşımlı" varsayımı bir backend gerektirir.
GrammarLens'te backend yok (§5, bilinçli guest-first kararı); her cihaz kendi
Günlük Test'ini kendi API çağrısıyla üretmek zorunda. Yani paylaşımlı ile
kullanıcı-başına-kişisel arasında gerçek maliyet farkı yok — ikisi de günde 1
üretim çağrısı/cihaz.

**Güncel karar:** cohort/bucket karmaşasına gerek yok. Günlük Test doğrudan
cihazın kendi (local) hata profiline göre üretilir — zaten günde 1 çağrı
yapılacaktı, kişiselleştirmenin ek maliyeti yok. Profili olmayan (yeni)
kullanıcı için genel/rastgele bir set üretilir. Gerçek maliyet avantajı
paylaşımdan değil, iki şeyden gelir: günde yalnızca 1 kez üretilmesi (Topic
Practice gibi tekrar tekrar değil) ve hiç LLM değerlendirme çağrısı
yapmaması (deterministik kontrol). Kaba tahmin: ~$0.01-0.015/cihaz/gün
(yalnızca üretim) → 100 DAU'da aylık ~$30-45, 1000 DAU'da ~$300-450 — Topic
Practice'ten belirgin ucuz ama "neredeyse sıfır" değil. Gerçek paylaşımlı
üretim (sunucusuz bir fonksiyonla günde 1 kez üretip tüm cihazlara aynısını
servis etmek) bir backend eklemek demek — kullanım büyürse değerlendirilecek
bir sonraki adım olarak not düşülüyor, şimdilik yapılmıyor.

---

*Living document. Open decisions in §7 get resolved in place, with the
reasoning kept, not overwritten.*
