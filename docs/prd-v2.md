# PRD v2 — GrammarLens

**Version:** 2.0 (draft)
**Author:** Ahmet Emin Tayfur
**Date:** August 2026
**Status:** v2 shipped
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
- **AI Practice Partner** — bet: speaking practice is the premium-worthy
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
  ├─ AI Practice Partner  (premium — later phase, locked placeholder in v2)
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
*(Removed 2026-09-21, §13.11: the two optional Profile fields were dropped
entirely; nothing ever read them.)*

*Rationale:* every field asked before the user has experienced value costs
completions, and this is an unknown app. Name earns its place by powering
personalization; learning goal earns its place by feeding topic suggestions —
which partially answers T1's "I don't know where to start." Age and occupation
are currently marketing data only, with no in-product use, so they don't
justify their friction yet.

### Settings
Does not exist today. Minimum: theme (light/dark/system), name edit, data
reset (currently only possible by deleting the app), and optional profile
fields (age, occupation) for users who want to fill them in. *(The optional
fields were removed 2026-09-21, §13.11.)*

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
- AI Practice Partner — premium placeholder only in v2; built in a later phase
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
8. *(Later phases)* accounts + backend → social/competition → AI Practice Partner

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
  *(Corrected 2026-09-21, §13.9: the wording that shipped, "never sent to a
  server", was false once the proxy and Firebase existed.)*

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

> **Superseded 2026-09-21 — see §13.12.** The Daily Test is no longer built
> from the local error profile; every request is the same general mix. The
> reasoning below is kept as history.

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

## 13. v2.2 — Monetization surface and Home (2026-09-05)

Decided in a working session after the design audit (`docs/design-audit.md`).
These supersede the parts of §6 and §12 they contradict; the earlier reasoning
is kept in place rather than rewritten.

### 13.1 "Early Access" is retired

The Early Access screen and the Paywall screen were doing the same job badly.
Early Access listed what is free / trial / paid and carried a "Start free
trial" button; the Paywall argued the value and carried the same button. A user
heard a different story depending on which one they reached, and neither screen
was complete.

**Decision:** merge them into one Premium screen that both explains and sells.
Early Access's free/trial/paid table is good content and survives the merge;
the Paywall's purchase block, price and required disclosure sit under it. The
name "Early Access" no longer describes anything — it was never a time-limited
campaign — and is dropped.

### 13.2 Trial model: 7 days, card up front, auto-converting

Replaces the 3-day trial everywhere (Home locked card, the free/trial/paid
table, the Day-0 pitch, the paywall). Configured as a 1-week introductory offer
on the App Store Connect products; RevenueCat reads it rather than defining it.

Two implementation constraints, both App Store review matters, not preferences:
- Trial length is never written into copy by hand. It comes from a single
  source — ideally the package's introductory offer once RevenueCat is
  connected, a single named constant until then. Displayed terms that disagree
  with what is actually sold are a rejection reason.
- The purchase point must disclose trial length, the price after it, the
  renewal period, that it auto-renews unless cancelled, and carry Privacy and
  Terms links.

**Superseded 2026-09-17 — different trial length per plan: 3 days monthly, 7
days annual.** Configured in App Store Connect the same day: monthly
(`grammarlens_premium_monthly`) gets a 3-day free introductory offer, annual
(`grammarlens_premium_annual`) keeps 7 days (App Store Connect models it as a
"1 Week" duration, not "7 Days" — RevenueCat/StoreKit report it back as
`periodUnit` WEEK, `periodNumberOfUnits` 1, not as 7 days; the purchase
point's disclosure text converts week-unit trials to days for display so the
two plans read in comparable units). Rationale: steer users toward the annual
plan by putting the longer trial on the plan that is worth more to us — a
bet, not a user finding, same status as the pricing bet below. Known side
effect: introductory offers are one per subscription group, so a user who
already used the monthly 3-day trial does not get the annual 7-day trial on
switching plans. The first implementation constraint above (never hand-write
trial length; read it live) is unaffected and, if anything, is now load-
bearing — the two plans genuinely differ, so no single hardcoded number could
ever have been correct for both. The reasoning above is kept rather than
rewritten, per this document's own rule.

### 13.3 Pricing

$9.99/month, $89.99/year. The annual plan is presented as its per-month
equivalent ($7.49/month, billed annually at $89.99) with a "Save 25%" marker;
annual is preselected. The 7-day trial applies to both plans. *(Superseded
2026-09-17: 3 days monthly, 7 days annual — see §13.2.)*

**Superseded 2026-09-07 — final pricing: $5.99/month, $49.99/year.** The
annual plan is presented as $4.17/month, billed annually at $49.99, with a
computed "Save 30%" marker; annual stays preselected and the 7-day trial still
applies to both. The reasoning above is kept rather than rewritten, per this
document's own rule.

**Superseded 2026-09-17 — the per-month figure and the savings-badge math,
corrected against a real device.** Confirmed live on-device with the real
App Store products: StoreKit presents the annual plan's per-month equivalent
as **$4.16**, not the $4.17 stated above — it truncates 49.99 / 12 = 4.1658...
to two decimals rather than rounding. The 2026-09-07 note's "Save 30%" was the
intended figure, but the shipped code computed it from that truncated $4.16
value and then rounded up, which produced "Save 31%" on-device — an
overstated discount, not what was written above. The savings badge is now
computed directly from the two products' real raw prices (annual vs.
12 × monthly, no intermediate rounding) and floored rather than rounded, so
display rounding can't overstate the discount again: 1 − 49.99 / (12 × 5.99)
= 30.44% → 30%, matching what this section always intended. The reasoning
above is kept rather than rewritten, per this document's own rule.

**Superseded 2026-09-17 — the trial length is no longer the same on both
plans.** See §13.2's own 2026-09-17 note: monthly is a 3-day trial, annual is
7 days, deliberately asymmetric to steer toward annual. Pricing itself
($5.99/month, $49.99/year, the computed savings marker, annual preselected)
is unaffected — only the "the 7-day trial still applies to both" clause above
no longer holds. The reasoning above is kept rather than rewritten, per this
document's own rule.

Why the change, in order of weight:
- The $89.99/$9.99 pair was a 25% annual discount. $49.99 against $5.99 is
  30% (8.4 months paid for 12), a stronger pull toward the plan that is worth
  more to us: cash up front, the 7-day trial cost amortized over twelve
  months, and no monthly churn decision.
- $5.99 sits clearly under the category comparison set (Duolingo, Grammarly,
  ELSA all around $12) without reading as disposable.
- Margin holds. See §13.7. The binding cost risk was never the price point.

Recorded as a bet, not a finding — no user has seen either number.

Prices are never hardcoded — Apple returns them in the viewer's currency, and
the per-month figure is computed from the real annual price in the same
currency, not stored as a second constant.

No invented social proof ("most popular", "join thousands"). The product has no
users yet and the repo's first working principle forbids claiming otherwise.

### 13.4 Nothing unbuilt is sold

"Unlimited Streak Mode" and "AI Practice Partner" were listed with "Coming
soon" tags on the old Early Access screen. That was acceptable on an
informational screen. It is not acceptable on a screen that takes money: Apple
expects advertised subscription features to exist, and listing them as part of
the offer contradicts the project's own no-fake-it rule.

**Decision:** the purchase surface lists only what exists today — Topic
Practice and its personalized plain-language feedback. Roadmap items, if shown
at all, sit outside the purchase block and are not tied to the price.

### 13.5 Home becomes a "today" screen, not a menu

Home looked empty after Streak Mode and Voice Practice were removed. Putting
them back was considered and rejected: they were removed precisely because they
were dead coming-soon cards, and filling space with non-existent features is
the failure mode this project is built to avoid.

The real problem is that Home has data and shows none of it. New structure:

1. Orange header band — greeting and avatar.
2. **Today** — the actual state of the Daily Test: an invitation if unsolved, the
   score plus "new test tomorrow" if solved. Largest block on the screen, since
   this is the free core loop.
3. **Topic Practice** — locked or unlocked, as today.
4. **Your weak spots** — the two or three most frequent, tappable through to
   detail; shown only when they exist (no empty state — the Review tab already
   covers that). For a free user these are locked, and the tap opens the
   Premium screen naming that specific weak spot.
5. A quiet Premium row for free users — a row, not a banner.

### 13.6 Evidence status of the above

All of §13 is a **bet**, not a finding. No user has seen any of it. In
particular, one tension is recorded rather than resolved: a free trial (7
days on annual, 3 on monthly since 2026-09-17, §13.2) requires a card, and the Day-0 flow asks for it roughly two minutes into first
launch, before the user has ever used Topic Practice. That may convert poorly
and may read as pressure, which sits badly with the calm, no-pressure
positioning this product is built on. The alternative — surfacing the offer at
the moment the user feels the limit instead — cannot be compared without
retention data we do not have. Revisit once real numbers exist.

### 13.7 Unit economics (2026-09-07)

Derived from the deployed proxy, not from guesswork about the app: model
`claude-sonnet-4-6`, fixed 5-question sets, a Topic Practice session is two
calls (`generate_practice_set` + `score_answers`), Daily Test is one
generation call per device per day, `max_tokens` 2048 throughout.

**Correction to §12.4.** That estimate priced tokens at $2/$10 per MTok
(Claude Sonnet 5). The model actually deployed is Sonnet 4.6 at **$3/$15** —
50% higher per token. §12.4's ~$0.03/session figure happens to survive the
correction; its stated basis does not.

| Unit | Cost |
|---|---|
| One Topic Practice session (generate + score) | $0.034 |
| One Daily Test generation | $0.021 |

Monthly cost per device:

| Scenario | Monthly |
|---|---|
| Free, occasional (10 daily tests) | $0.21 |
| Free, every day (30 daily tests) | $0.63 |
| Premium, light (12 active days, 12 sessions) | $0.66 |
| Premium, typical (20 active days, 30 sessions) | $1.43 |
| Premium, heavy (30 days, 60 sessions) | $2.66 |

Against $5.99/month (net $5.09 after Apple's 15%): 87% margin light, **72%
typical**, 48% heavy. Against $49.99/year (net $3.54/month): 81% light, **60%
typical**, 25% heavy. The annual plan is the thinner of the two by design —
that is what the up-front cash and removed churn are bought with.

**§12.2's feature table is now wrong** where it lists the free tier's marginal
API cost as "~0 (deterministik)". §12.8 already corrected the reasoning — every
device generates its own Daily Test, there is no shared backend — but the table
was never updated. A free user who opens the app daily costs **~$0.63/month and
returns nothing**. That, not the subscription price, is the structural cost
exposure.

**Device cap lowered 30 → 15/day (2026-09-07).** At 30 operations/day a single
device could run ~14 sessions/day and cost ~$30/month against $5.09 of revenue.
15/day still allows ~7 sessions/day — beyond any real usage pattern — and caps
worst-case exposure at roughly $8-15/month per device. `GLOBAL_DAILY_LIMIT`
stays at 300, which bounds total spend at ~$300/month until it is raised.

**Everything above is estimated, not measured.** System prompt sizes are real
(read from `proxy/src/anthropic.ts`); user prompt and completion sizes are
modelled. Anthropic returns `usage.input_tokens` / `usage.output_tokens` on
every response and the proxy currently discards it. Logging those two numbers
per operation closes §7.1's instrumentation prerequisite and replaces this
whole section with data. Do that before the numbers here are used for any
further decision.

### 13.8 Daily session cap lowered 10 → 5 (2026-09-21)

`StorageService.dailySessionLimit` goes from 10 to 5. This is a margin
decision, made on the §13.7 estimates (which remain unmeasured): at ~$0.034
per Topic Practice session, 10 sessions/day would cost ~$10.20/month for one
device, while the annual plan nets ~$3.54/month. At 5 the worst case is ~$5.10.

It also closes the proxy-headroom conflict recorded in `docs/roadmap.md`
(2026-09-15): a session is 2 proxy units (generate + score), so 5 sessions are
10 units, plus 1 for the Daily Test — inside `DEVICE_DAILY_LIMIT` = 15, which
is deliberately **not** changed. The local cap now always binds before the
proxy's generic per-device wall. The cap is a cost guardrail, not a product
promise: no user-facing copy states it except the "That's all for today"
dialog, and nothing anywhere says "unlimited". This resolves §7.2's open
cap number for launch only; revisit with the token-log data (§13.10).

### 13.9 Onboarding privacy note corrected (2026-09-21)

The onboarding line "Stored only on this device — never sent to a server"
(§10.1) was false: practice answers go through the proxy to Anthropic, and
Firebase receives usage and crash data. It is replaced with: "Your name and
goal stay on this device. Practice answers are sent to our AI provider to give
you feedback, and usage and crash data is collected." This is what the code
does (name and goal are sent to neither the proxy nor analytics) and agrees
with the published privacy policy. Any future in-app privacy claim should be
checked against that policy and against the App Store privacy label, not
written from memory of an earlier architecture.

### 13.10 Token logging in the proxy (2026-09-21)

§13.7's unit economics are estimates: prompt and completion sizes were
modelled, and the proxy threw away Anthropic's `usage` object. The proxy now
logs, per successful Anthropic call, the operation kind (`daily_test` /
`topic_practice`), the exact operation, the question count and the real input
and output token counts, via `console.log` into Workers Logs. It logs nothing
user-related (no device id, prompts, questions, answers or generated text);
a test plants secrets in every request and response field and asserts none
reaches any console channel. See `proxy/README.md`.

Status: deployed; data is accumulating. Until
a few weeks of real traffic are measured, every figure in §13.7, the session
cap (§13.8) and the unit economics above stay estimates. Options if the data
must outlive Workers Logs' short retention, **not built**: (1) Workers
Analytics Engine — one data point per call, SQL queryable, months of
retention, the smallest change from today's `console.log` and the
recommended next step; (2) Logpush of Workers Logs to R2 — keeps raw lines,
needs a paid plan and a query tool; (3) a daily aggregate in KV or D1 —
smallest storage but needs new counter code and loses raw per-call detail.
Any of these would only ever hold the same non-personal fields.

### 13.11 Age and occupation removed from the profile (2026-09-21)

The optional Age and Occupation fields on Profile are removed: UI, model and
storage. Before removing them, every use in the code was checked: they were
read by nothing — not prompt generation, not any request body to the proxy
(which rejects unknown fields anyway), not analytics, not Home or Premium.
They were stored and shown back, nothing more, so removing them loses no
personalization. Schema v19 rebuilds `user_profile` without the two columns
and deletes every stored value; name, learning goal and avatar are kept. Data
that is never used should not be collected: this also shrinks what the privacy
policy has to describe. The policy page never mentioned age or occupation as
collected data (its only age wording is the 13+ audience statement, which
stays). If a real use appears later, ask for it at the moment it pays off, not
in a settings form.

### 13.12 Daily Test no longer sends weak spots (2026-09-21)

`generate_daily_test` used to send the device's most frequent error topics
(`topicId` and `frequency`, derived from what the user got wrong) so the prompt
could bias the set. That is removed: the client sends only the anonymous quota
`deviceId` (used by the proxy, never forwarded to Anthropic) and the question
count, and the prompt is a fixed general mix. Reasons: after launch the Daily
Test moves to one shared set for everyone (roadmap, out of scope for launch),
personalization is kept for Premium, and with this change the Daily Test sends
no user data to Anthropic at all, which keeps the privacy story to one
sentence (only Topic Practice answers leave the device, and only with the
user's permission, §13.13).

The proxy removes the field entirely rather than accepting and ignoring it. It
already rejects unknown fields, so a request that carries `weakSpots` now gets
a 400 and never reaches Anthropic; the guarantee is enforced and tested
server-side, not just by what today's client happens to send. The app has never
shipped, so no older client depends on the field. What is lost: a user's
Daily Test no longer leans toward their own weak spots. The local error profile
is still written by the Daily Test and still feeds Home and Review; it just no
longer feeds generation.

### 13.13 Permission before answers go to the AI provider (2026-09-22)

Only one thing the app does sends what the user wrote to a third party: Topic
Practice scoring (`score_answers`: the question text and the typed answer, to
Anthropic's Claude through the proxy). App Review guideline 5.1.2(i) requires
that to be disclosed and explicitly permitted first. The permission is asked
once, on the first Topic Practice launch, inside `launchPracticeSet`
(the single choke point, no caller-supplied flag), before the length picker and
before anything is generated or counted. It is versioned, stored locally,
fails closed, and is revocable from Profile → Data (part 2). Declining keeps
the Daily Test fully working, since it sends nothing about the user (§13.12).
The screen states what is sent, to whom, why and what never leaves, and
deliberately makes no claim about the provider's own handling of the data.

Part 2: Profile → Data has the switch (on re-shows the screen, off is
immediate), the onboarding note (§13.9) now names "Anthropic (Claude)" and says
the user is asked first, and `ai_consent_result` (analytics plan E7) reports
granted, declined and revoked with the place and wording version, no content.

### 13.14 The first day, revised (2026-09-22)

Four decisions change §12.3's first-launch sequence and the days after it.
The first day now runs **Welcome → Onboarding → a fixed Daily Test → results →
Home climbs → Premium**.

1. *The first test is fixed, not generated.* Five hand-written questions ship
   with the app (three fill-in-the-blank, two error-correction, one per topic,
   with predicted wrong answers and their comments). It opens at once, offline
   and with no generation cost, and the answer key was read by a person before
   any user sees it. Later days are unchanged (§12.8). `daily_test_completed`
   reports `set_source` (`bundled` / `generated`), so the two can be compared.
2. *The result screen has one button and the win comes first.* The Welcome badge
   card sits under the results; the confetti plays on the user's tap ("Start my
   climb"), for its whole run, and only then does Home appear. The paywall card
   that used to end this screen is gone.
3. *The paywall comes after the payoff, once.* Home opens the Premium screen by
   itself about 600 ms after the pawn finishes the first climb (or when Home has
   loaded, if no step was earned), once per install, only for a user who finished
   the test and does not already have full access. The step in §12.3's diagram,
   "Result → paywall offer", is replaced by this. Hypothesis to read from data:
   the moment right after a visible win converts better than the moment right after
   a result list; the sources `day0_after_climb` (this) against `home` and the
   others in `paywall_viewed` / `purchase_result` will show it, but not before
   there are users.
4. *Tomorrow's test is prepared when today's is completed.* The next day's set is
   generated in the background at that moment and cached under its date, so the
   Daily Test opens with no wait from the second day on (§12.8's once-per-day
   generation is unchanged; it just happens a day earlier, in the background). A
   failure is silent and falls back to generating on open. The proxy was not changed.

---

*Living document. Open decisions in §7 get resolved in place, with the
reasoning kept, not overwritten.*
