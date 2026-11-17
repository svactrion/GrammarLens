# GrammarLens UI polish — design specification (final, v11, 2026-11-18)

v10 (after the owner's first device test): §1.14–§1.16, V05, V05b, V24, the new V24f, V24s, V13r and PW05r.

v11 (after the device test of the integrated build, 2026-11-18): §1.17–§1.21, §3.2 (shine), §3.3 (pose changes),
§3.5 (props everywhere), §3.6 (switch), §4, V01, V04 (+ the new V04s), V05, V05b, V06, V10/V11, V12, V13 / V13c / V13a
(new order), V18, V23, V24f, §5.10 (N01, N03), SY03 (dark mode rules).

The design was made on a claude.ai design canvas ("GrammarLens — Tüm Ekranlar
ve Senaryolar", page "Yeni tasarım — gruplar"). This folder is a complete,
offline copy of it: nothing here needs the canvas.

## 0. How to read this package

| Path | What it is |
|---|---|
| `SPEC.md` | This file: decisions, global system, every screen's intent, behaviour, motion and haptics |
| `TASK.md` | How the implementation run works (branch, batches, checks, rules) |
| `ASSETS.md` | Every new image, its size and where it is used |
| `assets/` | App-ready images (WebP) |
| `boards/<ID>.html` | The board itself: open in a browser (it loads `../assets/` and the app's `assets/`). Exact sizes, colours, radii, shadows, copy and CSS keyframes live here |
| `screens/<ID>.webp` | A static render of each board (Reduce Motion on, so loops are frozen) |

Order of precedence when sources disagree:
1. §1 "Owner decisions and overrides" below.
2. The screen's section in §5.
3. `boards/<ID>.html` for layout, sizes, colours and copy.
4. `screens/<ID>.webp` for the overall look.

Reading the boards:
- Phone boards are 390 × 844 at 1×; every px value is a Flutter logical pixel.
  Wider boards (1240–1520 px) are storyboards or system sheets.
- Copy on the boards is the English source text. Every user-facing string goes
  through the ARB files (§3.7).
- Sample data on the boards is not real: the name "Ada", Fox, the goal "Work",
  November / Ember Peak, "4/5", "+9 points", "66 to Bronze", "20:41", topic
  names, prices. Wire every value to the app's real data and rules.
- Board animations loop so they can be watched; in the app most of them run
  once. The motion notes in §5 decide.
- Text inside the boards that explains the design (labels in Turkish, red
  helper lines such as the error-correction squiggle) is not UI.

## 1. Owner decisions and overrides (final)

1. **Companions: 9 heroes, each with 6 poses** (Fox, Panda, Koala, Frog, Bird,
   Giraffe, Cat, Sloth, Crab — this order everywhere). Moods without a pose
   (the wrong-answer "oops") use the base image + motion + a prop
   (expression kit, §3.5).
2. **Retired heroes move to Fox.** Users whose saved avatar is Snail (02),
   Elephant (03), Bee (04), Chick (06), Turtle (09), Penguin (10) or Hedgehog
   (12) become Fox (14) on first launch of the new build, silently. Those
   seven never appear anywhere again. Saved format stays `avatar_XX`.
   *(This overrides the X03 board note, which still says "kept, only hidden".)*
3. **Companion picker = B1 turntable** (V03 in onboarding, R06 from Profile).
   A second button, **"Try my luck"**, opens the **wheel of fortune** (V03b),
   which picks a buddy at random; the result title reads "<Buddy> picked you!".
   The wheel never lands on the current buddy or on the previous spin's
   result. The A / B2 / B3 picker trials are gone.
4. **Daily Test card = one fixed skeleton for loading / waiting / done**
   (X05): 350 × 256, rows 28 · 100 · 52 with 20 gaps and 18 padding. Finishing
   the test changes colours and slot contents only, never size or alignment.
5. **Daily Test gets per-question feedback**: "Check" grades each answer on
   the device against the set's own answer key (no extra API call, no wait).
   Practice keeps its batched AI evaluation at the end of the session.
6. **Onboarding "Getting ready" step** (V05b): a 0 → 100 % bar whose three
   stops are real work: name + buddy saved (33), today's Daily Test downloaded
   (66), this month's mountain opened (100). The bar never passes a stop
   before that work has finished; in-between values are smoothing only.
7. **Paywall is one scrolling page**: first view has no price boxes (13) →
   plans as a vertical list of rectangles, yearly preselected (13a) → Free vs
   Premium table + trial timeline (13c). The orange trial CTA and the
   price/renewal line stay pinned at the bottom on every part of the page.
   Plans are never square boxes side by side. Tapping X opens one pop-up per
   session with a sad companion (13b) — no discount, no campaign.
8. **The rest scene** (V24) replaces the Home content only once every daily
   right is used (Daily Test done and the practice allowance used: the free
   ticket, or 5/5 Premium sessions). There is no time-of-day variant.
9. **Practice length keeps the existing slider** (3 / 5 / 10), restyled (R02).
10. **Out of this run, separate task later:** home-screen widgets (W01) and the
    daily reminder notification (N01, N02, N03, and the reminder switch/time
    on V24). Boards are included for reference only.
11. **First-wave practice topics** (Conditionals, Passive Voice, Prepositions,
    Relative Clauses, Comparatives & Superlatives): app and proxy code are
    written in this run but stay **switched off** (a constant / config flag,
    default off). No proxy deploy, no paid measurement, no topic visible to
    users. They ship only after the question-quality check and the owner's
    review.
12. The goal choice (V05) is stored only; it does not change content. Copy must
    not promise personalised questions.
13. No new packages, no new analytics events, no new data collected.
14. **Goal options: four** (V05): Exam prep, Work, School & university (new,
    stored as `school`; user property `learning_goal` gains the value
    `school`), Everyday English. Still stored only; it changes no content.
15. **Free users' rest scene leads to Premium** (V24f, flow V24s): the same
    camp, but the sheet shows the user's own weak spot of the day, a strip of
    1 used + 4 locked tickets and one action, "Wake Fox up · 7 days free",
    which wakes the companion and opens the contextual paywall (V13r). After a
    trial starts, PW05r sends the user straight into that weak spot's practice.
    The paywall never opens by itself. Premium users keep the plain V24.
    Copy never promises faster climbing (steps come only from the Daily Test).
16. **Getting ready lasts at least 4 s** (V05b): each stop takes at least
    1.2 s, then 0.6 s of celebration; the bar still never passes a stop before
    its work has finished.
17. **Paywall order: first view → comparison → plans** (V13 → V13c → V13a).
    Value before price. The hint on the first view says "Compare plans". The
    full price line under the pinned button ("7 days free, then <price> per
    year, auto-renews unless cancelled.") stays on the first view and
    everywhere on the page, and no price on the first view is bigger than it
    (Guideline 3.1.2(c); 1.0.0 was rejected over price prominence).
18. **The name screen comes alive** (V04, V04s): the companion asks, listens
    while the user types, and greets them by name when they pause. Two new
    strings, translated into all 8 interface languages.
19. **Dark mode is fixed in this round** (SY03 rules): contrast, navy text on
    dark, the right/wrong chips. A theme-level pass, not per-screen paint.
20. **The expression kit is used everywhere** (§3.5): every companion shows
    its mood's prop; wrong answers use `oops`.
21. **Splash slower on first launch** (V01): about 2.2 s; later launches stay
    short.

## 2. Scope

In scope: every board in §5 except those marked **OUT**.

OUT (reference only): W01-Widgets, N01-SoftAsk, N02-LockScreen,
N03-Settings, the reminder switch + time on V24.

Storyboards (V12b, R06s-B1, R06s-D) are not screens; they explain motion of
V12 and the picker/wheel.

## 3. Global system

### 3.1 Colours

The boards use this palette. Keep the app's existing theme values where they
already exist (page background, card surface, border, text); add the rest as
named tokens (a `ThemeExtension`), never as literals in widgets.

| Name | Hex | Name | Hex |
|---|---|---|---|
| bg (page) | #F6F1E7 → keep app's #F3EFE6 | card | #FFFDF8 → keep app's card surface |
| line (border) | #E8DFCF → keep app's border | shadow (bottom "lip") | #E3D8C5 |
| text | #1B1B1F | muted | #55555E |
| orange | #FF7A1A | orangeDeep | #C95A08 |
| onOrange | #241200 | cream | #FFF1E2 |
| navy | #0D3B8F | navyDeep | #06245C |
| sky | #DCE6FB | onSky | #0A2E70 |
| green | #1F9D63 | greenDeep | #13734A |
| greenSoft | #DDF3E7 | red | #B83232 |
| redSoft | #FDE6E3 | gold | #FFC23C |
| goldDeep | #8A5C00 | goldSoft | #FFF1C7 |

Wheel slice colours, in hero order: #FF7A1A, #0D3B8F, #FFC23C, #3FA36B,
#4F8FE8, #E85D75, #8B5CF6, #C98A4B, #E2483D.

Dark theme (SY03 shows the direction): page #15141A, cards #211F27, text
#F2EEE8, muted #A9A6B2, the mountain uses the theme's `background_dark`;
orange and navy accents unchanged. Every new component takes its colours from
tokens, so dark mode comes from the theme, not from per-screen work.

### 3.2 Type and shape

- Nunito Sans (already bundled). Headings 900, buttons 900, body 400–800 as on
  the boards; titles use slight negative letter-spacing (−0.6 to −0.8 px).
- Cards: radius 26–28, 2 px border, a solid bottom "lip" shadow of 4–6 px
  (`0 Npx 0 shadow`), no blur. Chips: fully rounded.
- Primary button: height 56 (52 inside cards), radius 18, 5 px bottom lip in
  the deep tone; on press it moves down 4 px and the lip shrinks
  (PressableButton). Optional shine sweep (3 s loop) on the main CTA of a
  screen only. The shine is a diagonal band the full height of the button,
  38 % of its width, skewed −20°, white 0 → 50 % → 0, clipped to the
  button's shape; it travels from −140 % to +320 % of its own width in the
  first 55 % of the loop. Never a small square (v11: the device build drew
  one on V05 and V06). One shared implementation for every shining button.

### 3.3 Motion tokens

- Durations: fast 150 ms · base 250 ms · slow 400 ms · celebrate 800 ms.
- Curves: entrances easeOutCubic · pops easeOutBack · loops easeInOut ·
  sheets/pages spring.
- Reduce Motion (`MediaQuery.disableAnimations`): loops stop, entrances become
  a 150 ms fade, confetti and rays do not run. Loops also stop when off
  screen.
- Implement as `AppMotion` constants; no ad-hoc durations in widgets.
- Pose changes (any mood to another: wave on tap, waking up, the V04 greeting,
  V05b inspect → cheer) cross-fade the two images in 200 ms with a 0.96 → 1
  scale on the new one; never a hard swap (v11: the Profile wave felt
  abrupt). Reduce Motion: a 150 ms fade.

### 3.4 Haptics

`HapticMap` over Flutter's `HapticFeedback`:
- selection → `selectionClick` (choices, slider stops, switches, picker steps)
- light → `lightImpact` (taps, small progress)
- medium → `mediumImpact` (primary buttons, ticket)
- success → medium, then light after 90 ms
- warning → light, then light after 80 ms (wrong answer, errors) — never a hard
  error buzz
- heavy → `heavyImpact` (only the irreversible Reset confirmation)

Rules: at most one haptic when a screen opens; none in loops; follow the
system setting.

### 3.5 Companion system (V00-CompanionSystem, X01, X03)

- One widget: `CompanionView(hero, mood, size)`. Screens pass a mood; the
  widget picks the image, the motion and the prop. Moods: `idle`, `wave`,
  `cheer`, `think`, `inspect`, `sad`, `sleep`, `oops`.
- Image: the pose file (`<hero>_<mood>.webp`) when the mood has one; `idle`
  and `oops` use the base avatar.
- Motion per mood: idle = breathe (scale 1 ↔ 1.04, 3 s); wave = the pose +
  gentle bob; cheer = 2 hops (translateY −14 px, 300 ms easeOut) then breathe,
  with sparkles 0 → 1.1 → 0; think = tilt −6°, 2.4 s loop; inspect = slow
  tilt; sad = droop (±3° and 4 px down, 2.6 s); sleep = scaleY 1 ↔ 1.03, 3 s;
  oops = head shake ±8°, twice, 360 ms + sweat drop falling.
- Props sit at the top right of the head: sparkle (cheer), thought bubble
  (think), cloud (sad), Zzz (sleep), sweat (oops).
- v11: **every companion on every screen shows its board's mood and that
  mood's prop.** A prop is left out only where the board leaves it out (V24f:
  the dream bubble replaces the Zzz) or where it would cover text; each such
  case is listed in PROGRESS.md with its reason. Wrong answers (V09, Q04 /
  Q05 wrong, practice wrong) use `oops`: the head shake and the falling sweat
  drop. Dialogs with a sad companion (V13b, R10, R08 reset) show the cloud.
- Picker order and stage colours: ASSETS.md. Personality chips (user-facing,
  translated): Fox — Curious, Quick learner, Loves a challenge; Panda — Calm,
  Steady, Never gives up; Koala — Relaxed, Thoughtful, Kind; Frog — Cheerful,
  Bouncy, Always ready; Bird — Free spirit, Early riser, Chatty; Giraffe —
  Gentle, Patient, Thinks big; Cat — Clever, Independent, Curious; Sloth — Slow
  and steady, Calm, Focused; Crab — Brave, Tough, Thinks sideways.

### 3.6 Shared components

| Component | Board | Notes |
|---|---|---|
| PressableButton (primary / secondary / text) | all | §3.2 |
| DailyTestCard(state: loading, todo, done) | X05 | fixed 350 × 256 skeleton; §5.2 |
| Ticket(state: free, tearing, used) | X04 | 350 wide = body 266 + stub 84; corner radius 22; two half-circle notches (radius 12) cut out of the shape at the perforation, top and bottom; dashed perforation line; the notches are part of the shape (never circles painted on top) |
| ScoreCapsule | V14 | top right of Home: ring towards the next medal tier around the clay star, points, "N to Bronze", "+9" badge after today's points; tap → Profile month progress |
| StepBar (segmented bar) | many | segments fill one by one with a small jiggle |
| Sheet (bottom) | RV06, PF04, PF03 | spring in from the bottom (450 ms) |
| CompanionDialog | R10, 13b, R08 reset | dim 200 ms, card pops 0.9 → 1 (250 ms) |
| Snackbar | SY02 | one component for all short messages |
| ErrorState | R11 | one pattern for every network/quota/server error |
| Confetti, Rays | many | `widgets/confetti_burst.dart` exists; reuse/extend |
| Switch | N03, V24f, R08 | thumb white in both states (v11: the device build drew it black); track navy when on (green on V24f's reminder row, as on the board), #E3DACB when off; dark mode: thumb stays white |

### 3.7 Localization

- The app ships in 8 locales: en (source), ja, ko, es, pt-BR, tr, ar (RTL), de.
  Every new string goes into all ARB files; translations by AI (owner rule).
- Topic names (Gerund vs. Infinitive, Conditionals, …) stay English in every
  language; feature names are translated (Daily Test → Günlük Test, Review →
  Tekrar, …); the brand names GrammarLens and Premium stay English. Questions,
  hints and AI feedback stay English.
- Arabic: layouts mirror (directional paddings/alignments); the turntable
  and wheel keep their geometry but swipe direction follows the reading
  direction; numbers stay Western digits as today.
- Long translations must not break fixed-size components: text truncates with
  "…" (DailyTestCard) or scales down within the documented limit.

## 4. First-run flow

V01 Splash → V02 Welcome → V03 Choose your buddy (→ V03b wheel, optional) →
V04 Name → V05 Goal → V05b Getting ready → V06 This month's mountain →
Day-0 Daily Test (V07 question, V08 correct / V09 wrong, Q04 / Q05 question
types, R10 leave) → V10 Results → V11 Welcome badge → V12 First step on the
mountain → V13 Paywall (13c, 13a, 13b on close) → Home (V14).
The results come before the badge (v11: the integrated build showed the badge
first).

Later days: V15 (Home, test waiting) → Daily Test → Home (V14, done) → Review
(V16 …) → practice (R01 …) → rest scene when every daily right is used
(V24 for Premium; V24f for free users, which can lead to Premium: V24s → V13r
→ PW05r → practice).

## 5. Screens

Format per screen: what it is and why · behaviour (only where the app's
behaviour changes) · motion · haptics. Board file: `boards/<ID>.html`, render:
`screens/<ID>.webp`.

### 5.0 System boards

**V00-CompanionSystem — companion state machine.** The base of the whole
redesign: one `CompanionView`; screens only state the mood (§3.5).

**V00-MotionSystem — motion and touch system.** `AppMotion` (durations,
curves), `PressableButton`, `HapticMap`, all tied to Reduce Motion (§3.3, §3.4).

**X03-HeroSet — 9 heroes × 6 poses.** Reference sheet of every pose. Override:
§1.2 (retired heroes move to Fox).

**X01-ExpressionKit — pose + props.** The pose carries the emotion, the prop
amplifies it; for "oops" the prop and motion carry it alone.
Motion: cheer translateY −14 px, 2×, 300 ms easeOut + sparkles 0 → 1.1 → 0;
oops rotate ±8°, 2×, 360 ms; think rotate −6°, 2.4 s loop; sad rotate ±3° + 4 px
down, saturation 0.55; sleep scaleY 1 ↔ 1.03, 3 s, brightness 0.82.
Haptics: the screen's own.

**X04-Ticket — the ticket in its three states.** Free: orange, dashed
perforation, two notches; tearing: body turns navy, the stub keeps its own
notch halves and torn (zigzag) edge and falls away; used: body with a torn
right edge and its notch halves, the stub's place is a dashed empty slot of
the same shape showing the next ticket's time. Shadow: under the whole ticket
when free, under the body only when used.
Motion: free → tearing: body colour 250 ms; stub rotates from its top-left
corner and falls (450 ms easeIn) with 4 paper bits; then the "USED" stamp
lands (scale 2.2 → 1, −14°); new day: a stub slides into the empty slot and
the body turns orange (400 ms).
Haptics: stub tears: medium; stamp: light.

**X05-DailyCard — Daily Test card skeleton.** `DailyTestCard(state)`.
Outer 350 × 256 in all states, radius 28, 6 px bottom lip; never shrinks in a
list (fixed height). Rows: header 28 (label "DAILY TEST" + status chip 28 high)
· gap 20 · content 100 (left: title 26/30 one line, subline 14/18 one line,
5-segment bar 140 × 8; right: a 100 × 100 slot) · gap 20 · button 52.
States: loading (skeleton bars, thinking companion, "Getting today's test"
with dots in the button slot); todo (orange, hopping companion, empty bar,
navy "Start today's test" with a pulse ring behind it); done (navy, the score
ring "4/5", the bar in result colours — green correct, orange wrong — orange
"Review answers").
Acceptance: screenshots of V15 and V14 on the same device overlap exactly at
the card's edges, header row, bar and button. A widget test asserts identical
size in all three states (also at the largest supported text scale).
Motion: orange → navy: background 400 ms, size and rows never move; each slot
cross-fades on its own (250 ms): companion → score ring, empty bar → filled
bar, Start → Review answers; ring 0 → 4/5 in 600 ms; segments fill 100 ms
apart; loading → todo: skeleton cross-fades to content in 250 ms, the button
pops in from below.
Haptics: Start: medium; back on Home after finishing: light per filled
segment (max 5).

**X02-Assets** — not included (superseded by ASSETS.md).

### 5.1 Launch and onboarding

**V01-Splash — the icon assembles itself.** The app icon is built from its
parts: the navy square pops in, the cream lens turns into place from the
bottom right, its two lines draw left to right, a glint crosses the glass;
then the wordmark rises and a small lens scans the word.
Motion: square 0.5 → 1.08 → 1, 320 ms easeOutBack; lens from bottom right with
rotation + scale, 280 ms delay, 360 ms; lines scaleX 0 → 1, 160 ms, 120 ms
apart; glint 300 ms; wordmark 12 px up + fade, 250 ms; the small lens scans
the word in 900 ms. First launch about 2.2 s (v11: 1.4 s felt rushed on the
device); later launches only square + wordmark (≤ 800 ms), because daily users
open the app every day. Reduce Motion: one fade.
If the icon cannot be reproduced faithfully from shapes, use the icon image
with the same timing and record it in PROGRESS.md.
Haptics: when the square lands: light (once).

**V02-Welcome — the trio waves.** Panda, Fox and Frog in their wave poses at
the bottom.
Motion: heroes float and wave in turn (0.3 s apart), demo loop 3.2 s.
Haptics: Get started: light.

**V03-Meet — choose your buddy (B1 turntable).** All 9 heroes stand on a round
stage; the front one stands on the podium in its wave pose, full size; the
others shrink with depth (back row small, sides medium). Name (40/900),
three personality chips, a speech line ("Hi! Let's reach the summit
together."), dots + "1 / 9". Subtitle under the title: "Swipe to meet all 9 ·
change anytime in Profile". Buttons: primary navy "Climb with <Hero>",
secondary outlined "Try my luck" with a small 9-colour wheel icon.
Behaviour: the selection is saved as the avatar; "Try my luck" opens V03b.
Motion: dragging turns the whole ring (one hero = 40°), the ring follows the
finger and snaps to the nearest hero with a spring on release; size follows
depth; the hero arriving in front drops 8 px onto the podium and waves; the
background changes to the hero's stage colour in 300 ms; the mini wheel in
"Try my luck" turns slowly (6 s); tapping it opens the wheel page from the
bottom (400 ms).
Haptics: every 40°: selection; release: light; Try my luck: light.

**V03b-LuckyWheel — the wheel picks a buddy.** Reached only from "Try my
luck" (manual choosing stays on the turntable). 9 slices in hero order, each
with the hero's base image; a navy rim with 18 bulbs; a gold-ringed white hub;
an orange pointer at the top. Phases: ready (hub shows "?", title "Let a buddy
pick you", one orange button "Spin the wheel"), spinning (blurred, bulbs
blink, button disabled "Spinning…"), landed (title "<Hero> picked you!", the
hero's cheer pose in the hub, its slice glows, confetti, background in the
hero's colour, traits; primary "Climb with <Hero>" in onboarding / "Save
<Hero>" from Profile, secondary "Spin again"). Top left "All buddies" returns
to the turntable with the landed hero in front.
Behaviour: random result, never the current buddy and never the previous
result; nothing is saved until the primary button.
Motion: opening: the wheel rises 0.9 → 1 (400 ms easeOutBack), bulbs light
in sequence; spin 2.4 s, 2–3 full turns, easeOutCubic slowdown, the pointer
ticks at each slice; landing: slice glow, hub hero pops, confetti 1.5 s,
background 300 ms.
Haptics: Spin: medium; each slice passing: selection (thinning out as it
slows); landing: success.

**V04-Name — the buddy gets to know you (v11).** The companion stands large in
the centre (142 pt) inside a warm glow, with a speech bubble above it (tail
pointing down at it); the name field, the hint "A nickname is fine. It stays
on this device." and an n/40 counter below; Continue above the keyboard.
Three states (storyboard V04s):
1. Asks — empty field: wave pose, bubble "Hi! What should I call you?",
   Continue disabled.
2. Listens — while typing: inspect pose (looking at the field through its
   lens), the bubble shows three animated dots.
3. Greets — 700 ms after the last key, if the name is valid: cheer pose, one
   hop, three sparkles, bubble "Nice to meet you, <name>!" (name in orange,
   at most 16 characters shown, then …), a green tick at the right of the
   field.
Typing again returns to Listens; clearing the field returns to Asks.
New strings: "Hi! What should I call you?" and "Nice to meet you, {name}!",
in all 8 interface languages. Same validation as today (max 40).
Motion: opening: companion 12 px up + fade (300 ms), bubble pops (350 ms
easeOutBack); every pose change is the §3.3 cross-fade; the bubble pops on
each change; the glow breathes (3.2 s); Continue goes from disabled to active
in 200 ms. Reduce Motion: no hop, no glow loop.
Haptics: the greeting: light (once per name); Continue: light.

**V04s-NameStoryboard** — the three V04 states side by side.

**V05-Goal — big cards, the buddy reacts.** Four goals as large cards:
Exam prep ("IELTS, TOEFL or another English exam"), Work ("Emails, reports
and professional English"), School & university ("Homework, essays and
academic writing", book icon, purple tile #EFE6FB / #5B3BA8), Everyday English
("Write with confidence every day"). Every place that lists or edits the goal
shows all four. The selected card gets a navy frame
and lifts, the companion pops out of its corner in the cheer pose with a
4-piece confetti burst, and a short reaction line appears inside the card
("Work it is! I'll cheer you on."). Progress bar on top ("2 of 3"), "Skip for
now" text button.
Behaviour: §1.12 — stored only.
Motion: cards enter from below 60 ms apart; selection: card scale 1.03 + slight
tilt that alternates by position: card 1 right (+2°), card 2 left (−2°),
card 3 right, card 4 left (v11: cards 2 and 3 tilted the same way on the
device); companion hops out in 300 ms, confetti; reaction line 150 ms
later; changing the selection slides the previous companion down and out.
Haptics: selection: selection, plus light with the confetti; Continue: medium.

**V05b-GettingReady — a real 0 → 100 % bar.** Centre of the screen: big
percentage (60/900, tabular figures), a thick striped orange bar (26 high)
with a summit flag at its end and three stops (33 / 66 / 100); below, three
rows that tick as the work finishes: "Name and buddy saved", "Today's Daily
Test downloaded", "November's mountain opened" (month name is real). The
companion looks through its magnifier (inspect) and switches to cheer at 100;
its bubble names the goal ("Work English, here we come!"); rays turn, clouds
drift, sparkles glint; at 100 confetti bursts from the flag. A "Your climb"
card at the bottom reflects the choices (name, buddy, goal, this month's
mountain and its step count, "5 questions a day").
Behaviour (§1.6, §1.16): each task owns one third; while a task runs the bar
eases towards its stop and never passes it until the task has finished. Each
stop takes at least 1.2 s, so the screen shows for at least 4 s; if a task
is slower, the bar waits at its stop with the companion thinking; past 8 s
show the R11 error pattern with "Try again". Then V06 after 600 ms.
Motion: stop reached: check pops (easeOutBack), its row goes from faded to
full colour; companion inspect → cheer cross-fade 200 ms + hop; chips enter
120 ms apart; 6 confetti pieces from the flag at 100.
Haptics: each stop: light; 100: success.
v11: on the device the bar did not look like this board. Match it exactly:
the striped orange fill, the three stop circles that turn into green ticks
when passed, the flag at the end of the track, the big percentage above.

**V06-MountainIntro — this month's mountain.** The month's mountain with the
summit flag (v2 assets) on the summit tip; the avatar at the start.
v11: the pole stands on the mountain's highest point, not where the trail
ends (the device build put it at the trail's end). Each month's art gets its
own apex point, measured from the image, in light and dark.
Motion: mountain 0.9 → 1 scale, 600 ms easeOutCubic; pole pops, pennant
waves from its left edge (1.6 s, ±6°); the avatar hops twice at the start;
bottom panel slides up 24 px (300 ms).
Haptics: CTA: medium.

### 5.2 Home and the mountain

**V15-HomeNextDay — test waiting (orange card).** DailyTestCard `todo`, then
the mountain card with the next step glowing ("Step 2 is one test away!").
The score capsule shows no "+N" badge yet today.
Motion: pulse ring behind Start (1.8 s loop); companion hops in the card
(0.8 s); next step on the mountain: gold ring pulse.
Haptics: Start: medium.

**V14-Home — test done (navy card).** DailyTestCard `done`, mountain card
("Step 2 opens tomorrow"), the free ticket (compact, "Use it on: <weak
spot>"), the Premium topic showcase. Score capsule top right with today's
"+N".
Motion: as X05, plus capsule "+9" pops and its ring fills towards Bronze
(600 ms); ticket glint every 3.4 s; topic cards float (3.4 s, staggered).
Haptics: X05; card and ticket taps: light.

**H03-HomeLoading — today's test loading.** DailyTestCard `loading`; the
mountain card is a skeleton too. The shared set usually arrives within 1 s.
Motion: skeleton shimmer 1.4 s; companion thinks (2.4 s); set arrives:
cross-fade 250 ms, nothing jumps; past 8 s: R11 pattern.
Haptics: none.

**H04-HomePremium — Premium Home.** No ticket and no locks: a "Practice" card
with "Sessions today 2/5" (segments), unlocked topic tiles and "Practice your
weak spot". DailyTestCard and mountain as on the free Home.
Motion: a finished session fills its segment navy + small jiggle; topic tiles
float.
Haptics: topic tile: light; segment filling: light.

**V12-Climb — first step on the mountain (camera).** After the first Daily
Test: wide shot → zoom in → the avatar walks to step 1 → zoom out. The image
always covers the screen (cover framing): no empty band at the top or bottom
at any moment; the wide shot fits the screen height and crops the sides.
Motion: one camera transform: wide → 2.2× close (1 s easeInOut) → walk 2 s →
wide (1 s); the walk follows the trail path (PathMetric) in 0.45 s hop steps;
the trail paints 0 → 100 % in sync; "Step 1 of 30" pops on arrival; the
bubble and Continue appear when the camera has opened back up.
v11: the bubble ("First step done! 29 to the summit.") opens right above the
companion, its tail pointing at it, not at the top of the screen. Its place
follows the companion's position on screen: 12 pt above the companion's head,
at least 16 pt from the screen edges, the tail under the companion's centre;
if there is no room above, it opens below with the tail pointing up. "Step 1
of 30" stays at the top. Later days on
the Home card: no zoom, only the walk + paint (1.2 s).
Haptics: arrival: light; "Step 1 of 30": success.

**V12b-ClimbStoryboard** — the three key frames of V12 (wide, close, wide).

**V24-DayComplete — rest scene (Premium).** Shown only per §1.8, to Premium
users once 5/5 sessions are used. Free users get V24f instead. The camp at the
companion's own step: tent behind, campfire in front (logs image; the flame is
drawn on top of the logs, its base in the middle of the pile), warm ground
light, rising sparks, the companion asleep (sleep pose + Zzz), "See you
tomorrow, <name>" and a countdown to the next Daily Test (local midnight).
OUT: the reminder switch and time on this board (§1.10) — leave them out.
Motion: two flame layers flicker in opposite phase (0.5 s and 0.38 s); sparks
rise in 1.4 s; ground light breathes (1.6 s); Zzz 2.4 s; the countdown
updates every minute.
Haptics: none.

**V24f-RestFree — rest scene for free users, bridging to Premium.** Same
camp, with three changes:
1. No "See you tomorrow" chip and no "Zzz": the sleeping companion has a
   dream bubble instead ("FOX IS DREAMING OF…" + today's weak spot, three
   small cloud dots from the head). No weak spot today → no dream bubble.
2. The sheet header: moon, "All done for today", two small done ticks
   (Daily Test 4/5, Free ticket used) and, right-aligned, the countdown to the
   next free Daily Test.
3. The Premium card (navy → #2A1E5C gradient, thin gold border, slow glint):
   "PREMIUM" chip + "Not sleepy yet?", title "Keep practising today", a strip
   of five mini tickets (1 used: dashed, grey, "USED"; 4 locked: orange with a
   lock), "Free: 1 ticket a day · Premium: 5 a day", "Practise <weak spot> now,
   with AI feedback on every answer." (no weak spot: "Pick any of the 5 topics
   …" with the real topic count) and the orange button "Wake Fox up · 7 days
   free" (the user's own companion name).
Behaviour: free users only; the card is part of the page, never a modal; the
paywall opens only from the button, with paywall source `rest_scene` on the
existing `paywall_viewed` event. The board's "Remind me tomorrow" row belongs
to the separate notifications task: leave it out on this branch.
Layout (v11, the device build differed): the scene is full-bleed from the top
of the screen (behind the status bar) down to the sheet; the navy sheet is
attached to it with rounded top corners, not a separate card with a gap; the
camp (tent, fire, companion) sits at the board's scale and is always fully
visible above the sheet with at least 12 pt to spare. When the sheet needs
room (so that "Wake …" stays above the nav bar), the scene is cropped from
the TOP; the image is never scaled up. Dream bubble top left, score capsule
top right, as on the board.
Motion: dream dots appear one by one (200 ms apart), the bubble floats
(3.2 s); the Premium card slides up 300 ms after the scene; locked tickets pop
60 ms apart; glint every 3.6 s.
Haptics: none on open (the screen's one haptic rule); button: medium.

**V24s-RestToPremium — the flow (storyboard).** 24f → tap "Wake Fox up" →
the card glows, the fire grows (300 ms), the companion cross-fades sleep →
wave (200 ms) and hops, the Zzz/dream fades, a bubble says "I'm awake! One
more round?" → 600 ms later V13r rises from the bottom (450 ms spring) →
trial starts → PW05r → that weak spot's practice (V18). Closing V13r (X):
V13b once per session, then back to 24f and the companion falls asleep again
(400 ms).
Haptics: Wake Fox up: medium; the wake-up hop: light.

**R04-MonthCard — month recap.** The finished month's mountain fills the card
edge to edge (no blurred side fill); the trail with its gold dots; steps,
points and "to Gold"; then a points bar that fills step by step with the
existing thresholds: up to the Bronze line (the line glows, a bronze medal
appears top left, the bar jiggles), then to Silver (the medal becomes silver,
jiggle), then stops at the month's points and jiggles; the next line (Gold)
stays faded. Thresholds come from `MonthlyMedalRules`, not from the board.
CTA "See my new mountain" → R04b.
Motion: bar 0 → bronze → silver → points, 250 ms pause + jiggle (±3 px,
±1.2°) at each stop; a threshold line glows 1.5× when passed; medal swaps
with a pop; trail dots light 60 ms apart.
Haptics: each stop: light; reaching Silver (or the highest tier reached):
success.

**R04b-NewMountain — a new month's mountain opens.** The new mountain rises
into view and stays visible; flag pops; the companion drops onto the start.
Motion: mountain rises 40 px + fade (900 ms); flag pops 400 ms later;
companion drops to the start and hops twice.
Haptics: companion lands: light.

### 5.3 Daily Test — question screens

**V07-Question — per-question "Check".** §1.5. Hint slider as in the app
today. The companion nods while the user types and says "Looks good! Tap
Check." once an answer is entered. The points chip at the top uses the clay
star.
Behaviour: Check grades on the device with the existing matching rules
(`utils/answer_matching.dart`, accepted answers, partial multi-blank rules);
then V08 or V09. Points shown during the test are display-only and must equal
what the completion awards (+2 correct, +1 wrong, existing rules); when and
how points are persisted does not change.
Motion: nod (1.2 s) while typing; bubble pops (200 ms) on input; the hint
handle nudges every 2.8 s; Check moves down 4 px on press.
Haptics: hint opens: selection; Check: light.

**V08-Correct — the buddy cheers, +2 flies.** Sheet springs up, check pops,
a "+2" star flies into the points chip, the question's progress segment turns
green, the companion hops (cheer). The explanation is the set's own sentence;
if a question has none, show only the correct answer.
Motion: sheet spring (450 ms); check pop 500 ms; star flies up into the chip
(600 ms), chip count rises; segment turns green + jiggle; companion 2 hops.
Haptics: success.

**V09-Wrong — "Oops! So close."** The companion shakes its head with a sweat
drop (oops, expression kit). The "Almost!" sheet shows the correct answer and
why; "Saved to your weak spots" flies to Review. A wrong answer also earns +1.
Motion: answer box shakes ±6 px (300 ms); sheet spring; companion shakes 2× +
sweat drop; a book icon flies to the Review tab in the nav bar (500 ms).
Haptics: warning.

**Q04-MultiBlank — several blanks.** Each blank's colour matches its answer
box (orange 1, navy 2); the "—" button marks a box as "no article". Check per
question; results per blank (the 1.4.0 partial rule).
Motion: tapping a box makes its blank in the sentence "breathe" once (scale
1.06, 200 ms); "—" fills the box with its colour (150 ms); after Check boxes
turn green/orange one by one (120 ms apart).
Haptics: "—": selection; result: success if all correct, light ×2 if
partial.

**Q05-ErrorCorrection — find the mistake (last question, keyboard open).**
The wrong word is NOT marked in the app (the squiggle on the board is only a
reading aid). The word the user changed is highlighted blue in the answer box
(the 1.4.0 word difference). Last question: the button reads "Finish".
Motion: the card moves up with the keyboard (250 ms); the changed word's blue
background appears in 150 ms while typing; Finish is full width and moves
down 4 px on press.
Haptics: Finish: medium.

**R10-Leave — leave the test? (sad buddy).** A companion card instead of the
system dialog; sad pose; "Keep going" dominant, "Leave" as red text. The same
component is used to leave a practice session.
Motion: background dims in 200 ms; card pops 0.9 → 1 (250 ms); companion
droops (2.6 s); Leave: the card slides down and closes.
Haptics: card opens: warning; Leave: medium.

### 5.4 Results and rewards

**V10-Results — ring fills step by step.** Companion in cheer; the score ring
fills one question at a time with a jiggle per step; the strip below fills
question by question (wrong ones orange); "+9" counts up; answer rows enter.
Motion: one ring step per question, 280 ms each, ±3° jiggle at the end of a
step; strip in the same rhythm; points count up in 600 ms; answer rows from
below 40 ms apart.
Haptics: each correct step: light; wrong step: none; last step: success.

**V11-Badge — the Welcome badge.** The companion in cheer holds its arms up as
if lifting the badge above its head; rays turn; confetti.
Shown after V10 and before V12 (§4).
Motion: badge pops (900 ms) + glint (2.6 s); companion hops twice, then
breathes; confetti 2.5 s.
Haptics: badge lands: success.

**R05-Medal — monthly medal, the moment a threshold is passed.** Opens right
after the Daily Test results when a tier is reached: the medal above the
companion's head (cheer), tier-coloured rays, the next threshold.
Motion: medal pops (900 ms) and floats (3 s); rays one turn per 40 s;
confetti 2.5 s.
Haptics: medal lands: success.

### 5.5 Review and weak spots

**V16-Review — free ticket.** The shared Ticket component (identical on Home,
Review and the weak spot detail). Weak spot cards show the mistake inline and
start practice directly.
Motion: ticket glint every 3.4 s; weak spot card moves down 2 px on press.
Haptics: "Practice with my ticket": medium (starts V16b).

**V16b-TicketTear — using the ticket.** The same ticket: body turns navy, the
stub tears off along its zigzag edge and falls, "USED" stamp lands on the
right of the body. Sizes identical to the free and used states.
Motion: body orange → navy 250 ms; stub rotates from its top-left corner and
falls (450 ms easeIn) with 4 paper bits; stamp 2.2 → 1, −14°, 250 ms after the
stub falls; about 700 ms in total, then practice starts.
Haptics: stub tears: medium; stamp: light.

**V22-ReviewUsed — used ticket.** The free ticket with its stub gone: same
body size, torn right edge, notch halves in place; the stub's place is a
dashed empty slot showing when the next ticket comes (clock + time); the stamp
in its own column inside the body.
Motion: stamp pops once on entry; the slot's time updates every minute; at
the reset (local midnight) a new stub slides into the slot and the body turns
orange (400 ms).
Haptics: none.

**RV05-ReviewEmpty — no weak spots yet.** Empty state as a reward: the
companion cheers; the ticket is visible but "waiting for your first weak
spot"; one action: go to the Daily Test.
Motion: companion hops twice, then breathes; the empty-state text fades in
after 150 ms.
Haptics: CTA: light.

**RV06-ReviewSort — sort sheet.** Two options with big touch targets; the
selected one is a navy card; the list re-sorts behind the sheet.
Motion: sheet from the bottom 450 ms easeOutCubic; on change the list
re-orders (animated, 250 ms).
Haptics: selection.

**R03-WeakSpot — weak spot detail.** The mistake inline (wrong struck
through, correct in green), a mastery strip 0/3, the companion's one-line
rule, practice through the shared Ticket. Premium: "Practice this" instead of
the ticket.
Motion: mastery strip fills its done segments one by one on entry; ticket
glint.
Haptics: ticket: medium → V16b.

**R12-ReviewPremium — Premium Review.** No ticket: a navy "Suggested focus"
card (the most repeated weak spot) and a mastery strip on each weak spot.
Motion: focus card glint every 3.6 s; strips fill step by step on entry.
Haptics: card: light.

### 5.6 Practice (AI, Premium value)

**R01-Topics — Topic Practice list (Premium).** Coloured topic cards, each
with a 3-part mastery strip; the user's weak spot topic as a full-width
"Picked for you" card. A free user tapping a topic gets the paywall.
Behaviour: the list comes from the app's topic data; first-wave topics stay
hidden (§1.11).
Motion: cards float (3.6 s, staggered); press moves 2 px down, then the
length step.
Haptics: card: light.

**R02-Length — number of questions (slider kept).** The existing slider
mechanics (3 / 5 / 10 stops, drag) in the new style: orange knob, dots at the
stops, a ring on top and "Standard · about 4 minutes". Ring and button text
update live while dragging. Free users never see this step.
Motion: knob snaps to stops (spring, 200 ms); ring fills to the value in
250 ms, the number rolls; button text cross-fades.
Haptics: each stop: selection; Start: medium.

**V17-Consent — AI consent.** Same content as today (all of it stays visible
for Guideline 5.1.2(i)); only the structure changes: readable sections, a
clear consent switch. Once, before the first practice.
Motion: sections appear 40 ms apart; Allow moves down 4 px on press.
Haptics: Allow: medium; Not now: none.

**V18-Preparing — questions being prepared.** Companion thinks; question card
skeletons shimmer; topic hint cards rotate. The skeleton cards and the hint
card have the same width (v11: the skeletons were narrower on the device).
Topic practice and weak-spot practice share this screen.
Motion: shimmer 1.4 s; companion tilt (2.4 s); hint cards slide every 3 s;
questions arrive: skeleton → card in 250 ms.
Haptics: questions ready: light.

**V19-PracticeQuestion — batched AI evaluation.** A line under the card says
up front that answers are evaluated together at the end. Hint slider as
today.
Motion: Next: the next card slides in from the right (280 ms); hint slider
as today.
Haptics: Next: light; hint opens: selection.

**V20-Reviewing — AI evaluation (loading).** The companion inspects through
its magnifier; a scan window with the clay lens sweeps over the answer
cards; a checklist ticks; an indeterminate bar. This is the wait between
"Submit" and the results.
Motion: scan window sweeps over the cards (3.2 s); checklist items tick 0.8 s
apart; indeterminate bar (1.6 s loop); when the result arrives the window
stops on the last card and the page moves to the results.
Haptics: each tick: light; result ready: success.

**V21-PracticeResults — mastery step by step.** First the progress on the
weak spot (e.g. 2/3, segments fill one by one), then the AI feedback with
inline corrections. Companion cheers.
Motion: strip 280 ms per segment + jiggle; feedback cards from below 60 ms
apart.
Haptics: each filled segment: light; mastery complete (3/3): success.

**P08-DailyLimit — practice limit reached.** Not a red warning but the close
of a good day: the companion sleeps; the counter (Premium 5/5, free 1/1) is
full; one sentence says when it opens again. Free users also get "See
Premium".
Motion: sheet from the bottom 450 ms; counter segments fill one by one;
companion breathes slowly (3 s).
Haptics: sheet opens: light.

**First-wave topics (no board).** §1.11: add Conditionals, Passive Voice,
Prepositions, Relative Clauses, Comparatives & Superlatives to the app's topic
data (with hint cards like the existing topics) and to the proxy's topic
handling, behind a flag that is off. Tests cover both flag states. Do not
deploy the proxy and do not run any generation or measurement script.

### 5.7 Paywall (one scrolling page, §1.7)

**V13-Paywall — first view.** No price boxes. Three companions (Panda, Fox,
Frog) on top, the headline built on the user's own mistake ("Turn today's
mistake into progress, <name>."), the weak spot card, three benefit rows,
"Compare plans" with an arrow (v11; was "See plans"). Pinned bottom: orange "Start my 7-day free trial"
(shine + pulse) and the full price/renewal line ("7 days free, then <price>
per year, auto-renews unless cancelled."), Restore · Terms · Privacy. The
price line and the links stay visible on first view (App Review).
Behaviour: copy that counts topics must use the real number of available
topics.
Motion: companions float, the middle one hops; "Compare plans" arrow nudges
every 1.8 s; CTA shine + pulse.
Haptics: CTA: medium; X: light (→ 13b once per session).

**V13a-PaywallPlans — plans at the end of the page (v11).** After the
comparison (13c): "Choose your plan", a vertical list of rectangular plans
(yearly preselected), then the trial timeline. The pinned CTA's text follows
the selected plan. In each plan row the billed amount is the largest price;
the monthly equivalent stays small.
Motion: plans enter from below 60 ms apart as they scroll in; selection: frame
turns navy in 150 ms, radio pops.
Haptics: plan selection: selection.

**V13c-PaywallCompare — Free vs Premium right after the first view (v11).**
Part of the same page (13 → 13c → 13a): "Free vs Premium" with the cheering
companion, the comparison table, the "Cancel anytime…" note, then a "Choose
your plan" hint with an arrow. The trial timeline moves to 13a with the
plans. The selected plan (yearly by default) drives the pinned CTA before the
plans are on screen.
Motion: table rows appear 40 ms apart when visible; the Premium column fills
top to bottom.
Haptics: none (CTA: medium).

**V13b-ExitReminder — exit pop-up.** Opens when X is tapped, once per
session. Sad companion over the dimmed paywall ("Leaving already, <name>?"),
no discount; primary "Start my free trial", secondary "Continue with free"
(closes the paywall).
Motion: background dims in 200 ms; card pops (500 ms).
Haptics: opens: light; Start: medium.

**V13r-PaywallRest — the paywall opened from the rest scene.** The same
paywall page (13 → 13a → 13c, same pinned CTA, price line and links); only the
top changes: an evening camp strip (the month's dark background, the awake
companion waving, the campfire), the "GRAMMARLENS PREMIUM" chip, title
"<Hero> is wide awake, <name>.", subline "Keep practising today. Your free
ticket is used, Premium adds 4 more.", a "PRACTISE IT NOW" card with today's
weak spot ("saved today → right after your trial starts"), then benefits in
this order: "5 practice sessions a day" (Today: 4 more. Every day after: 5.),
"AI feedback on every answer", "All N grammar topics".
Motion: continues from V24s (scene stays on top, page rises); companion
waves, fire flickers; otherwise as V13.
Haptics: CTA: medium; X: light (→ 13b).

**PW05-PremiumOn — purchase done.** One celebration screen after a purchase or
trial start: the companion cheers, the three unlocked things are listed, the
trial's end date is written plainly. Pending and failed purchases keep the
snackbar messages (SY02).
Motion: rays turn, companion hops twice; benefits slide in from the side
120 ms apart; confetti 2.5 s.
Haptics: screen opens: success.

### 5.8 Profile and settings

**PW05r-PremiumOnRest — trial started from the rest scene.** PW05 with
"<Hero> is ready. Let's go!", the third perk "4 more sessions today, 5 every
day", and the button "Practise <weak spot>" that opens that weak spot's
practice directly (V18), not Home. No weak spot: "Pick a topic" → R01.
Motion and haptics: PW05.

**V23-Profile — profile.** The companion on a coloured stage with a "Change"
button (→ R06); a ribbon under it with the name and "Climbing with <Hero> ·
since <month year>" and a pencil (→ PF04); three stat tiles (points, step,
weak spots); "Medal collection" on the thick shelf (medal_shelf_v2) with 3
medals standing on its top surface (newest first; a locked slot for the
current month) and "See all" (→ PF02); the month progress card with the
thresholds; then the existing settings rows.
Ribbon size (v11: it looked thick on the device): its width follows the
screen: tails included, screen width − 60 pt (330 at 390, 368 at 428). The
name and "Climbing with <Hero> · since <month year>" each stay on one line;
if a line does not fit, its text first shrinks (to 85 % at most), then ends
with …. Height 62 pt at the default text size.
Motion: ribbon settles from 12 px below (300 ms easeOutBack) when the stage
opens; companion breathes and waves when tapped (the wave is the §3.3 pose
cross-fade); medals settle on the shelf 80 ms apart.
Haptics: pencil: light (→ PF04); See all: light (→ PF02).

**PF02-Medals — all medals over a blurred profile.** A layer over the profile,
not a new page: the profile blurs; every medal side by side, newest first,
with year headers; earned medals glow, the current month is grey. The shelf
still shows 3; this layer opens with "See all" and closes with X or a swipe
down. Medal images for future themes do not exist yet — use the existing
medal assets.
Motion: background blur 0 → 10 in 250 ms, panel pops 0.92 → 1; medals fly
from the shelf into the panel (Hero transition, 350 ms), then settle 40 ms
apart; closing reverses.
Haptics: opens: light; tapping a medal: light (→ PF03).

**PF03-MedalDetail — medal detail.** Opens from the bottom when a medal in the
layer is tapped: the medal large and glowing, tier + month + theme, steps /
points / what is left to the next tier.
Motion: the medal grows from its place in the layer into the sheet (Hero,
350 ms); numbers count up.
Haptics: opens: light.

**PF04-EditName — edit name.** Tapping the pencil opens a sheet above the
keyboard; the companion asks the question. Saving shows the "Name saved"
snackbar (SY02).
Motion: the sheet rises with the keyboard (250 ms); on save the sheet closes
and the name on the profile cross-fades (150 ms).
Haptics: Save: light.

**R06-AvatarChange — change your buddy.** The V03 turntable opened from
Profile: title "Change your buddy", subtitle "Your progress stays the same",
primary "Save <Hero>", secondary "Try my luck" (→ V03b with "Save <Hero>").
Progress never changes. Motion and haptics: V03.

**R07-Language — interface language.** Each language in its own name; the
selected one is a navy card; a note on top says questions stay in English.
Motion: selection frame turns navy in 150 ms, check pops; the interface
switches with a 200 ms fade.
Haptics: selection.

**R08-Data — Data & AI feedback.** Three clear cards: AI consent (switch),
what stays on the device, reset progress (red, with the CompanionDialog
confirmation). Texts as in the app today.
Motion: switch knob slides in 200 ms; reset uses the R10 pattern.
Haptics: switch: selection; reset confirmation: heavy.

**R09-Credits — credits.** Attribution text unchanged (CC BY 4.0
requirement). Three companions greet on top; one card, two links.
Motion: companions float, the middle one waves.
Haptics: none.

**N03-Settings — OUT** (§1.10).

### 5.9 Picker storyboards

**R06s-B1-Turntable** — three frames of the turntable: resting, turning
(halfway: the front hero shrinks sideways while the next grows to the front;
nobody disappears), new choice (Panda in front; Fox back right). Motion and
haptics: V03.

**R06s-D-Wheel** — four frames of the "Try my luck" flow: tap → ready →
spinning → landed. Motion and haptics: V03b.

### 5.10 Widgets and notifications — OUT (§1.10)

W01-Widgets, N01-SoftAsk, N02-LockScreen: reference only for the main run;
built by the widgets task (`TASK-widgets.md`). v11 fixes on these screens:
- N01 opens as soon as the first rest scene (V24 / V24f) is on screen, also
  when the user comes back to Home from Review after using the free ticket
  (the device build opened it only after switching tabs again).
- N03: the switch thumbs are white (§3.6).

### 5.11 System states and theme

**R11-Offline — no connection / failed to load.** One language for every
network error: sad companion, a calm explanation, "Try again". Quota and
server errors use the same pattern with their own copy.
Motion: companion droops (2.6 s); Try again shows dots inside the button
while retrying and returns when the result comes.
Haptics: error opens: warning; successful retry: light.

**SY02-Snackbar — one snackbar.** Dark capsule, status icon on the left (green
check / orange warning / red error), at most one action; sits right above the
nav bar; disappears after 3 s.
Motion: slides up from 120 % → 0 in 250 ms easeOutCubic, waits 3 s, slides
down; swiping down dismisses it at once.
Haptics: success: light; error: warning.

**SY03-DarkHome — dark theme direction.** The same components in dark: page
#15141A, cards #211F27, the mountain's dark background; orange unchanged.
Every screen's dark version comes from theme tokens; nothing is drawn per
screen.
v11 rules (the owner found dark mode hard to read on the device):
- Text contrast at least 4.5:1 against its own background; large text
  (≥ 18 pt, or ≥ 14 pt bold) and icons at least 3:1.
- Navy is a light-mode colour. On dark surfaces navy text, links, icons and
  outlines use a light blue counterpart (a token, e.g. `onSurfaceAccent`,
  around #9DB8FF; check the ratio); navy stays as a fill only where white
  text sits on it (buttons, chips, the ribbon, the Premium card).
- Right / wrong (V08, V09, Q04, Q05, R03, results rows): dark tints, not light
  pastel fills: success fill around #173A2A with text/icon around #7FD6A6;
  error fill around #42201F with text/icon around #FF9C92; amber / orange
  the same way. Check every pair against the ratio.
- Soft fills (sky, cream, goldSoft, greenSoft, redSoft) get dark tints of the
  same hue; no light fill keeps dark text on a dark page.
- Card lips and borders: a lighter line (#2E2C36 or so) instead of the light
  shadow colour.
- Companion art and mountain art are unchanged (the mountain already has its
  dark background).
- Done when every in-scope board has a dark capture that passes the ratios
  (PROGRESS.md lists the pairs that were changed).
Motion: theme change 300 ms colour cross-fade; otherwise as in light.
Haptics: as in light.
