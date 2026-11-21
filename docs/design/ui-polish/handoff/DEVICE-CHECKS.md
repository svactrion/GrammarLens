# Device checks — `ui-polish-widgets` on the iPhone 14 Plus

One ordered checklist for the owner's phone. It covers the UI polish
(SPEC v10, fix rounds 1 and 2), the widgets and reminders, the
integration of the two (`INTEGRATE.md`), fix round 3 (`FIX3.md`, SPEC v11),
fix round 4 (`FIX4.md`, SPEC v12) and fix round 5 (`FIX5.md`, SPEC v13),
whose fourth pass is below, the first-wave topics switched on for
1.5.0 (`docs/TOPICS.md` phase D; the Worker is deployed, owner 2026-11-19),
and fix round 6 (`FIX6.md`, SPEC v14), whose check comes first. It merges fix round 2's "Owner
device checks" (`PROGRESS.md`) and the widgets run's "Owner steps"
(`PROGRESS-widgets.md`). Nothing on this list was checked on a device by
the runs that wrote it; what the owner has seen on his phone is marked on
the item. The simulator results are in `PROGRESS.md`.

Each item gives what to do, what you should see, and the board ID (the
boards are in `boards/`). Write down anything that differs: the item
number and what you saw is enough.

## The owner's result (2026-11-21)

Recorded before the merge into `main` (`docs/RELEASE-1.5.0.md` step 1). On
2026-11-21 the owner reported his device checks of 19 to 21 November and
gave his word for the merge and the 1.5.0 version bump:

- the day's step plays before the rest scene (FR6-3 item 6, fix round 6
  item 1): **seen**;
- the Daily Test card's companion (FR6-2 item 2, fix round 6 item 2): **his
  decision: it stays as specified, no change**;
- Review's inline mistakes on the new topics (FR6-4 item 9, fix round 6
  item 3): **seen on 2026-11-19**;
- the reminders arrive and the widgets work: **seen** (in general; the
  widget and reminder items below are not itemised beyond that);
- in his words, everything else works flawlessly; he did not report the
  remaining items one by one.

From his check of 2026-11-19: T-1 seen; T-2 seen for Conditionals, Passive
Voice, Prepositions and Relative Clauses (Comparatives & Superlatives: not
reported); T-3 seen; T-5 and T-6 could not be checked with a new topic
(his most repeated weak spot is in an older topic; the rest scene's deck
and the widget were seen with that one), so they stay covered by tests
only.

Every other item on this list that is not marked seen is **covered by the
owner's general report of 2026-11-21, not itemised**; in the older
sections (FR5, "Still open from the third pass", FR4, FR3 and sections
1–4) that note is given once at the top of the section and applies to
each of its items not otherwise marked.

## Fix round 7 — one item for the TestFlight check

Fix round 7 (`FIX7.md`, SPEC v15, on `main`) is not a new device pass. Do
this once, during the short TestFlight check of
[`docs/1.5.0-release-steps.md`](../../../1.5.0-release-steps.md) §3:

- **A sheet follows dark mode while it is open** (item 2). Open any of the
  app's sheets — Review → the sort button ("Recent" by Weak spots), or Profile → the pencil by your
  name — then switch the phone to dark mode from Control Centre (and back)
  without closing it: the sheet's background, its grabber and its text
  change together and everything stays readable. — SPEC §3.6

**N01 after the day's step (item 1) is not on this list:** N01 is asked
once per install and your phone has answered it, so it cannot be seen
there again. It was checked on the simulator only (an iPhone 18 Pro, in
Turkish, a second day: the step walked, the save point's name, the beat,
then N01, 6.0 s after "See your climb"; captures in
`build/fix7-captures/`), and by widget tests.

## Fix round 6 — the next morning (start here)

Fix round 6 (`FIX6.md`, SPEC v14) changed three things after your check of
2026-11-19: the rest scene now comes after the day's step (item 1),
Review's inline mistake on multi-blank answers (item 3), and Review's list
after a ticket practice (found on the way). The card companion's hop was
measured and not changed (item 2). Nothing here was checked on a device:
the simulator and test results are in `PROGRESS.md` ("Fix round 6"). No
VoiceOver check is asked for. Write down anything that differs (the item
number and what you saw).

### FR6-1. Build and install

The same commands as FR5-1 below (**no Xcode step**), over the current test
build; do not delete it.

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.
Keep the interface in Turkish and your larger text size, as before.

### FR6-2. As a free user, before that day's Daily Test

1. **Home's first view.** Scrolled to the top: the pawn and the gold ring
   on the next step are above the floating nav bar. — V15, FR3-3 item 1
   *(Covered by the owner's general report of 2026-11-21, not itemised.)*
2. **The card companion (item 2).** On the Daily Test card the companion
   hops while the test waits: up by about a sixth of its height and down
   again in a little over half a second, a small squash on landing, still
   for a moment, then again (every 1.2 s). On the simulator this is what is
   drawn (16 pt at the card's 100 pt companion; the frames are in
   `PROGRESS.md`, "Fix round 6", item 2). Say whether this is the motion you
   called "as if breathing" and whether the hop should be larger at this
   size; nothing was changed. Check that Reduce Motion is off (Settings →
   Accessibility → Motion): with it on, the companion stands still. — X05
   *(Owner's decision, 2026-11-21: it stays as specified; no change.)*
3. **The widgets' "before the test" state**: "Step N is waiting" / "one
   test away", your mountain at your step; a tap opens the Daily Test. —
   W01, FR3-3 item 3 *(Owner, 2026-11-21: the widgets work; seen in
   general, not itemised.)*
4. **T-4** below (the copy that counts topics says 10). *(Covered by the owner's general report of 2026-11-21, not itemised.)*

### FR6-3. The ticket first, then the Daily Test (item 1)

5. **Use the ticket.** Review → "Biletimle pratik yap" on a weak spot → answer
   → submit → "Konulara dön". **Review's list is up to date at once** (the
   new weak spots are there with "yeni", without leaving the tab). Home:
   the ordinary Home, the ticket "used", the test still waiting.
   *(Covered by the owner's general report of 2026-11-21, not itemised.)*
6. **The Daily Test, then "Tırmanışını gör".** On Home:
   - the mountain comes into view and **the pawn walks to its new step**;
   - on a save point day (a hut, a camp, the spring) the save point lights
     up and its name shows for about three seconds;
   - the pawn **rests for about a second** with nothing else moving;
   - **the rest scene fades in** over Home (not a hard cut);
   - the reminder question (N01), if it is still due, opens once the rest
     scene stands, not over the mountain.
   Write down if the rest scene comes before the walk, if the wait feels
   too long or too short (the second is a number that is easy to change),
   or if anything jumps. — V24f, §1.8
   *(Seen by the owner: the day's step plays before the rest scene; his
   checks of 19 to 21 November, reported 2026-11-21.)*
7. **Leave and come back.** Another tab and back, then the app to the
   background and back: the rest scene is there, the step is not played
   again. *(Covered by the owner's general report of 2026-11-21, not itemised.)*
8. **T-5** below (V24f with a new topic's weak spot), if your most repeated
   weak spot is in a new topic. *(Not checked with a new topic: see T-5.)*

Not needed for this check, but if you have a Premium day: the same order
there is all five sessions first, then the Daily Test; the step, the rest
and then V24.

### FR6-4. Review's cards for the new topics (item 3)

9. **The inline mistake.** Review: on each weak-spot card, the sentence
   shows your wrong word **struck through in its place**, the right word
   green next to it, the rest plain. Nowhere a struck-through piece of the
   instruction ("… the verbs in brackets: '…"), nowhere a bracketed cue
   word, nowhere half a sentence struck through after the corrected one.
   **The three cards you saw on 2026-11-19 change by themselves** (nothing
   stored was changed, only how it is drawn): look at those first. Open one:
   its detail screen ("Senin yazdığın" / "Düzeltilmiş hali") is as before.
   If a card still looks wrong, a screenshot of the card and of its detail
   screen is what is needed to go on. — V16, R03
   *(Seen by the owner on 2026-11-19: Review's inline mistakes on the new
   topics; reported 2026-11-21.)*

## First-wave topics (1.5.0) — after the Worker's deploy

**State (2026-11-19):** the owner deployed the Worker (version
`a3f736ef-0877-4200-b0b2-a996ef20cca0`; `/health` answered `ok`, a
Conditionals practice request `200`) and installed this branch's build. On
his phone: the ten topic cards show (T-1), practice sets of the new topics
generate and are scored, and their weak spots appear in Review (T-3). The
other items are open. *(2026-11-21: the owner's result is recorded on
each item below and in "The owner's result (2026-11-21)" at the top.)*

Phase D of `docs/TOPICS.md` switched the five new practice topics on
(Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives &
Superlatives). **Deploy the Worker first** (`proxy/README.md`, "Owner
checklist — deploy for 1.5.0"): until then the new topics answer with an
error. Then build and install as in FR5-1 below (the same commands, no Xcode
step, over the current test build) and go through this section; the fourth
pass (FR5) can be done on the same install, in either order. Nothing here
was checked on a device, and no VoiceOver check is asked for. Write down
anything that differs (the item number and what you saw).

Topic names stay English in every language; the rest is in your interface
language (Turkish below).

**Needs Premium** (the sandbox trial or your subscription) for T-1 to T-3:
Topic Practice is the Premium part. Five sets are a whole day's sessions
(5 a day), so do T-2 on a day without other practice, or over two days.

1. **T-1. Ten cards on Topic Practice.** *(Seen by the owner on
   2026-11-19: the ten cards show.)* Home → Topic Practice. Ten topic
   cards, two a row, in this order: Gerund vs. Infinitive, Modal Verbs,
   Modal Past Forms, Tense Selection, Articles, then Conditionals, Passive
   Voice, Prepositions, Relative Clauses, Comparatives & Superlatives. Each
   new card has its own icon and colour, its description in Turkish and
   "not started yet" in Turkish under it. Scroll to the end: no title is cut
   ("Comparatives & Superlatives" wraps onto two lines), the two cards of a
   row are the same height, nothing touches the screen's edge. If a weak
   spot of yours is in a topic, that topic is the navy "Senin için seçildi"
   card on top and the other nine follow. — R01
2. **T-2. One set in each new topic, through to its results.** For each of
   the five: tap the card, choose a length, Start.
   - The loading screen says "<topic> konusunda soruların yazılıyor…" with
     **no number**, and the "Biliyor muydun?" card shows that topic's own
     four lines in turn. — V18
   - The questions are about that topic and each is set in a different
     everyday situation. Every fill-in-the-blank question shows its blank
     (a line of underscores with a box). A set may have one question fewer
     than you chose; that is the guard, not a fault. — V19
   - The hint (the lamp on a question, where the card is offered) shows the
     topic's card.
   - Submit: the results have **a card for every question you answered**,
     with a verdict on each. If instead a message says the scoring failed
     and your answers are still on the screen, send them again: that is the
     new retry giving up, and worth writing down with the time. — V20, V21
   - Write down any question that looks wrong and any answer you think was
     judged wrongly, with the topic. In Conditionals in particular: an
     answer that mixes two conditional types and is still called correct is
     the known weakness (5 of 132 in the measurement).
   *(Seen by the owner on 2026-11-19 for Conditionals, Passive Voice,
   Prepositions and Relative Clauses; Comparatives & Superlatives: not
   reported. Reported 2026-11-21.)*
3. **T-3. A new topic's weak spot on Review.** *(Seen by the owner on
   2026-11-19: the new topics' weak spots appear in Review.)* After T-2 you
   will have
   mistakes in the new topics. Review: each new weak spot is listed with
   its own name; opening one shows its own screen with **its own topic**
   (the topic label, the hint card, "Bunu çalış" starting a set in that
   topic, not in Gerund vs. Infinitive). "Önerilen odak" may be one of
   them. — R11, R12
4. **T-4. The copy that counts topics says 10.** As a free user (or before
   the trial): Home's topic showcase lists the topics in a row that scrolls
   sideways, the new ones included, and its button says "10 konunun tümünü
   aç". On the paywall: the benefit row says "10 konunun hepsi · …", the
   Free vs Premium table has "10 konunun tümü", and the page opened from
   the rest scene says "10 dilbilgisi konusunun tümü". Nowhere a "5" for
   the number of topics. — V14, V13, V13c, V13r
   *(Covered by the owner's general report of 2026-11-21, not itemised.)*
5. **T-5. V24f with a new topic's weak spot.** As a free user, on a day
   when the Daily Test is done, the free ticket is used and your most
   repeated weak spot is one from a new topic: the dream bubble and the
   front ticket show that weak spot's name on one line; the ticket deck's
   line without a weak spot would read "10 konudan biri". After "Tilki
   uyansın" and the trial, "practise" opens that weak spot in its own
   topic. If your most repeated weak spot is an old one, skip this and say
   so. — V24f, V13r, PW05r
   *(Not checked with a new topic, owner 2026-11-19: his most repeated weak
   spot is in an older topic; the rest scene's deck was seen with that one.
   Covered by tests only.)*
6. **T-6. The tip widget.** With the tip widget on the Home Screen and a
   weak spot in a new topic as your most repeated one: the widget's label
   is that topic's name in capitals and the tip is a line of that topic's
   card (it changes daily). Without such a weak spot the daily tip stays
   on the five Daily Test topics; that is intended. — W01
   *(Not checked with a new topic, owner 2026-11-19: his most repeated weak
   spot is in an older topic; the widget was seen with that one. Covered by
   tests only.)*
7. **T-7. The Modal Past Forms card.** Topic Practice → Modal Past Forms →
   a set: on the loading screen and in a question's hint the card now has
   these four lines, each on one line at your text size:
   "could / would: the past of can / will" ·
   "Reported: "I can" → she said she could" ·
   "modal + have + past participle: past events" ·
   "must have: sure · should have: regret". In the Daily Test, a Modal Past
   Forms question's hint shows the same card. — V18, the hint card
   *(Covered by the owner's general report of 2026-11-21, not itemised.)*
8. **T-8. The Daily Test is as it was.** Its five questions come from the
   five old topics only; no new topic appears in it. *(Covered by the owner's general report of 2026-11-21, not itemised.)*

## Fix round 5 — fourth pass

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

Fix round 5 (`FIX5.md`, SPEC v13) built the panel you chose for V24f, the
new month progress card and a paywall that closes only with its X. This
section is the fourth pass, in order; it is short. The third pass (FR4),
the second (FR3) and the first (sections 1–4) below stay for reference.
Nothing here was checked on a device: the simulator and test results are in
`PROGRESS.md` ("Fix round 5"). Write down anything that differs (the item
number and what you saw).

### FR5-1. Build and install

The same commands as FR4-1; **no Xcode step**. Install over the current
test build; do not delete it.

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.
Keep the interface in Turkish and your larger text size, as before.

### FR5-2. On this install

These need **today's Daily Test done and today's free ticket used** (Review
→ a weak spot → use the ticket, answer, submit), then Home.

1. **V24f's new panel.** Under the unchanged camp and dream bubble: the
   moon and "Bugünlük her şey tamam" alone on its row; then the small navy
   used ticket — the gold "KULLANILDI" stamp, a torn edge, and a light
   dashed slot with a clock, the time to the next free ticket (local
   midnight) and "SONRAKİ" — beside "Bugünkü ücretsiz bilet kullanıldı."
   and, in white, "Daha uykun gelmedi mi?"; then the navy Premium card: the
   gold ✦ PREMIUM tag on the left, "Günde 5 pratik" on the right, a deck of
   four orange tickets stepped down to the right, the front one saying
   "SIRADAKİ", your weak spot (one line), "Her cevaba yapay zekâ geri
   bildirimi" and "+4 / BUGÜN" on its stub, a light sweep over it every few
   seconds; "Tilki uyansın · 7 gün ücretsiz"; then "Yarın hatırlat". The
   reminder row ends just above the floating bar, with no empty band under
   it, and nothing scrolls. The panel looks the same in light and dark
   mode. — V24f
2. **Wake.** Tap "Tilki uyansın": the tickets slide into the front one,
   the companion wakes, then the paywall rises. — V24f, V24s, V13r
3. **The paywall from Wake stays until X.** On that paywall: swipe from the
   left edge to the right — nothing happens; drag down from the top —
   nothing closes it. Tap the X at the top left: the first time this
   session the reminder pop-up (V13b) opens; "Ücretsiz devam et" closes it
   and you are back on the rest scene, the companion asleep, the tickets
   spread again. — V13r, V13b
4. **The paywall from a Home topic card.** On a day before the rest scene
   (or after a fresh install), tap a locked topic card on Home: the
   paywall opens. The swipe from the left edge and the drag down do
   nothing; the X closes it (V13b only on the first X of a session). If you
   can, try the others the same way: Review's "Premium'a göz at" after the
   ticket is used, a weak spot's locked "Premium ile çalış", the offer
   on a practice's results. — V13
5. **Profile's progress card.** Profile → under the medal shelf: "Kasım
   ilerlemesi" and "<mountain> · N aktif gün" on the left; on the right
   your points large with "/ 300" and, in orange, "Bronz için N" (in green
   "Altın kazanıldı" once past 225). The bar has four parts with gaps at
   75, 150 and 225, each part tinted toward its medal; the orange fill runs
   through them part by part when the card appears; over each gap stands
   that medal in a ring (earned: full colour, a green ring and a small
   tick; not yet: faded, a grey ring), with its name and points under the
   bar; a navy dot marks your points. Check it in dark mode too: a dark
   card, the dot light blue. — V23p

### Still open from the third pass

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

These need **today's Daily Test not yet done** (the next day, or a fresh
install); they were not reached on the third pass.

1. **The sweat drop** on a wrong Daily Test answer starts at the
   companion's temple and falls along its cheek. — FR4-2 item 1
2. **Forward buttons are felt**: "Kontrol et" gives only its right or wrong
   feedback; "Devam et", "İleri" and "Gönder" give a light tap. — FR4-2
   item 2
3. **V20** centred, the last item waiting until the results are ready. —
   FR4-2 item 3
4. **Home's first view**: the pawn and the gold ring on the next step above
   the floating bar. — FR3-3 item 1
5. **The Daily Test card's companion** hops while it waits. — FR3-3 item 2
6. **The widgets' "before the test" state**: "Step N is waiting" / "one
   test away", your mountain at your step; a tap opens the Daily Test. —
   FR3-3 item 3, FR4-2 item 8 *(Owner, 2026-11-21: the widgets work; seen in general, not itemised.)*

## Fix round 4 — third pass

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

Fix round 4 (`FIX4.md`, SPEC v12) changed what you found on the second
pass. This section was the third pass; its items you could not reach are
listed again under "Still open from the third pass" above. Nothing here was
checked on a device: the simulator and test results are in `PROGRESS.md`
("Fix round 4"). Write down anything that differs (the item number and what
you saw).

### FR4-1. Build and install

The same commands as FR3-1; **no Xcode step**. Install over the current test
build; do not delete it.

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.
Keep the interface in Turkish and your larger text size, as on the second
pass.

### FR4-2. On this install

Do them in this order: the first one needs **today's Daily Test not yet
done**; the rest need it done.

1. **A wrong answer's sweat drop by the head** (needs today's test not done,
   or a fresh install). In the Daily Test, answer one question wrong: the
   companion shakes its head and the sweat drop starts at its temple and
   falls along its cheek, not above and to the right of it. Check it on the
   giraffe if you can (Profile → change your buddy). — SPEC §3.5, X01, V09
2. **Forward buttons are felt.** In the Daily Test: "Kontrol et" gives only
   its right or wrong feedback (one haptic); "Devam et" on the sheet gives a
   light tap. In a practice: "İleri" and "Gönder" give a light tap. —
   SPEC §3.4
3. **V20 centred, the last item waiting** (needs the free ticket on a
   practice: Review → a weak spot → use today's ticket, answer, submit).
   While the AI checks: the content is centred on the screen (not at the
   top with the lower half empty); "Cevapların okunuyor" and the second
   item tick, "Geri bildirimin yazılıyor" keeps a pulsing dot until the results are
   ready, then ticks just before the results open; the lens stays inside
   its window over the answers. — V20
4. **V24f on one screen with the fire by the companion** (the practice from
   item 3 done; back on Home). The rest scene and its sheet fit the screen
   without scrolling: the header ("Bugünlük her şey tamam", two small
   ticks, the countdown on the right), the Premium card (the title and the
   PREMIUM chip on one row, the tickets, "Tilki uyansın · …"), then
   "Yarın hatırlat" with the time and the switch, all above the floating
   bar. The camp sits under the dream bubble; the campfire stands at the
   companion's front right on the same ground: small logs, a two-coloured
   flame about 40 % of the companion's height, a warm glow on the ground.
   Scrolling does nothing (or only bounces back). — V24f
5. **The paywall footer** ("Tilki uyansın" opens it, or Profile →
   Premium). The pinned footer is compact: the orange button, the full
   price line under it, "Geri yükle · Koşullar · Gizlilik" on one row, and
   **no "Belki sonra"**. "Compare plans" ("Planları karşılaştır") with its
   arrow is visible above the footer on the first view. The X at the top
   left closes; the first time this session it shows the reminder pop-up
   (V13b). — V13, V13c, V13a, V13r
6. **The Turkish capitals.** "TİLKİ RÜYASINDA…" in the dream bubble (item 4,
   when a weak spot is saved) and "GERİ BİLDİRİMİN YOLDA" on V20 (item 3):
   a dotted İ, never "GERI" or "TILKI". — SPEC §3.7
7. **Profile's progress card.** Profile → under the medal shelf: "Kasım
   ilerlemesi" and "<mountain> · N aktif gün" on the left, the score capsule
   (ring, star, points, "Bronz için N") at the top right, a bar of ten
   segments filled by this month's points, "Bronz 75 · Gümüş 150 · Altın
   225" under the bar at their places, and the monthly total. Check it in
   dark mode too. — V23
8. **The widgets in light and dark.** Remove the GrammarLens widgets from
   the Home Screen and add them again once (iOS keeps the old layouts until
   then). The medium tip widget shows your latest weak spot: its topic, a
   short rule with a green pill, your own sentence with the wrong words
   struck through (red) and the corrected one (green), "Zayıf noktan · her
   gün bir yenisi"; tap the sentences → that weak spot opens in Review; tap
   the right box → the Daily Test (or Home once done, where it says
   "Tamam" and the hours to the next test with the companion asleep). Switch
   the phone to dark mode: every widget has its own dark look (a dark plum
   card, the small waiting widget a deeper orange with cream text, the done
   box dark navy), none of them system grey; the medium mountain widget is
   unchanged. — W01 *(Owner, 2026-11-21: the widgets work; seen in general, not itemised.)*

## Fix round 3 — second pass

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

Fix round 3 (`FIX3.md`, SPEC v11) changed what you found on the first
device test. This section is the second pass, in order; sections 1–4 below
are the first pass and stay for reference. Nothing here was checked on a
device: the simulator and test results are in `PROGRESS.md` ("Fix round
3"). Write down anything that differs (the item number and what you saw).

### FR3-1. Build and install

The same commands as section 1a and 1c. **No Xcode step is needed now:**
your team is set on the widget target (your change, committed as round 3's
E1). Install over the current test build; do not delete it.

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.

### FR3-2. On this install

Do them in this order: the first two need **today's Daily Test not yet
done**; the rest need it done.

1. **A wrong answer's "oops"** (needs today's test not done). In the Daily
   Test, answer one question wrong: the companion shakes its head and a
   sweat drop falls beside "Oops! So close." — V09, B8.
2. **The dark mode walk, part 1** (needs today's test not done). Switch the
   phone to dark mode (Control Centre or Settings → Display). In the Daily
   Test: the right answer's green chip and the wrong answer's red "Almost!"
   read clearly; the results' rows ("Correct", "Needs work") too. — SY03, D
3. **V18 from Review** (needs today's test done and the free ticket not
   used). Review → a weak spot → "Use today's ticket": the loading screen
   has no big title at the top, the companion thinks over three dots,
   "Writing 3 questions on <topic>…", two skeleton cards and a **blue**
   "Did you know?" card, all the same width. — V18, B7
4. **N01 right after the practice** (the practice from item 3 done). Back
   on Home: the rest scene shows and the reminder question (N01) opens at
   once, without switching tabs. Answer it either way. — §5.10, A2
5. **V24f's layout** (today's test done, the ticket used, a free account):
   the scene runs to the top of the screen behind the status bar, the night
   sheet is attached under it (no separate rounded card), the tent,
   companion and fire are whole above the sheet, and "Wake <Hero> up" is
   above the floating bar on the first view. — V24f, B1
6. **The switches**: Profile → Notifications (N03), and V24f's "Remind me
   tomorrow": white thumbs in both states, the track navy (N03) or green
   (V24f) when on. — N03, B5
7. **Profile**: the navy ribbon is the screen's width minus 60 pt, tails
   included, and no longer looks thick; the name and "Climbing with … ·
   since …" each on one line. Tap the companion: it changes to the wave
   with a soft cross-fade, not a jump. — V23, C5, C6
8. **The paywall** (a topic card on Home or a locked practice): the first
   view says "Compare plans"; it scrolls to Free vs Premium, then "Choose
   your plan" leads to the plans and the trial timeline at the end. The
   orange button and its price line stay at the bottom all the way, and
   the button already says the yearly trial before you reach the plans.
   — V13, V13c, V13a, C4
9. **The dark mode walk, part 2**: Home, Review, a weak spot, the paywall,
   Profile, Notifications, Settings in dark mode: no navy text on dark
   (links, eyebrows, icons are a light blue), soft cards are dark tints,
   nothing hard to read. — SY03, D

### FR3-3. Before today's test (the next day)

1. **Home's first view**: the pawn and the gold ring on the next step are
   above the floating nav bar. — V14, V15
2. **The Daily Test card's companion** hops while it waits. — X05
3. **The widgets' "before the test" state**: "Step N is waiting" / "one
   test away", your mountain at your step; a tap opens the Daily Test.
   — W01 *(Owner, 2026-11-21: the widgets work; seen in general, not itemised.)*

### FR3-4. Delete the app and install again (the first run)

Delete GrammarLens from the home screen, then run the `flutter run
--release …` command of FR3-1 again.

1. **Splash**: about 2.2 s; the small lens scans the word slowly (about a
   second). Open the app again later: the short splash only. — V01, C1
2. **The name screen**: the companion is large in the middle with a warm
   glow. Empty field: it waves and asks "Hi! What should I call you?".
   Typing: it looks at the field through its lens, three dots in the
   bubble. Stop typing: after a moment it cheers, hops once, three
   sparkles, "Nice to meet you, <name>!" with the name in orange, a green
   tick in the field and **one light haptic**. Type again: it listens;
   clear the field: it asks again. — V04, V04s, C2
3. **The goals**: the cards tilt right, left, right, left. — V05, B3
4. **The shine** on the goal screen's Continue (once a goal is picked) is
   a tall diagonal band across the whole button, not a small square. — B4
5. **Getting ready**: the bar is a warm track with light stripes that
   move, round stops that pop into green ticks, and the flag's pole
   standing on the last stop. — V05b, B2
6. **The mountain intro**: the flag stands on the very top of this
   month's mountain. — V06, B6
7. **Day 0**: the results come first, then "Climb my first step" opens the
   Welcome badge, then the first climb. — V10, V11, V12, A1
8. **The first climb**: "First step done! 29 to the summit." opens just
   above your companion, its tail pointing at it. — V12, C3
9. **The paywall** after the climb: the same order as FR3-2 item 8. — C4
10. **N01 after the first practice**: Review → use the free ticket on a
    weak spot → finish the practice → back on Home, the rest scene and N01
    at once. — A2

## 1. Before the first device build (once)

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

The widget extension is a new target, `GrammarLensWidgets`, and it shares
an App Group with the app. Xcode needs your team on it once. No signing
setting was written by the runs; this is the only manual step.

### 1a. Get the branch

In Terminal:

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

### 1b. Xcode: team and App Group, click by click

1. In Terminal run `open ios/Runner.xcworkspace`. Xcode opens the project
   (the **.xcworkspace**, not the .xcodeproj).
2. In the left sidebar click the folder icon at the top (Project
   navigator), then the blue **Runner** icon at the very top of the list.
3. The middle pane shows **PROJECT** and **TARGETS**. Under **TARGETS**
   click **Runner**, then the **Signing & Capabilities** tab at the top.
   Note the **Team** shown there (your team, as for every release).
4. Still in **Signing & Capabilities** for **Runner**, scroll down to
   **App Groups**. `group.com.ahmettayfur.grammarlens` should be listed
   with its box ticked.
   - If it is red or shows an error, click **Try Again** (or the small
     circular-arrow button next to it). With "Automatically manage
     signing" on, Xcode registers the group in your developer account.
   - If the box is not ticked, tick it.
5. Under **TARGETS** click **GrammarLensWidgets**, then **Signing &
   Capabilities**.
   - Tick **Automatically manage signing** if it is not ticked.
   - **Team:** choose the same team as Runner's (step 3).
   - **Bundle Identifier** must read
     `com.ahmettayfur.grammarlens.widgets`; do not change it.
   - **App Groups:** the same `group.com.ahmettayfur.grammarlens`, ticked;
     if it is red, **Try Again** as in step 4. If App Groups is missing,
     click **+ Capability** (top left of the tab), double-click **App
     Groups**, click **+** under it and type
     `group.com.ahmettayfur.grammarlens`.
6. Plug in the iPhone 14 Plus with the cable, unlock it, and tap **Trust**
   if asked. In Xcode's top bar, click the device menu (next to "Runner")
   and pick your iPhone once, so Xcode can make the provisioning profiles
   for both App IDs. Wait until both targets' Signing sections show no red
   errors (the "Signing Certificate" line shows your name).
7. Close Xcode (**Xcode → Quit Xcode**). Nothing needs to be built from
   Xcode, and nothing needs to be committed: Xcode writes the team into the
   project file, which `git status` will then show as changed — leave it, or
   commit it yourself if you want it kept.

If Xcode cannot register the group: in the Apple Developer site,
**Certificates, IDs & Profiles → Identifiers → App Groups → +**, register
`group.com.ahmettayfur.grammarlens`; then under **Identifiers** open
`com.ahmettayfur.grammarlens` and `com.ahmettayfur.grammarlens.widgets`
(create the second as an App ID if it is missing), tick **App Groups**,
**Configure**, choose the group, **Save**; then repeat step 6. Push
Notifications are **not** needed (the reminders are local).

### 1c. Build and install on the phone, in release mode

With the phone plugged in and unlocked, find its ID:

```bash
flutter devices
```

Then build and install the release build with the production config (put
your phone's ID from the list in place of `<iPhone ID>`):

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q` in Terminal; the app stays on
the phone. Expected: the build ends without a signing error. This machine's
check (`flutter build ios --release --no-codesign`, `INTEGRATE.md` 3e)
built `Runner.app` with the widget extension inside, for arm64, version
1.4.0 (7); the known Flutter 3.44.6 / Xcode 27.2 `lipo` problem only hits
`flutter build ios --simulator`, not device builds.

## 2. Install over the current 1.4.0 app (do not delete it first)

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

Step 1c installs over the App Store 1.4.0 and keeps its data. The new build
moves the database from schema 26 to 27 in one step (tested on the
simulator with a 1.4.0-shaped database). First, Settings → Accessibility →
Motion: note whether **Reduce Motion** is on (with it on, every companion
loop stops by design; that was the likely reason the companions looked
still at the first test).

1. **Your data survived.** Same name, same goal; this month's steps on
   Home; Profile's medals and "since" line; Review's weak spots; your
   language and text size. If your 1.4.0 hero was one of the seven
   retired ones, it is Fox now (expected). — V15, V23, PF02
2. **Home's first view.** The greeting is one line with your name in
   bold; the pawn and the gold ring on the next step are fully above the
   floating nav bar (the 6.7" phone keeps the full mountain window).
   — V14, V15
3. **The companions move** (if Reduce Motion is off): Welcome's sides
   float and Fox sways (you see this in part 3); Home's card companion
   hops; Profile's companion breathes and floats, and waves when tapped;
   the paywall's side companions float and the middle one hops; the rest
   scene breathes (Premium, with a rising Zzz) or shows the floating dream
   bubble (free). — V02, X05, V23, V13, V24, V24f
4. **Daily Test.** Each question has its own Check with right/wrong
   feedback and a haptic; the progress, the results and the points count
   up. — V07, V08, Q04, Q05, V10
5. **The free ticket, Review and practice.** The ticket on Review
   (free / used), a weak spot's detail, a practice session and its results.
   — X04, V16, V16b, V17–V21
6. **Profile.** The navy ribbon with its V-cut tails, your name on one
   line. Edit name with the **real keyboard**: the sheet sits right on the
   keyboard with the companion visible above, the counter reads n/40.
   **All medals:** newest first, the Welcome badge at the month you earned
   it, the counters on top. — V23, PF04, PF02
7. **The paywall** (as a free user: Home's topic cards, or a locked
   practice on Review): the trio moves,
   the button shines and pulses, the arrow nudges; scroll to the Free vs
   Premium table (it reads well at your text size); close with X: the
   exit pop-up once. — V13, V13c, V13b
8. **The free rest scene → Premium** (as a free user, with today's Daily
   Test done and the free ticket used; a sandbox account):
   - V24f: the dream bubble names today's weak spot; "Wake Fox up · 7 days
     free" is on the first view (the trial days come from the store);
   - under the Premium card, **"Remind me tomorrow"** with its time and
     switch (scroll a little if it is below the bar) — INTEGRATE 3a;
   - Wake: the companion wakes, then the paywall rises from the bottom
     (V13r); X → the exit pop-up once → back at the camp, asleep;
   - start the **sandbox trial**: PW05r, and "Practise <weak spot>" opens
     that practice. — V24f, V24s, V13r, PW05r
9. **Widgets** (long-press the home screen → Edit → Add Widget →
   GrammarLens). Open the app once first (it writes the widget data).
   - Add all three: **Climb** small, **Climb** medium, **Tip**.
   - Before today's test: "Step N is waiting" / "one test away", your
     mountain at your step; a tap opens the Daily Test.
   - After the test: "Done today", the hours to the next test, the evening
     mountain; a tap opens Home.
   - The text is in **Nunito Sans** (the app's typeface; rounded, heavy
     titles), nothing cut off; dark mode; Arabic if you switch the app to
     it (the Arabic letters use the system font). — W01 *(Owner, 2026-11-21: the widgets work; seen in general, not itemised.)*
10. **Reminders.**
    - N01 opens by itself once: on the first rest scene (V24 or V24f), or
      when you finish a Daily Test on a second day. "Turn on reminders" →
      iOS's dialog → Allow. — N01
    - Profile → Notifications: the four kinds and the time wheel; set the
      time 2–3 minutes ahead and leave the app: one reminder arrives, with
      the companion's picture; tapping it opens the Daily Test (or Review
      for "Free ticket is back"). — N02, N03
    - "Don't Allow" (or turn it off in iOS Settings): Profile →
      Notifications shows "Notifications are off" and **Open Settings**
      works. — N03
    *(Owner, 2026-11-21: the reminders arrive; seen in general, not
    itemised.)*
11. **Haptics:** Wake (medium) and the wake hop (light); Save name and the
    pencil (light); See all (light); the paywall button (medium); the goal
    cards (selection); each Daily Test answer.

## 3. Then delete the app and install again (the first run)

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

Delete GrammarLens from the home screen (this removes its data and the
widgets), then run the command of step 1c again.

1. **Splash** then **Welcome**: the companions float and sway. — V01, V02
2. **Pick a buddy** on the turntable; drag it; **"Try my luck"** spins and
   never lands on the current buddy or the previous result. — V03, V03b
3. **Your name**, then **four goals** (Exam prep, Work, School &
   university, General); each card gives a selection haptic. — V04, V05
4. **Getting ready** lasts about 4 seconds, never stalls, the companion
   thinks then hops. — V05b
5. **The mountain intro:** the flag stands **on the summit**. — V06
6. **Day 0 test** → **results** → **the Welcome badge** → **the first
   climb** (the pawn walks to step 1) → **the paywall** → **Home**.
   — V07–V12, V13
7. N01 should **not** open after this first test (it waits for a second
   day or the first rest scene).

## 4. Performance (release build)

*(2026-11-21: each item in this section not otherwise marked is covered by the owner's general report of 2026-11-21, not itemised.)*

1. The turntable drag and the wheel spin are smooth. — V03, V03b
2. Scrolling Home up and down (mountain, ticket, topics) is smooth, and the
   companions keep moving. — V14, V15
3. Opening the paywall and scrolling it is smooth. — V13

## Going back to the App Store version

To return to 1.4.0 from the App Store, delete the app and install it from
the App Store (this build's data does not carry over; Premium comes back
with "Restore Purchases" on the paywall). Do not install 1.4.0 over this build.
