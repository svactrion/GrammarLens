# UI polish — progress log (branches `ui-polish` and `ui-polish-widgets`)

Running log of the unattended implementation run of `TASK.md` / `SPEC.md`,
its fix rounds, and the integration with the widgets and reminders
(`INTEGRATE.md`). One section per batch: status, commits, what was verified
and how, decisions, open items. The final summary is below the Integration
section.

## Fix round 5 (owner's third device pass, 2026-11-18)

`FIX5.md`, SPEC v13. On the third pass (iPhone 14 Plus) the owner confirmed
the paywall footer and V24f on one screen, chose a new panel for V24f on
the canvas (the ticket deck), asked for a clearer month progress card, and
found that some paywalls close with a swipe; a simulator capture also
showed round 4's V24 (Premium) with about 200 pt of empty panel. This
round fixes these on `ui-polish-widgets`. **Status: done** (items 1–4,
steps 0, Checks and Docs below; the checks ran after the last code change,
`5427ce8`, the smoke driver; the app's last change is `c7eaf5e`). Not on `main`, not shipped, not checked on a device; the
fourth pass is the first section of `DEVICE-CHECKS.md`.

| Step | Status | Commits |
|---|---|---|
| 0 Start | done | `7fddad1` |
| 1 V24f's panel: the ticket deck | done | `6f7ae07` (with item 2: one file) |
| 2 V24 (Premium) back to its own board | done | `6f7ae07` |
| 3 The month progress card | done | `a9a36c1` |
| 4 The paywall closes only with X | done | `c7eaf5e` |
| Checks | done | `cef8544` (a flaky test, F5-9), `5427ce8` (the smoke walk) |
| Docs | done | this commit |

### 0. Start

`df -h ~`: **16 GiB** free at the start (228 GiB disk); nothing needed
deleting then. On `ui-polish-widgets`, `git pull --ff-only` (up to date);
`FIX5.md`, SPEC v13, the changed V24f board and screen and the new V23p
board and screen committed as "docs: fix round 5 task and SPEC v13"
(`7fddad1`). The end-of-run figure is under "Checks: builds, tests, disk".

### 1. V24f's panel: the ticket deck

**What was asked.** The owner chose a new panel on the canvas: under the
unchanged top half (scene, camp, fire, dream bubble, score capsule), the
title alone, today's free ticket used (small, with the time to the next
one), and the navy Premium card with a deck of four tickets, then the
reminder row; built from the app's real ticket (X04), not new drawings;
the panel fits its content and ends just above the nav bar.

**Before.** Round 4's sheet: a header with two done ticks and the
countdown, a compact Premium card with five 50 × 30 mini tickets (one
used, four locked), the allowance line, "Practise <spot> now…" and Wake;
the sheet never started lower than the board's top (F4-4), so spare room
stayed under the row.

**Fix (`6f7ae07`).**
- `widgets/ticket.dart`: X04's outline (notches, torn edge, stub),
  stamp and slot take a scale (`_Geo`), the ticket itself unchanged. Two
  new widgets from them: **`MiniUsedTicket`** (150 × 50 + a 3 pt lip: the
  navy torn body with a white hairline, the gold USED stamp sized to its
  word, the dashed light slot with a clock, the time to local midnight and
  NEXT; mirrored in Arabic as X04 is) and **`TicketDeck`** (four X04
  tickets 92 pt tall with a 70 pt stub, 7 pt apart diagonally, the back
  ones a shade darker with the stub's sparkle; the front one: "✦ NEXT UP",
  the weak spot on one line, "AI feedback on every answer", "+4 / TODAY"
  on its stub, its glint every 3.4 s; the back tickets settle 60 ms apart,
  the front one last; `gathered` draws them into the front one in 150 ms).
- `widgets/rest_scene.dart`: the night panel is the boards' **#1F1A2E in
  both themes** (`AppColors.restPanel`); V24f's rows, 12 pt apart: the moon
  and "All done for today"; the used ticket with "Today's free ticket is
  used." and, in white, "Not sleepy yet?"; the Premium card (140° navy →
  plum, gold hairline, a dark lip): the gold ✦ PREMIUM tag and "5
  practices a day", the deck, "Wake Fox up · 7 days free" (50 pt); the
  reminder row (44 pt, F4-3). The panel slides up 300 ms after the scene.
  On Wake the deck gathers (150 ms), the companion wakes, then V13r
  rises; the deck spreads again when the paywall closes.
- **The fit (both panels):** the panel's last row ends 8 pt above the nav
  bar; the sheet's top is fitted after layout and the scene fills the rest
  (the board's top is only the first frame's guess). The sheet never rises
  above the camp's room (then the page scrolls: the SE, the largest text).
  The art is never scaled: where the fitted panel would start below the
  art's lower edge (early in the month on tall phones), the camp and the
  art move down together (F5-3).
- Strings: 7 new in the 8 languages (`restTodaysTicketUsed`,
  `restPracticesADay`, `restNextUp`, `restAiFeedback`, `restDeckToday`,
  `restDeckSemantics`, `restDeckAnyTopic`); "Not sleepy yet?" restored with
  its translations; 10 that only round 4's sheet used removed. The weak
  spot's name stays English (§3.7); NEXT UP and TODAY are upper-cased by
  language (`SIRADAKİ`, `BUGÜN`).

**Tests.** `test/home_screen_test.dart` "v13": V24f and V24 at six phones
(390 × 844, 393 × 852, 402 × 874, 428 × 926, 440 × 956 and the SE) × the
default, next and largest text: full-bleed scene, the panel attached, the
camp whole ≥ 12 pt above it, the fire on the companion's ground, **the art
never scaled** (the mountain's box no taller than the art), the dream
bubble under the status bar; from 390 × 844 up at the default and next
text **no scroll extent and the reminder row 8.0 pt above the bar (no
empty band)**; the row reachable everywhere. Steps 20, 26, 30 (the sky
continued, the camp at its board place) and steps 0 and 1 on the tallest
phones (the camp and art moved down); Turkish at 428 × 926, next text.
The V24f content test (USED, the time, NEXT, the two lines, PREMIUM, "5
practices a day", the four tickets 7 pt apart, NEXT UP, the spot, +4,
TODAY, the deck's label, the 50 pt button), no weak spot ("Any of N
topics", the real count), Wake (gathered at 160 ms, awake after, V13r, X → V13b, the deck
spread again). `test/fix5_rest_panel_test.dart` (12): the mini ticket
(size, texts, label, Turkish stamp readable, Arabic mirrored), the deck
(offsets, texts, one line, settle order, gather and back, Reduce Motion,
the glint only with loops, Arabic), the panel colour the same in light and
dark for V24f and V24.

Measured (widget renders, `build/fix5-captures/v24-numbers.md`; sheet top
· gap camp → panel · row above the bar · Wake above the bar · scroll):

| Size | Text | V24f | V24 |
|---|---|---|---|
| 390 × 844 | default | 291 · 29.8 · 8.0 · 79.5 · 0 | 452 · 110.8 · 8.0 · 0 |
| 390 × 844 | next | 287 · 25.8 · 8.0 · 79.5 · 0 | 441 · 99.8 · 8.0 · 0 |
| 393 × 852 | default / next | 299 / 295 · 24.2 / 20.2 · 8.0 · 0 | 460 / 449 · 8.0 · 0 |
| 402 × 874 | default / next | 321 / 317 · 38.2 / 34.2 · 8.0 · 0 | 482 / 471 · 8.0 · 0 |
| 428 × 926 | default / next | 373 / 369 · 91.0 / 87.0 · 8.0 · 0 | 534 / 523 · 8.0 · 0 |
| 440 × 956 | default / next | 403 / 399 · 99.4 / 95.4 · 8.0 · 0 | 564 / 553 · 8.0 · 0 |
| 428 × 926, Turkish | next | 358 · 76.0 · 8.0 · 0 | 523 · 125.4 · 8.0 · 0 |
| 375 × 667 (SE) | default | 215.8 · 12 · scrolls 67.8 | 309 · 12 · 8.0 · 0 |
| 390–402 wide | largest | scrolls 1.9–18.8 | 341–398 · 8.0 · 0 |

### 2. V24 (Premium) back to its own board

**What was wrong.** F4-1 had removed V24's two done tiles and its "Next
Daily Test · step N" card and kept its board's taller frame, so the short
panel left about 200 pt empty under the reminder row.

**Fix (`6f7ae07`, with item 1).** V24's panel is its board again: the moon,
"All done for today" and "Your buddy is resting until tomorrow."; the
**Daily Test** tile ("4/5 · +9 points") and the **Practice** tile ("5/5
sessions"); the card with "NEXT DAILY TEST · STEP N", the month's ten-step
bar (this round of ten in gold) and the countdown; the reminder row. The
four strings V24 used before round 4 (`restBody`, `restPracticeTitle`,
`restTestLine`, `restNextTest`) restored from git with their translations.
The panel fits its content and ends 8 pt above the bar (item 1's fit), so
the scene fills the rest: no empty band at the five sizes (the table
above). This changes F4-1 (F5-2).

**Tests.** The v13 layout tests above (V24 rows); Home's "every daily right
used (Premium)" test (the body line, the tiles' titles and lines, "NEXT
DAILY TEST · STEP 4", the countdown, the step bar); `b5_home_mountain_test`
(the countdown updates every minute in the card).

### 3. The month progress card

**What was wrong (device).** "Bronze 75" under the bar did not say where 75
is on it.

**Fix (`a9a36c1`).** `MonthlyProgressCard` (in
`widgets/monthly_medal_collection.dart`) rebuilt to board V23p: "<Month>
progress" and "<mountain> · N active days" on the left; on the right the
points large with "/ 300" and the distance ("66 to Bronze" in orange,
"Gold reached" in green, the score capsule's own strings). The bar runs
0–300 in four parts split by 4 pt gaps at 75, 150 and 225; unfilled parts
tinted toward bronze, silver, gold and neutral (the board's colours, light
and dark); the orange fill runs through them. Over each gap, the medal's
image (the shelf's, for the running month's mountain) in a ring on a stem:
earned = full colour, a green ring and a tick; not yet = muted (less
saturated, faded) with a grey ring. Names and points under the bar, an
earned or the next medal's name darker. The dot (navy; light blue in dark)
at the points. The fill runs part by part, 200 ms each, the dot with its
front; a passed medal pops and gets its tick; at once under Reduce Motion.
The 10-segment bar and the "Monthly total" line are gone. VoiceOver: the
title, the line, the distance, then the bar as "9 of 300 points; Bronze at
75, Silver at 150, Gold at 225" (2 new strings in the 8 languages; 9 that
only the old card used removed). Every number from `MonthlyMedalRules`.

**Tests.** `test/fix5_progress_card_test.dart` (23): 0, 9, 75, 120, 150,
225, 240 and 300 points in light and dark — "N / 300", the distance and its
colour, each part's fill and tint, each medal's tick, ring colour and
muting, the names' colours, each medal and name over its gap, the dot's
place and colour, the screen-reader label, no "Monthly total"; Small,
Medium and Large text inside the card; the fill part by part (half the
first part at 100 ms, Bronze's tick and pop at 250 ms, the dot at the
fill's front, all in place at the end); Reduce Motion at once; Arabic
(the bar from the right). `monthly_medal_collection_test` "v13" (two
months' numbers from the rules: the gaps at the thresholds, the medals
over them, the fills, the ticks, the dot); `settings_screen_test` and
`debug_sample_collection_test` read the points from "N / 300" now.

### 4. The paywall closes only with X

**Diagnosis first.** A test per entry point, in iOS's behaviour
(`test/support/paywall_close.dart`: a slow and a flung swipe from the left
edge, a drag down from the top, a system back), run before the fix. Every
way the paywall is opened:

| Entry point (source) | Route | Before the fix |
|---|---|---|
| Home's topic cards and weak spot (`home`) | `MaterialPageRoute` | closed by the **edge swipe** |
| After the first climb, onboarding (`day0_after_climb`) | `MaterialPageRoute` | closed by the **edge swipe** |
| Review's used ticket, "See Premium" (`review_quota`) | `MaterialPageRoute` | closed by the **edge swipe** |
| The weak spot's locked row (`weak_spot_quota`) | `MaterialPageRoute` | closed by the **edge swipe** |
| A topic's practice when the free one is used (`practice_launch`) | `MaterialPageRoute` | closed by the **edge swipe** |
| The practice results' offer (`practice_result`) | `MaterialPageRoute` | closed by the **edge swipe** |
| V24f's Wake → V13r (`rest_scene`) | its own `PageRouteBuilder` | no swipe; closed by a **system back** |
| Profile | — | Profile opens no paywall (searched; F5-18) |

Cause: on iOS a `MaterialPageRoute` has the Cupertino edge swipe back, and
the paywall's `PopScope` only *observed* pops (to log `system_back`), so
the swipe and the system back closed it. No route is a sheet or has a
barrier, so a drag down or a tap outside closed none.

**Fix (`c7eaf5e`), in one place:** the paywall's `PopScope` no longer lets
the route pop by itself (`canPop: false`), which also turns off the edge
swipe (Flutter's `popGestureEnabled` is false for a route that would not
pop); the X (V13b first in a session when the store's offer is loaded),
and a purchase's Continue close it through `_dismiss()`, which pops the
route itself. Restore is unchanged (F5-16).

**Tests.** Each entry point's own test now opens the paywall through its
real flow, swipes, drags down and sends a system back (it stays), then
closes with X (`home_screen_test`: a topic card, V13b once then at once;
V13r from Wake; `home_day0_paywall_test`; `review_screen_test`;
`practice_launch_free_tier_test`: a topic and the weak spot's row;
`results_screen_test`). `premium_screen_test`: a system back no longer
closes it nor logs `paywall_dismissed`; the X logs `close_button`.
`test/fix5_paywall_close_test.dart` (14): each source's paywall in its
route type, light and dark, stays after the gestures; X → V13b → closed;
renders it after the attempts.

### Decisions

- **F5-1. "The five sizes".** FIX5 names five sizes without listing them.
  Choice: round 4's phones from 390 × 844 up (390 × 844, 393 × 852,
  402 × 874, 428 × 926, 440 × 956); the SE (375 × 667) is still tested and
  may scroll. Why: FIX5's own rule, "no scroll at 390 × 844 and larger".
- **F5-2. F4-1 and F4-4 change.** F4-1 had V24 drop its tiles and step card
  and keep its board's taller frame; F4-4 kept spare room under the row.
  Now both panels fit their content and end 8 pt above the nav bar
  (round 4's `anchorClearance`), and the scene fills the rest; the boards'
  sheet tops are only the first frame's guess. Why: SPEC V24f v13 and V24
  v13 ("ends just above the nav bar", "no empty band").
- **F5-3. Where the panel would start below the art.** Early in the month
  the camp's step is near the art's bottom; on the tallest phones the
  fitted panel starts lower than the art reaches. Options: (a) hold the
  panel at the art's edge and leave an empty band under the row; (b) scale
  the art; (c) move the camp and the art down together. Choice: (c). Why:
  SPEC V24f v13 ("the art is never scaled; the sheet never starts below the
  art's lower edge") and FIX5 ("no empty band"); the top of the scene then
  shows more sky (the round 4 mirrored sky where needed).
- **F5-4. The night panel's colour.** Round 4 used the theme's night
  gradient (different in light and dark). Choice: the boards' #1F1A2E in
  both themes (`AppColors.restPanel`, also behind the page). Why: SPEC
  V24f v13 ("the night panel (#1F1A2E)") and FIX5 ("the panel is the same
  in both").
- **F5-5. The used ticket and the deck "from X04's shapes and colours".**
  Choice: X04's own paths (notch halves, torn edge, perforation, stub),
  stamp and slot, scaled to the board's sizes (150 × 50; 92 pt tickets
  with a 70 pt stub, 7 pt apart), and X04's colours: the navy body (the
  board's lighter #1A4BB0 is not an app colour) with the board's white
  hairline so it reads on the dark panel; the front ticket X04's flat
  orange (the board drew a gradient); the back ones a shade darker toward
  X04's lip; the board's thin highlight along each deck ticket's top left
  out (not part of X04). The panel's ticket colours are the light theme's
  (the panel is the same in both). Why: FIX5 ("not new drawings").
- **F5-6. The small ticket's stamp takes its word's width.** X04's stamp is
  a fixed 72 × 40 box; made small, "KULLANILDI" would shrink to about 6 pt.
  Choice: the stamp wraps its word at 10.5 pt and shrinks only past the
  body's width. Why: legible in every language; "USED" looks as on the
  board.
- **F5-7. The headers.** V24f: the moon and the title only (the board); the
  countdown moved into the used ticket's slot (the time to the next free
  ticket, local midnight). V24: the title with "Your buddy is resting until
  tomorrow." (its board). Round 4's done ticks are gone from both.
- **F5-8. No weak spot yet.** The board has no such state; the deck's front
  ticket needs a one-line title. Choice: "Any of N topics" (new string,
  the real topic count), the same line under it. Why: rule 5, the
  smallest; round 4 named the topics the same way.
- **F5-9. A flaky test (Checks).** `l10n_layout_test` "pt at 320 pt, Large,
  Profile" failed one run in nine (nothing this round touched it):
  without a hero Profile shows a random one, and with the crab the
  Portuguese ribbon line "Escalando com Caranguejo" needs 84 % at 320 pt,
  past the ribbon's 85 % (then "…", as its rule says). Options: change the
  ribbon's rule (other long names, e.g. the sloth in Turkish, need 73 %),
  or name the hero in the test. Choice: the site names the fox (`cef8544`).
  Why: the ribbon's behaviour is as designed; the test was not
  deterministic.
- **F5-10. Wake's order.** The deck gathers (150 ms), then the companion
  wakes (the hop, "I'm awake!"), then after round 4's 600 ms V13r rises;
  the button takes no tap from the first until the paywall closes; then
  the deck spreads again and the companion sleeps. Why: SPEC V24f v13's
  motion, in order.
- **F5-11. Motion.** V24f's whole panel slides up 24 pt (fading in from
  40 %) 300 ms after the scene; V24's does not (its board names no panel
  motion). The back tickets settle 350 ms each, 60 ms apart, back-most
  first, the front one last. All at once under Reduce Motion.
- **F5-12. Kept from round 4.** The reminder row stays 44 pt (F4-3; the
  board's 40); Wake is the board's 50 pt.
- **F5-13. The card's medals and words.** The medal images are the running
  month's mountain's (`MedalArt.monthly`, the shelf's; the board shows
  Green Slope's on an Ember Peak card). The distance and "Gold reached" are
  the score capsule's strings, so both say the same. The four tints and the
  fill's light end are the board's colours (new constants, light and dark);
  the grey ring is the app's line colour.
- **F5-14. The card's screen reader.** Round 4's card was one long summary
  ending with the monthly total. Choice: the title, the line, the distance
  and the bar's own label ("9 of 300 points; Bronze at 75, Silver at 150,
  Gold at 225", the SPEC's words) as separate items; the points are not
  read twice. Why: the SPEC gives the bar's label; the total line is gone.
- **F5-15. The card's fill.** It runs on the card's first build and when
  the points change; the dot moves with the fill's front; a passed medal
  scales up to 1.18 and back over the next 200 ms as its tick appears.
- **F5-16. Restore.** SPEC: "a purchase or a restore closes it as today".
  Today a restore shows its message on the paywall and the X closes it.
  Choice: unchanged. Why: rule 4.
- **F5-17. V13b.** It still opens only when the store's offer is loaded (it
  states the trial), on the first X of a session, as before.
- **F5-18. "Profile" as an entry point.** FIX5 lists Profile; the app's
  Profile opens no paywall (searched every push of `PremiumScreen`).
  Recorded; nothing to change.
- **F5-19. "The paywall at each entry point after a swipe attempt".** The
  behaviour is tested in each entry point's own flow (item 4); the
  captures render each source's paywall in its route type after the
  gestures (`fix5_paywall_close_test`), and the smoke walk tries the edge
  swipe on the simulator on V13r from Wake.

### Checks: the listed captures against their boards

Light renders in `build/fix5-captures/`, dark in `build/fix5-captures/dark/`
(widget-test renders at a phone's size in the app's font,
`FIX5_CAPTURE=1`), and the smoke walk's simulator screenshots in
`build/fix5-captures/smoke-tr/`. Each was looked at next to its board.

| Board | Light | Dark | Match / what differs |
|---|---|---|---|
| V24f (v13 panel) at 390 × 844, 393 × 852, 402 × 874, 428 × 926, 440 × 956, default and next text | `V24f-<size>-default`, `-next` | same names | match: the title alone, the used ticket with USED, the time and NEXT, the two lines, the Premium card with the tag, "5 practices a day", the deck of four 7 pt apart, NEXT UP, the spot, +4 TODAY, Wake, the row just above the bar; the panel the same in both themes. Differs: the ticket body is the app's navy (the board's is lighter, F5-5), the front ticket flat orange (the board: a gradient), no highlight line on the deck tickets; the panel starts 291 pt down at 390 × 844 (the board: 314) because the app's text is a step larger than the board's and the row is 44 pt (F4-2, F4-3) |
| V24f in Turkish, 428 × 926, next text | `V24f-428x926-next-tr` | same | match: one screen, "KULLANILDI" readable on the small ticket (F5-6), SIRADAKİ, BUGÜN, "Günde 5 pratik" |
| V24f late and early in the month | `V24f-390x844-step20/26/30`, `V24f-440x956-step0`, `V24f-428x926-step1` | — | match: the camp at its board place late in the month (the sky continued), the camp and art moved down early on the tall phones (F5-3); no empty band |
| V24 (its own board again) at the five sizes, default and next | `V24-<size>-default`, `-next` | same names | match: "See you tomorrow, Ada", the bubble and Zzz, the title with its line, the two done tiles, NEXT DAILY TEST · STEP N with the step bar and the countdown, the row just above the bar. Differs: the panel starts 452 pt down at 390 × 844 (the board: 466; larger app text), the scene shows the month's own step |
| V24 in Turkish, 428 × 926 | `V24-428x926-next-tr` | same | match |
| V23p, 0, 9, 75, 120, 150, 225, 240, 300 points | `V23-progress-<points>` | same names | match: the points and "/ 300", the distance in orange / green, four tinted parts with gaps at the thresholds, the medals over them (earned with the green ring and the tick, the rest faded), the names and points, the dot (navy / light blue). Differs: the running month's mountain's medals (the board shows Green Slope's, F5-13) |
| V13 at each entry point after the swipe, the drag down and the system back (home, day0_after_climb, review_quota, weak_spot_quota, practice_launch, practice_result) | `V13-after-swipe-<source>` | same names | match: the paywall still open, the X at the top left, the compact footer |
| V13r from Wake after the gestures | `V13-after-swipe-rest_scene`; the walk's `V13r-after-edge-swipe`, `V13r-after-drag-down` | `V13-after-swipe-rest_scene` | match: still open; X → V13b → the scene |
| Mini ticket, deck (X04 made small) | `X04-mini-used`, `-tr`, `V24f-deck` | — | match X04's used ticket: navy torn body with its notch halves, the stamp, the dashed slot |

### Checks: the smoke walk (Turkish, a fresh install)

Driven by `tool/ui_polish/smoke_driver.dart` (Flutter Driver; a simulator
screenshot after each step; extended this round, `5427ce8`) on the iPhone
18 Pro simulator (402 × 874, `49ECC1F0…`) **after removing the app, so a
fresh install**, with `SEED_LANGUAGE=tr` and `SMOKE_LANG=tr`; the practice
used the local stand-in for the proxy (canned items and feedback on
localhost, no AI call; the scoring held back 9 s). 34 screenshots in
`build/fix5-captures/smoke-tr/`; the walk ended with exit 0.

What was seen, in order, in Turkish: Welcome; the name screen; the goals;
getting ready; the mountain intro; the Day 0 test (the first answer wrong,
the sweat drop by the head); the results, then the badge, then the first
climb; the paywall and its X → V13b → Home; Review; the free ticket on a
practice (consent, V18, three answers, V20 waiting, the results); Home:
the rest scene with N01 at once; "Şimdi değil"; **V24f with the new panel
on one screen** ("Bugünlük her şey tamam"; the small "KULLANILDI" ticket
with "5:18 SONRAKİ"; "Bugünkü ücretsiz bilet kullanıldı." / "Daha uykun
gelmedi mi?"; PREMIUM and "Günde 5 pratik"; the deck with "SIRADAKİ",
"Gerund vs. Infinitive", "Her cevaba yapay zekâ geri bildirimi", "+4
BUGÜN"; "Tilki uyansın · 7 gün ücretsiz"; "Yarın hatırlat" just above the
bar); a drag up did not move it; **Profile's progress card** ("Kasım
ilerlemesi", "Kor Zirvesi · 1 aktif gün", "9 / 300", "Bronz için 66", the
four tinted parts, the three faded medals over the gaps with Bronz 75,
Gümüş 150, Altın 225, the navy dot near the start); back to Home; **Wake →
V13r**; then, with the simulator tool, **two swipes from the left edge
(from x = 10, slow and fast) and one from the screen's very edge**: the
paywall stayed (the driver: "V13r after the edge swipe: true"); **a drag
down**: it stayed ("true"); **the X closed it at once** — V13b had already
opened once this session on the Day 0 paywall, so it does not open again
(its rule, F5-17); back on the rest scene, the companion asleep, the deck
spread again.

V13r has no swipe of its own (its route never had one); the six page-route
entry points' edge swipe was checked in the widget tests in iOS's
behaviour (item 4), not on the simulator: after the walk the driver's
build is gone from the simulator, and the walk does not reach them.

### Checks: builds, tests, disk

After the last code change (`5427ce8`; the app's own last change
`c7eaf5e`):

| Check | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` (with `FIX5_CAPTURE=1`) | **2863 passed**, 0 failed |
| Swift `RunnerTests` (with the widget snapshots, iPhone 18 Pro simulator) | **23 tests, 0 failures**; 64 snapshots |
| Simulator build of Runner + widget extension (`xcodebuild … -destination "platform=iOS Simulator,id=49ECC1F0…" build`, as in round 4) | **BUILD SUCCEEDED**, `GrammarLensWidgets.appex` embedded |
| `flutter build ios --release --no-codesign` | **built** `Runner.app` (50.3 MB reported; 1.4.0 (7)) with `GrammarLensWidgets.appex` |

`flutter build ios --simulator --debug` (the Flutter wrapper, tried twice)
still stops after 4 s with Xcode's "Could not compute dependency graph:
Failed to receive dependency graph response" (exit status 255), as in
round 4; the same scheme builds for the simulator with `xcodebuild`
(above), and the smoke walk built and ran the app with `flutter drive`.

What the checks found and fixed: the flaky Profile layout test (F5-9,
`cef8544`); the old card's "Monthly total" line read by two Profile tests,
and round 4's system-back test, which asserted the behaviour item 4
removes (changed with their items).

**Disk.** 16 GiB free at the start; 14 GiB after the builds; after the
allowed cleanup (`flutter clean` in `~/GrammarLens` with the captures moved
aside and back, then `flutter pub get`; this project's two DerivedData
folders, `Runner-gqpsqce…` for `~/GrammarLens/ios/Runner.xcworkspace` and
`Runner-ghmgufz…` for `~/GrammarLens/macos/Runner.xcworkspace`) **18 GiB
free**. Nothing else was touched (the BirdApp DerivedData stays).

### Not verified

- **Anything on a device**: the new panel and its motion at the owner's
  own text size, the deck's glint and gather, the progress card's fill,
  the paywall's swipe and drag on the phone with each entry point. The
  fourth pass is the first section of `DEVICE-CHECKS.md`.
- **The six page-route entry points' edge swipe on a simulator**: checked
  in widget tests with iOS's behaviour (the route's swipe gesture is
  Flutter's own, the same code on the device), not by hand on the
  simulator (the smoke walk reaches V13r only).
- **393 × 852, 428 × 926, 440 × 956 and the SE**: no such simulator here;
  checked as widget-test renders at those sizes (items 1 and 2).
- **V24 (Premium) on the simulator**: the walk is a free user's; V24 was
  checked in widget tests and renders only.
- **The practice in the smoke walk** used the local stand-in for the proxy:
  no real generation or scoring, no paid call.
- **"The next text size"** is the app's Large (F4-2); the owner's phone
  setting is not known.

## Fix round 4 (owner's second device pass, 2026-11-18)

`FIX4.md`, SPEC v12. The owner ran fix round 3's second pass on his iPhone
14 Plus (428 × 926, release build, Turkish interface, a larger text size)
and confirmed results → badge → first climb, V12's bubble, the switches,
the ribbon, the paywall order, N01 after a practice, the name screen, the
goal tilt, the shine, V05b, the flag and dark mode in the app. This round
fixes what he found, on `ui-polish-widgets`. **Status: done** (items
1–8, steps 0, Checks and Docs below; the checks ran after the last code
change, `aea0f92`). Not on `main`, not shipped, not checked on a device;
the third pass is the first section of `DEVICE-CHECKS.md`.

| Step | Status | Commits |
|---|---|---|
| 0 Start | done | `d823d2d` |
| 1 V24f on one screen, the campfire | done | `7f6dc7e` |
| 2 The paywall footer | done | `c1df10c` |
| 3 Widgets v12 | done | `6fe1060` |
| 4 Profile's month progress card | done | `0af1e60`, `78f8692` |
| 5 Props by the head | done | `8949e42` |
| 6 Haptics on forward buttons | done | `37c36a8` |
| 7 Loading screens | done | `59caa2f` |
| 8 Upper case by language | done | `df9d9a6` |
| Checks | done | `8f12f80`, `8ad3761`, `aea0f92` (what the checks found) |
| Docs | done | this commit |

### 0. Start

`df -h ~`: **16 GiB** free at the start (228 GiB disk); nothing needed
deleting then. On `ui-polish-widgets`, `git pull --ff-only` (up to date);
`FIX4.md`, SPEC v12 and the six changed boards and screens committed as
"docs: fix round 4 task and SPEC v12" (`d823d2d`). The end-of-run figure is
under "Checks: builds, tests, disk".

### 1. V24f on one screen, and the campfire

**What was wrong (device):** the "Remind me tomorrow" row was below the nav
bar and needed a scroll; scrolled, the dream bubble slid under the status
bar; the campfire was a large flat flame on a ring of stones on the trail
in front of the tent.

**Cause.** Round 3 fitted the sheet so *Wake* ended 8 pt above the bar, so
the row under the card was always below it. The sheet held a "PREMIUM ·
Not sleepy yet?" row above the title, 34 pt tickets, a 56 pt button and a
48 pt row. The camp used a 73 pt companion (110 image units) and put the
fire in its own 76 × 96 unit box on the trail below the tent; the flame
was two flat shapes (solid orange and gold).

**Fix (`7f6dc7e`).** `widgets/rest_scene.dart` rewritten:
- **One screen.** The sheet starts at the board's place (V24f: 265 pt
  under the safe area at 390 pt wide, scaled with the width: **312 at
  390 × 844**; V24: its own board's 466) and only rises when the reminder
  row would not end 8 pt above the bar (the scene then crops from the top,
  never below the camp plus a 100 pt band for the bubble). The sheet's
  bottom padding is the bar's height plus 8, so a fitted page has no
  scroll extent at all. Spare room on taller phones stays under the row,
  as on the board (F4-4).
- **Compact sheet (board v12).** One header for both scenes: the moon,
  "All done for today" with two small ticks under it, the countdown and
  its label on the right. V24f's card: the title and the PREMIUM chip on
  one row, five 50 × 30 tickets, the allowance line, the weak-spot line,
  the 48 pt Wake button. The reminder row is 44 pt (the board's 40 at the
  app's touch targets, F4-3), its time chip drawn 30 pt inside a 44 pt tap
  area.
- **The camp at the board's scale** (84 pt companion at 390 wide, the tent
  80 × 65, the fire box 56 × 66 at the companion's front right). **The
  fire:** the log pile's base (measured: the pile's lowest saturated pixel
  is row 270 of the 384-pixel logs image) stands on the companion's foot
  line (fox_sleep's lowest pixel is at 0.897 of its box, F4-5); the flame
  is 40 % of the companion's height in two layers (a radial gradient
  #FFE07A → #FF9A2A → #FF5A1F with a soft orange halo, a pale #FFF1B0
  heart) flickering in opposite phase (`gl-flame`, 0.5 s and 0.38 s), three
  sparks (1.4 s), and a warm glow on the ground under the camp (`CampGlow`,
  `gl-glowpulse` 1.6 s). A soft shade under the status bar (the board's
  120 pt gradient).
- **The bubble** is laid out by its foot at the companion's head, its top
  never above the safe area (V24: never over the "See you" chip).
- **Late in the month** the camp is high on the mountain and the art's top
  edge would show: the art then starts lower and a mirrored copy continues
  its sky, so the camp keeps its place under the bubble (F4-6).
- **V24 (Premium)** uses the same camp, header and reminder row (F4-1).
- Strings: `restNextDailyTest` added (8 languages); `restBody`,
  `restPracticeTitle`, `restTestLine`, `restNextTest`, `restTicketUsed`,
  `restNotSleepy` removed (no longer used).

**Tests.** `home_screen_test` "v12 V24/V24f <size>, <text> text": both
scenes × 375 × 667, 390 × 844, 393 × 852, 402 × 874, 428 × 926, 440 × 956
× default, next and largest text (F4-2): full-bleed scene, attached sheet,
the board's sheet top at 390 × 844, the camp whole ≥ 12 pt above the sheet
and under the status bar, the logs' base on the feet, the dream bubble
under the status bar's edge, **no scroll extent and the row (and Wake)
≥ 8 pt above the bar at 390 × 844 and up at default and next**, the row
reachable everywhere. Also "v12 V24f step 20/26/30" (late month: the camp
in its place, the sky continued) and "v12 V24f in Turkish, 428 × 926, next
text" (one screen). `b5_home_mountain_test`'s countdown test follows the
new header.

Measured (points; "row" and "Wake" are their clearance above the nav bar;
"extent" is the page's scroll extent):

| Scene | Size | Text | Sheet top | Camp gap above the sheet | Row above the bar | Wake above the bar | Scroll extent |
|---|---|---|---|---|---|---|---|
| V24f | 375 × 667 | default | 215.8 | 12.0 | -1.8 | 67.2 | 9.8 |
| V24f | 375 × 667 | next | 215.8 | 12.0 | -34.8 | 34.2 | 42.8 |
| V24f | 375 × 667 | largest | 215.8 | 12.0 | -214.8 | -145.8 | 222.8 |
| V24f | 390 × 844 | default | 312.0 | 50.8 | 67.0 | 136.0 | 0.0 |
| V24f | 390 × 844 | next | 312.0 | 50.8 | 32.0 | 101.0 | 0.0 |
| V24f | 390 × 844 | largest | 246.2 | 12.0 | -77.2 | -8.2 | 85.2 |
| V24f | 393 × 852 | default | 326.0 | 51.2 | 61.0 | 130.0 | 0.0 |
| V24f | 393 × 852 | next | 326.0 | 51.2 | 26.0 | 95.0 | 0.0 |
| V24f | 393 × 852 | largest | 258.8 | 12.0 | -81.8 | -12.8 | 89.8 |
| V24f | 402 × 874 | default | 335.2 | 52.4 | 73.8 | 142.8 | 0.0 |
| V24f | 402 × 874 | next | 335.2 | 52.4 | 38.8 | 107.8 | 0.0 |
| V24f | 402 × 874 | largest | 263.9 | 12.0 | -34.9 | 34.1 | 42.9 |
| V24f | 428 × 926 | default | 337.8 | 55.8 | 123.2 | 192.2 | 0.0 |
| V24f | 428 × 926 | next | 337.8 | 55.8 | 112.2 | 181.2 | 0.0 |
| V24f | 428 × 926 | largest | 303.0 | 21.0 | 8.0 | 77.0 | 0.0 |
| V24f | 440 × 956 | default | 361.0 | 57.3 | 130.0 | 199.0 | 0.0 |
| V24f | 440 × 956 | next | 361.0 | 57.3 | 119.0 | 188.0 | 0.0 |
| V24f | 440 × 956 | largest | 361.0 | 57.3 | 9.0 | 78.0 | 0.0 |
| V24f (Turkish) | 428 × 926 | next | 337.8 | | 66.2 | | 0.0 |
| V24 | 375 × 667 | default | 422.9 | 106.4 | 44.1 | – | 0.0 |
| V24 | 375 × 667 | next | 422.9 | 106.4 | 15.1 | – | 0.0 |
| V24 | 375 × 667 | largest | 371.0 | 68.1 | 8.0 | – | 0.0 |
| V24 | 390 × 844 | default | 466.0 | 111.8 | 144.0 | – | 0.0 |
| V24 | 390 × 844 | next | 466.0 | 111.8 | 115.0 | – | 0.0 |
| V24 | 390 × 844 | largest | 466.0 | 111.8 | 56.0 | – | 0.0 |
| V24 | 393 × 852 | default | 481.2 | 112.9 | 136.8 | – | 0.0 |
| V24 | 393 × 852 | next | 481.2 | 112.9 | 131.8 | – | 0.0 |
| V24 | 393 × 852 | largest | 481.2 | 112.9 | 48.8 | – | 0.0 |
| V24 | 402 × 874 | default | 493.9 | 116.1 | 146.1 | – | 0.0 |
| V24 | 402 × 874 | next | 493.9 | 116.1 | 141.1 | – | 0.0 |
| V24 | 402 × 874 | largest | 493.9 | 116.1 | 58.1 | – | 0.0 |
| V24 | 428 × 926 | default | 506.8 | 125.4 | 185.2 | – | 0.0 |
| V24 | 428 × 926 | next | 506.8 | 125.4 | 180.2 | – | 0.0 |
| V24 | 428 × 926 | largest | 506.8 | 125.4 | 97.2 | – | 0.0 |
| V24 | 440 × 956 | default | 534.7 | 129.7 | 187.3 | – | 0.0 |
| V24 | 440 × 956 | next | 534.7 | 129.7 | 182.3 | – | 0.0 |
| V24 | 440 × 956 | largest | 534.7 | 129.7 | 129.3 | – | 0.0 |

The SE scrolls a little at the default and next text, and every size but 428 and 440 pt wide at the largest (allowed: SPEC V24f v12); the row is reachable everywhere (tested). V24's row is the sheet's last row (no Wake button).

### 2. The paywall footer

**What was wrong (device):** the pinned footer was about 207 pt tall and
spread out: a halo panel round the button, wide links, "Maybe later" under
them.

**Cause.** The footer stacked a 52 pt button inside `CtaGlow`, whose pulse
ring scaled 8 % wide and 45 % tall (mid-pulse it reads as a flat panel
round the button), the price line at a 1.6 line height, the three long
links ("Restore Purchases", "Terms of Service", "Privacy Policy") in 30 pt
rows that wrap at a large text size, a "Maybe later" row and the inset plus
4 under it.

**Fix (`c1df10c`).** The board's footer on V13, V13c, V13a and V13r: the
card colour under a 2 pt line, 24 pt side margins, the 54 pt button with
only its pulse (the ring now grows 10 pt evenly round it and fades, F4-8),
the full price line at 12 pt, centred, at most 300 pt wide, and **Restore ·
Terms · Privacy** on one centred row at 12 pt (new short labels
`paywallRestoreShort`, `paywallTermsShort`, `paywallPrivacyShort`;
VoiceOver reads the full names; each target still 44 pt, reaching 12 pt
over the price line and into the bottom margin), the board's 26 pt under
them. **No "Maybe later" anywhere** (the onboarding paywall is the same
screen): the close button is the way out, V13b once per session as before;
`paywallMaybeLater` is removed from the eight ARB files (the analytics
method constant `maybe_later` stays, documented as retired, so older data
reads). The first view takes the board's top row: Close at the start and
the GRAMMARLENS PREMIUM chip at the end, instead of a wordmark row plus a
chip row under the companions (F4-7): with the compact footer this puts
"Compare plans" and its arrow on the first view at every phone size
(closes F3-26).

**Tests.** `premium_screen_test`: the "Maybe later" tests now use the close
button (and assert there is no "Maybe later"); the footer measurements
follow the compact footer (the large-text SE footer is 144 pt, 0.216 of the
screen, and 243 pt at a 1.6× system scale, down from 0.349 and 0.462); the
rhythm and 44 pt reach above and below the links; a new group "V13 v12:
the compact footer" at the five sizes. `home_day0_paywall_test` and
`first_launch_climb_test` close the Day 0 paywall with the close button
(method `close_button`).

Measured (default text, the app's font; "Compare plans" clearance is the
label's and the whole hint's, arrow included, above the footer's top):

| Size | Footer height | "Compare plans" label clear | Hint with arrow clear |
|---|---|---|---|
| 375 × 667 | 140.0 | 32.0 | 8.0 |
| 390 × 844 | 154.0 | 35.0 | 11.0 |
| 402 × 874 | 154.0 | 50.0 | 26.0 |
| 428 × 926 | 154.0 | 117.0 | 93.0 |
| 440 × 956 | 154.0 | 132.0 | 108.0 |

The iPad first view is under "Checks".

### 3. Widgets v12

**What was wrong (device):** the medium tip widget showed one short rule
and was mostly empty; in dark mode every widget turned system grey and the
small one looked poor.

**Cause.** The tip payload held one hint line of the most frequent weak
spot's topic; the dark card was #252528 and the small waiting widget kept
its light orange with dark text.

**Fix (`6fe1060`).** The tip widget now shows the user's own latest
mistake:
- **Content.** The topic as the eyebrow; a short rule with its key words in
  a green pill (the scorer's stored rule, with the corrected words in the
  pill; the Daily Test stores no rule, so its topic's hint line whose key
  matches the correction, the key in the pill, F4-9); the user's sentence on
  one line, the wrong words struck through (red tint), and the corrected
  sentence (green tint, the corrected words bold), each one line with "…".
  A one-word answer to a one-blank question is put back into its sentence;
  otherwise the stored texts are compared word by word (1.4.0 B10's diff);
  a long sentence starts with "…" a few words before the mistake so it
  stays in view. "Your weak spot · a new one daily". A different weak spot
  each day, in turn (the ten most recent; the midnight entry is tomorrow's).
  With none yet: a topic's hint rule and two more hint lines.
- **Taps.** The left side opens that weak spot (R03) through a new link,
  `grammarlens://weak-spot?topic=…&type=…`, which switches to Review and
  opens it there (F4-10); the right box opens the Daily Test, or Home once
  done, where it shows "✓ Done", the hours to the next test and the
  companion asleep (its sleep pose written to the App Group like the
  avatar).
- **Data.** Read from Review's own records on the device and written to the
  App Group with the existing payload: nothing new leaves the device or is
  collected (`product.yaml` `legal` unchanged).
- **Dark variants** for the small widgets and the tip widget: card #1E1C27
  with a 1 pt #2E2C36 edge, text #F2EEE8, secondary #A9A6B2; the small
  waiting widget orange one shade deeper (#D9620E → #B84E08) with cream
  text; the done box #1B2E6B; green and red tints as SY03. The medium
  mountain widget is unchanged.
- Swift: the v12 tip fields are optional, so an older payload still decodes
  (until the app writes a new one at launch).
- Strings: `widgetWeakSpotFooter`, `widgetDoneShort`, `widgetNextInShort`
  added; `widgetTipLabel`, `widgetTipFooter` removed (no longer used).

**Tests.** Dart: `widget_payload_test` (the mistake's runs, the rotation,
the Daily Test's hint, the long sentence, no weak spot, the taps, done;
Turkish keeps the English topic name in capitals); the fixtures regenerated
plus `en_daily_test` and `en_long`; `widget_sync_test` (the sleep image,
the ten most recent weak spots, an entry without an answer skipped);
`app_link_test` (the weak-spot link and its router); `review_screen_test`
(the link opens R03, a link that came first, a weak spot no longer saved).
Swift (`WidgetSnapshotTests`): every widget × state × light and dark, the
sample (the board's "I'm interested to learn French"), the general tip in
both, an older payload, and the Dart fixtures (English waiting and done,
the Daily Test case, the long sentence, Turkish with no weak spot, German,
Arabic) in light and dark: 64 snapshots.

### 4. Profile's month progress card

**What was wrong (device):** the old card: an orange "5 points" box, one
bar and the tiers listed underneath.

**Cause.** Round 3 changed V23's ribbon only; `MonthlyProgressCard` was
never rebuilt to the V23 card.

**Fix (`0af1e60`).** As on the V23 board: "<Month> progress" and
"<mountain> · N active days" on the left, the score capsule (the ring round
the clay star, the points, "N to Bronze") at the top right, a bar of ten
12 pt segments filled by the month's points (the last one partly), the tier
marks under it centred on their thresholds' places (`medalTierMark`
"Bronze 75"; moved in at the card's edges, never over one another; bronze
#9A6A3A and silver #6F7782 in light, their dark tints in dark, gold
`goldText`), and "Monthly total: N / 300 points". Every number from
`MonthlyMedalRules`; VoiceOver reads the same summary as before.
`medalNextLabel`, `medalTopLabel` and `medalGoalPoints` are no longer used
and removed. The title may wrap to two lines beside the capsule at 390 pt
(F4-12).

**Tests.** `monthly_medal_collection_test` "N9 / V23 v12" (in the app's
font): two months (November 2026, February 2027) at 0, a sixth, Bronze,
Silver + 1, Gold and the maximum: each segment's fill, the capsule's
points, the total, the marks' text and places; the head and the capsule's
place; light and dark colours. `fix4_profile_card_test`: light and dark at
the default and the next text size, 0 to 300 points, the marks inside the
card. `profile_layout_test`'s end-of-page test now scrolls to the lazy
page's true end (`78f8692`: with the shorter card one long drag stopped
76 pt short; the requirement is unchanged).

### 5. Props by the head

**What was wrong (device):** on a wrong answer the giraffe's sweat drop fell
from far above and to the right of its head.

**Cause.** Every prop sat at a fixed place in the image box (the drop at the
box's top right corner, X01), the same for every hero; the giraffe's head
is in the middle of the top.

**Fix (`8949e42`).** `tool/scene_art/companion_heads.py` (ImageMagick, no
packages) measures each hero × pose image's head box from its pixels: the
silhouette's top; the neck as the narrowest row between 30 % and 70 % of
its height that the body widens again from (else half the silhouette); the
sides as medians of the rows' extents over the head's lower two thirds. 12
of the 63 images take a hand correction read off a grid, each with its
reason in the tool: the six lying sleep poses (fox, panda, koala, bird,
cat, sloth: the head is at one side), five crab images (the face is on the
body, the raised claws widen the top) and the fox's wave (the raised paw
read as a neck). It writes `lib/widgets/companion_head_table.dart`.
`CompanionView.propRectFor` places each prop from the table: the sweat
drop at the temple on the right, falling along the cheek; the thought
bubble and the cloud just above the head's top right; the Zzz rising from
just above the head; the sparkle beside it; mirrored about the head's
middle in RTL (the Zzz drifts left there). Sizes stay X01's.

**Tests.** `fix4_props_test`: every hero × pose image (63) has a head box
inside its image; every hero × prop sits by its head and mirrors in RTL;
the giraffe case (the old corner was outside the head, the new drop is
inside it); a contact sheet of the nine heroes × five props in light, dark
and Arabic.

### 6. Haptics on forward buttons

**What was wrong:** SPEC §3.4 v12, §1.25: moving on should be felt.

**Cause.** The practice's Next / Submit (a `FilledButton` in
`PracticeStepFooter`) had no haptic; the Daily Test's Check had a light
one (Finish a medium one) on top of its own right / wrong feedback.

**Fix (`37c36a8`).** Next / Submit give light; Check and Finish give none
of their own (the feedback, success / two light taps / warning, is their
haptic). Every forward button in onboarding, the Daily Test, practice and
the results:

| Flow | Button | Where | Haptic on tap |
|---|---|---|---|
| Onboarding | V02 "Get started" | `welcome_screen.dart` | light |
| Onboarding | V03 "Choose <Buddy>" | `buddy_picker.dart` | light |
| Onboarding | V03b "<Buddy> it is" | `lucky_wheel_screen.dart` | medium (primary CTA) |
| Onboarding | V04 "Continue" | `onboarding_screen.dart` (name) | light |
| Onboarding | V05 "Continue" | `onboarding_screen.dart` (goal) | medium (primary CTA) |
| Onboarding | V06 "Let's climb" | `mountain_intro_screen.dart` | medium (primary CTA) |
| Daily Test | Check / Finish | `daily_test_screen.dart` | none of its own: the right / wrong feedback (**changed**: was light / medium on top) |
| Daily Test | the sheet's "Continue" / "Got it" / "See results" | `daily_test_screen.dart` | light |
| Results | V10 "Climb my first step", "Continue" | `daily_test_result_screen.dart` | medium |
| Results | V11 "Continue" | `medal_celebration.dart` | light |
| Results | V12 "Continue" | `first_climb_screen.dart` | medium |
| Practice | V17 "Start N questions" | `practice_length_picker.dart` | medium |
| Practice | V19 "Next" / "Submit" | `practice_step_footer.dart` | light (**new**) |
| Results | V21 "Back to topics" | `results_screen.dart` | light |
| Results | V21 "See Premium" | `results_screen.dart` | medium |

(Skip is not a forward button: the Daily Test's keeps its light, the
practice's none.)

**Tests (through `HapticMap.log`).** `daily_test_check_test` "v12: one
haptic per Check, then light for Continue"; `fix4_haptics_test`: Next /
Submit light once, nothing when disabled, nothing for Skip.

### 7. Loading screens

**What was wrong (device):** V20's content sat at the top with the lower
half empty, all three checklist items were ticked while the wait went on,
and the lens poked out of the answer card.

**Cause.** V20 and V18 were top-aligned scroll views; V20's checklist ticked
all three items over 2.4 s whatever the result did; the lens stood 14 pt
above the scan window (out of the cards at the top of the sweep).

**Fix (`59caa2f`).** Both screens centre their content in the space under
the header (`widgets/centered_scroll.dart`: it scrolls only when it does not
fit). V20's first two items tick on their timers (0.8 s apart, light each);
the last, "Writing your feedback", stays in progress (a pulsing dot) until
the result arrives and ticks with it (the result's success haptic); the
results follow 400 ms later (at once under Reduce Motion). The lens sits
inside the scan window.

**Tests.** `fix4_loading_test`: before the result two items ticked and the
last in progress, still after 20 s; after it all three; the same under
Reduce Motion; V20 and V18 centred (±8 pt) in light and dark; the lens
inside the window through two sweeps.

### 8. Upper case by language

**What was wrong (device, Turkish):** "GERI BILDIRIMIN YOLDA", "TILKI
RÜYASINDA" (right: GERİ, TİLKİ).

**Cause.** Raw `toUpperCase()` on translated text; Dart's ignores the
locale.

**Fix (`df9d9a6`).** One helper, `utils/upper_case.dart`: `upperCaseIn`
(a language code or locale name) and `upperCaseFor` (the app's language):
Turkish and Azerbaijani map i to İ (and ı to I), ß becomes SS, every other
language the default. Every `toUpperCase()` in `lib/`:

| Where | Text | Now |
|---|---|---|
| V06 `mountain_intro_screen.dart` | the month and the mountain (translated) | `upperCaseFor` |
| R01 `topic_practice_screen.dart`, Home `home_practice.dart` | "Picked for you" | `upperCaseFor` |
| V24f `rest_scene.dart` | "<Hero> is dreaming of…" | `upperCaseFor` |
| V24f `rest_scene.dart` | "USED" (the ARB string, already capitals) | `upperCaseFor` |
| V24f `rest_scene.dart`, Home `home_practice.dart` | "Premium" (the plan's name) | `upperCaseIn('en')`, as the ARB's own "PREMIUM" (F4-13) |
| V20 `practice_reviewing.dart` | "Your feedback is on its way" | `upperCaseFor` |
| V18 `practice_preparing.dart` | "Did you know?" | `upperCaseFor` |
| R04 `month_card_sheet.dart` | the month card's title and eyebrow | `upperCaseFor` |
| R05 `medal_celebration.dart` | "<Tier> medal" | `upperCaseIn(l10n.localeName)` |
| R03 `weak_spot_detail_screen.dart`, V16 `review_parts.dart`, W01 `widget_payload.dart` | topic names (English in every language) | `upperCaseIn('en')` |
| left as they are (English content or codes) | `text_format.dart` (slugs), `feedback_format.dart` (a case test on English feedback), `blank_assembly.dart` (English question sentences), `weak_spot_detail_screen.dart` `_sentence` (the scorer's English rule), `monthly_equivalent.dart` (a currency code), `theme_preview_screen.dart` (a debug colour) | — |

The Turkish ARB strings written in capitals were checked one by one (SENİN
YAZDIĞIN, DÜZELTİLMİŞ HALİ, GÜNLÜK PRATİĞİN, ÖNERİLEN ODAK, BUGÜNÜN BİLETİ,
SONRAKİ, İZLE, GÜNÜN İPUCU, ŞİMDİ ÇALIŞ, KULLANILDI, TIRMANIŞIN, ROZET
KAZANILDI, …): all correct.

**Tests.** `fix4_upper_case_test`: the helper (tr, az, locale names,
German, English topic names); V20, V24f, V18 and R05 rendered in Turkish
with no dotless I where the source has a dotted i.

### Decisions

- **F4-1. V24 (Premium) "uses the same scene, header and reminder row".**
  Options: (a) V24f's frame (the sheet at 312: about 300 pt empty under the
  short V24 sheet); (b) the sheet as low as its content allows (a 600 pt
  scene); (c) V24's own board frame (the sheet at 466 on 390 × 844, the
  companion's top at 254) with V24f's camp, header and row. Choice: (c).
  Why: rule 3 (V24's board) and the smallest change. V24's two done tiles,
  its body line and its step-bar card are gone (their content is in the
  header's ticks); the header's countdown label is the new "next Daily
  Test".
- **F4-2. "The default, the next and the largest text size".** The app has
  three sizes (Small, Medium = default, Large) and the system's Dynamic
  Type applies on top. Choice: default = the app's Medium; next = its
  Large; largest = its Large with the system's largest standard size
  (xxxLarge, × 1.35). Why: "next" is the step up a user takes in the app;
  the largest standard system size is the most a user reaches without the
  accessibility sizes.
- **F4-3. The reminder row is 44 pt, not the board's 40.** TASK §4's 44 pt
  touch targets; the time chip is drawn 30 pt as on the board.
- **F4-4. The sheet never moves below the board's top.** Options: fill the
  spare room with scene; keep it under the row. Choice: keep it under the
  row, as the board does (67 pt at 390 × 844, 130 at 440 × 956).
- **F4-5. "The logs' base on the companion's foot line"** is read as the log
  pile's base (its lowest saturated pixel), not the stones' ring in front;
  the board's own fire sits about 10 pt lower. Why: rule 2 (SPEC's text)
  over rule 3 (the board).
- **F4-6. Late in the month** the art's sky is continued above its top edge
  by a mirrored copy, instead of letting the camp slide up under the
  bubble. Why: the camp and the bubble keep the board's places all month.
- **F4-7. The paywall's top row** takes the board's form (Close at the
  start, the chip at the end; no wordmark, no chip row under the
  companions). Options: keep round 3's first view (F3-26 stays open:
  "Compare plans" 28 pt under the footer at 390 × 844) or take the board's
  row. Choice: the board's (rule 3), which SPEC v12 expects to close F3-26.
- **F4-8. "No static halo panel".** The only thing round the button was
  `CtaGlow`'s pulse ring, scaled 8 % wide and 45 % tall, which reads as a
  flat panel mid-pulse; it now grows 10 pt evenly and fades.
- **F4-9. The tip's rule line.** The stored rule (practice) is a short name
  with no marked key words, and the Daily Test stores none. Choice: the
  scorer's rule with the corrected words in the pill; for the Daily Test
  the topic's hint line whose key matches the correction (its key in the
  pill). Why: SPEC's "a short rule with its key words in a green pill" from
  data the app already has.
- **F4-10. The tip's weak-spot tap** opens R03 through the Review tab (a new
  `grammarlens://weak-spot` link handled like the other widget links);
  a weak spot no longer saved leaves Review open.
- **F4-11. The struck words** are drawn in the wrong row's red (the board
  draws them in the text colour with a line), so the mistake reads at a
  glance.
- **F4-12. V23's title may wrap** to two lines beside the capsule at 390 pt
  (a long translation needs it); the board's English fits one.
- **F4-13. "Premium" in capitals** takes the English rules (PREMIUM, as the
  ARB's own capitalised strings in every language), not Turkish PREMİUM:
  it is the plan's name.

### Checks: the listed captures against their boards

Light renders in `build/fix4-captures/`, dark in `build/fix4-captures/dark/`
(widget-test renders at a phone's size in the app's font, `FIX4_CAPTURE=1`;
the widgets from the Swift snapshot tests, copied to
`build/fix4-captures/widgets/`; the iPad from the simulator gallery). Each
was looked at next to its board.

| Board | Light | Dark | Match / what differs |
|---|---|---|---|
| V24f, five sizes (and 393 × 852), default and next text | `V24f-<w>x<h>-default/next` | same in `dark/` | match: the sheet at the board's 312 (390 × 844), the compact header and card, the row above the bar with no scroll extent from 390 × 844 up, the fire at the companion's front right on its foot line, the dream bubble top left, the capsule top right. Differs: the row is 44 pt (F4-3); on taller phones more room under the row (F4-4); the SE scrolls a little (allowed) |
| V24f late in the month | `V24f-390x844-step20/26/30` | — | the camp in its place, the art's sky continued above its edge (F4-6) |
| V24f in Turkish, 428 × 926, next text | `V24f-428x926-next-tr` | — | one screen; "TİLKİ RÜYASINDA…" |
| V24, five sizes, default and next | `V24-<w>x<h>-default/next` | same | V24's own frame (sheet at 466) with V24f's camp, header and row (F4-1); differs from V24's board: no done tiles and no step-bar card, so more room under the row |
| V13 first view, 390 × 844 and 428 × 926 | `V13-Paywall-390x844`, `-428x926` | same | match: the board's top row (Close, the chip at the end), the compact footer (154 pt; the board about 150), "Compare plans" with its arrow on the first view. The headline and the line under it follow the app's own copy for a weak-spot source (unchanged this round) |
| V13c | `V13c-PaywallCompare-<size>` | same | match: the comparison, the compact footer |
| V13a | `V13a-PaywallPlans-<size>` | same | match: "Choose your plan", the plans, the compact footer |
| V13r | `V13r-PaywallRest-<size>` | same | match apart from the close button, which sits in the top row above the scene (the board puts it inside the scene; unchanged this round) |
| V13 on the iPad (iPad Pro 13" simulator) | `iPad-V13-Paywall` | `dark/iPad-V13-Paywall` | match: the column held to the iPad's width, the top row, the compact footer with the links on one row |
| W01, every widget × state (sample, Dart fixtures: English, Turkish, German, Arabic, the Daily Test case, the long sentence, the general tip, an older payload) | `widgets/*-light` | `widgets/*-dark` | match the v12 board: the topic, the rule with its pill, the struck and corrected rows, the box waiting and done (asleep, "next in 10 h"), the dark variants. Differs: the struck words are red (F4-11) |
| V23 progress card, 0 to 300 points | `V23-progress-<score>` | same | match: the capsule at the top right, ten segments, the marks at their places, the total. The title may take two lines (F4-12) |
| Props by the head (X01, nine heroes × five props) | `props-contact-sheet`, `-ar` | `props-contact-sheet` | every prop by its hero's head; mirrored in Arabic |
| V20 (waiting; after two ticks) | `V20-reviewing`, `V20-reviewing-waiting` | `V20-reviewing` | match the v12 changes: centred, the last item in progress, the lens inside the window. Differs, as since B7: the page is the app's light page, not the board's navy page with a grid; the companion above the title (the board: beside it); no checklist card, no feedback skeleton card, no tip (not part of FIX4) |
| V18 | `V18-preparing` | same | match: centred |
| Turkish capitals | `tr-capitals-V20`, `-V24f`, `-V18`, `-R05` | `tr-capitals-V20`, `-V24f` | match: GERİ BİLDİRİMİN YOLDA, TİLKİ RÜYASINDA…, BİLİYOR MUYDUN?, the medal eyebrow; PREMIUM in English capitals (F4-13) |

### Checks: the smoke walk (Turkish, a fresh install)

Driven by `tool/ui_polish/smoke_driver.dart` (Flutter Driver; a simulator
screenshot after each step) on the iPhone 18 Pro simulator (402 × 874,
`49ECC1F0…`) **after removing the app, so a fresh install**, with
`SEED_LANGUAGE=tr` and `SMOKE_LANG=tr` (the driver now reads the texts it
taps from that language's ARB file). The practice used a local stand-in
for the proxy (canned items and feedback on localhost, no AI call), holding
the scoring back 9 s so V20 could be seen. Run twice:
`build/fix4-captures/smoke-tr/` (24 screenshots) and `smoke-tr2/` (26: the
same walk plus the rest scene alone after N01).

What was seen, in order, in Turkish: Welcome ("İZLE"); the name screen; the
goals; getting ready; the mountain intro; the Day 0 test with the first
answer wrong: **the sweat drop at the fox's temple, by its head**, "Az
kaldı!"; **the results first** ("1. gün tamam!"), **then the Welcome badge**
("ROZET KAZANILDI"), then the first climb; **the paywall with the compact
footer** ("Geri yükle · Koşullar · Gizlilik" on one row, the full price
line, "Planları karşılaştır" on the first view) and **no "Belki sonra"**;
**the X opened V13b** (the cloud over the sad companion), "Ücretsiz devam
et" closed it; Home; Review; the AI consent; the practice (three questions
from the stand-in); **V20 centred, two items ticked and "Geri bildirimin
yazılıyor" with its dot while the scoring was held back, "GERİ BİLDİRİMİN
YOLDA", the lens inside the third card**; the results; back to Home: **the
rest scene and N01 at once** ("TİLKİ RÜYASINDA…"). After "Şimdi değil",
**V24f on one screen**: the header, the card and "Yarın hatırlat" above the
nav bar, the fire at the fox's front right; a drag up left the page where it
was (the two screenshots differ only in the fire's and the shine's frames,
0.2 % of the pixels).

### Checks: builds, tests, disk

After the last code change (`aea0f92`):

| Check | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` (with `FIX4_CAPTURE=1`) | **2807 passed**, 0 failed |
| Swift `RunnerTests` (with the widget snapshots, iPhone 18 Pro simulator) | **23 tests, 0 failures**; 64 snapshots |
| Simulator build of Runner + widget extension (`xcodebuild … -destination "platform=iOS Simulator,id=49ECC1F0…" build`, as in round 3) | **BUILD SUCCEEDED**, `GrammarLensWidgets.appex` embedded and validated |
| `flutter build ios --release --no-codesign` | **built** `Runner.app` (50.3 MB reported; arm64; 1.4.0 (7)) with `GrammarLensWidgets.appex` |

`flutter build ios --simulator --debug` (the Flutter wrapper, tried twice)
stopped after 4 s with Xcode's "Could not compute dependency graph: Failed to
receive dependency graph response" (exit status 255) for its generic
simulator destination; the same Xcode built the same scheme for a
simulator device with `xcodebuild` (above), and both smoke walks built and
ran the app on the simulator with `flutter drive`. Recorded, not chased:
it is Xcode's build service, not the code, and round 3's check is the
`xcodebuild` one.

What the checks found and fixed: the font-weight and wordmark guard tests
after the paywall change (`8f12f80`: the separator's weight through
`withWeight`; the paywall no longer carries a wordmark, F4-7), and the
iPad capture showed the top row's chip drifting toward the middle
(`aea0f92`: at the row's end as on the board; the phone renders and the
iPad capture were redone).

**Disk.** 16 GiB free at the start; 14 GiB before the cleanup; after the
allowed cleanup (`flutter clean` in `~/GrammarLens`, the captures moved
aside and back; this project's DerivedData folder `Runner-gqpsqce…`,
WorkspacePath `~/GrammarLens/ios/Runner.xcworkspace`) **17 GiB free**. The
two DerivedData folders without an `info.plist` were left, as in round 3.

### Not verified

- **Anything on a device**: the haptics (forward buttons, Check's one
  haptic), the widgets on a real Home Screen (iOS keeps the old layouts
  until a widget is removed and added again), the widgets' links on the
  phone (the weak-spot link opening R03), the fire and the rest scene at the
  owner's own text size, performance. The third pass is the first section
  of `DEVICE-CHECKS.md`.
- **The owner's text size**: "the next text size" is the app's Large
  (F4-2); the phone's own Dynamic Type setting was not known. V24f was
  checked in Turkish at 428 × 926 with the app's Large (one screen, 66 pt
  to spare) and up to the app's Large × the system's xxxLarge (a short
  scroll at 390–402 pt wide, allowed).
- **375 × 667, 393 × 852, 428 × 926 and 440 × 956**: no such simulator
  here; checked as widget-test renders at those sizes (items 1 and 2).
- **The practice in the smoke walk** used a local stand-in for the proxy
  (canned items and feedback on localhost): no real generation or scoring,
  no paid call; the walk's V20 waited 9 s because the stand-in held the
  result back.
- **The widget extension's dark edge** uses `ContainerRelativeShape`, which
  the snapshot tests draw as the test's own rounded frame; the real widget
  corner is the system's.

## Fix round 3 (owner's device test of the integrated build, 2026-11-18)

`FIX3.md`, SPEC v11. The owner tested `ui-polish-widgets` on his iPhone 14
Plus (release, iOS 26): an install over App Store 1.4.0 (data survived),
then a fresh install. This round fixes what he found, on
`ui-polish-widgets`. **Status: done** (A1–E1 and steps 0–6 below; checks
after the last code change under "Checks: builds and tests"); not on
`main`, not shipped, waiting for the owner's second device pass
(`DEVICE-CHECKS.md`, first section).

### 0. Start

Free space before: **8.5 GiB**. Deleted, as allowed: `flutter clean` in
`~/GrammarLens` (`build/` 2.7 GB, `.dart_tool/` 591 MB) and its DerivedData
folder `Runner-gqpsqce…` (WorkspacePath `~/GrammarLens/ios/Runner.xcworkspace`,
2.8 GB). Xcode was open (the owner's session, left running) and re-indexes
into that folder, so 727 MB of it came back during the delete; it was left
alone (quitting the owner's Xcode is not this run's call). After: **11 GiB**.
The end-of-run figure is under "Checks".

`git pull --ff-only` (up to date); the task, SPEC v11 and the changed and
new boards committed as "docs: fix round 3 task and SPEC v11" (`dd31c12`).

### E1. The owner's Xcode change

`ios/Runner.xcodeproj/project.pbxproj` had the owner's uncommitted change
from the device test. It sets the team for the widget target, and Xcode
rewrote four more lines when it saved the project. Every changed line:

| Line (object) | Change |
|---|---|
| `B595896E… NunitoSans-Variable.ttf` (file reference) | `lastKnownFileType = file;` added |
| `DFB0C932… OFL-NunitoSans.txt` (file reference) | `lastKnownFileType = text;` added |
| the `Shared` group | `name = Shared;` removed (its `path` is `Shared`, so the shown name is the same) |
| the `GrammarLensWidgets` group | `name = GrammarLensWidgets;` removed (same: `path` gives the name) |
| `GrammarLensWidgets` Debug, Release, Profile build settings | `DEVELOPMENT_TEAM = 37U9L67C2J;` added (three lines) |

No signing style, provisioning profile, bundle ID, entitlement or other
target changed. The four extra lines are Xcode's normal rewrite of the
script-made objects (`tool/ios/configure_xcode_project.rb` matches groups by
their shown name and files by path, so it still finds them). Committed
unedited as "chore(ios): development team for the widget target (owner,
device test)".

### A1. Day 0: the badge came before the results

**What the owner saw:** after the Day 0 test the Welcome badge (V11) opened
first; the results (V10) only after "Continue". SPEC §4: V10 → V11 → V12.
(The integration's smoke walk saw the same order and recorded it as the
flow's behaviour.)

**Diagnosis.** Hypotheses:
1. The first-launch flow pushes a badge route before the results: **ruled
   out**, `first_launch_flow.dart` has no badge step at all
   (dailyTest → dailyTestResult → firstClimb).
2. The result screen pushes the badge when it opens: **ruled out**, it
   pushes no route.
3. The result screen opens the badge as a layer over itself when the save
   lands: **supported.** `DailyTestResultScreen._saveCompletion` sets
   `_celebration = _Celebration.welcome()` as soon as
   `completeDailyTest` reports a live Welcome earn, and `build` stacks
   `MedalCelebration.welcome` over the results. The save lands within a
   frame or two of the screen opening, so the first thing the learner sees
   is the badge; its Continue only closes the layer, revealing the results
   and their "Climb my first step". This was Batch 5's N15 ("the
   celebration opens over the results when the save lands"), which SPEC v11
   §4 now overrides. Checked by reading the code and by the existing tests,
   which asserted exactly this order (`first_launch_climb_test` "end to
   end: the Welcome celebration over the results, then the results, …").

**Later days with a medal (R05):** SPEC R05 says the medal "opens right
after the Daily Test results when a tier is reached", and FIX3 keeps their
current order unless SPEC says otherwise: the tier layer still opens over
the results when the save lands and closes back to them (F3-1).

### A2. N01 opened late

**What the owner saw:** Day 0 test → Review → the free ticket used on a
practice → back to Home: the rest scene (V24f) showed but N01 did not open;
it opened only after another tab switch. SPEC §5.10: N01 opens as soon as
the first rest scene is on screen.

**Diagnosis.** Hypotheses, each checked with the whole app (its real tab
shell, Home, Review) in `test/fix3_n01_trigger_test.dart` on the code before
the fix:
1. *The trigger runs only on Home's first build or `initState`*: **ruled
   out.** The check sits in Home's `build` (every build, once-guarded by
   `_restSceneSeen`); a cold start straight into the rest scene opens N01
   (test (b) passed before the fix).
2. *It reads the ticket state before the practice result was saved*:
   **supported, in a stronger form.** Home reads today's free-ticket count
   only in `initState`, on app resume and after its own Daily Test. A
   practice started from Review records the ticket while Home is another
   (kept-alive) tab, and Home never re-reads it when it is shown again: in
   test (a) (Review, ticket used, back to Home) Home showed the ordinary
   Home, not the rest scene at all. The rest scene then appears only after
   some later refresh: on the phone, an app resume (iOS resumes an app
   after any system overlay), which is how the owner got the rest scene
   without N01.
3. *It waits for an event that a tab switch does not send*: **supported.**
   `_maybeShowSoftAsk` runs only inside `build` and declines while Home is
   not "quiet" (`_homeVisible`: the active tab, the top route, not paused;
   no step walking; no month card). When it declines, nothing calls it
   again until Home happens to rebuild: a route above Home closing, the
   pawn landing or the app resuming does not re-check, and a tab switch
   rebuilds Home only by chance (that is what finally opened it on the
   phone). A second blocker found on the way: when the rest scene replaces
   the mountain while a step is still walking, the mountain never reports
   the walk's end, so `_climbAnimating` stays true and N01 stays blocked.

The exact moment on the phone (which refresh brought the rest scene while
which condition said "not quiet") cannot be replayed without the phone;
the two causes above are each enough to give the owner's symptom.

**Fix (A1, `df1747c`).** The save only notes the Welcome earn. The results
(V10) show alone; their "Climb my first step" opens the badge (V11) over
them, and the badge's Continue goes on to the first climb (V12), or pops
the route where there is no first climb. The results stay in one `Stack`
whether or not a layer is open, so opening the badge no longer rebuilds
them (their entrance replayed and the list jumped 10 pt). R05 unchanged
(F3-1).

**Tests (A1).** `first_launch_climb_test` "end to end (A1)": the Day 0
walk records results, badge, first climb, Home, step, Premium in that
order; it fails on the old code (the badge first). The result screen's,
Home's and the first-launch flow's Welcome tests follow the new order
(`climbThroughWelcome` in `test/support/celebration_support.dart`).

**Fix (A2, `669b218`).** Home re-reads today's Daily Test and the free
ticket whenever it becomes the visible tab again, so a ticket used from
Review shows the rest scene at once. N01's check (`_scheduleSoftAskCheck`)
runs after the frame that shows the rest scene and whenever Home's
visibility changes: the tab, a route above it closing, resume, the pawn
landing. A walk cut short by the rest scene no longer holds it back. Still
once: the stored answer and the controller's open flag guard it.

**Tests (A2).** `test/fix3_n01_trigger_test.dart`, the whole app shell:
(a) Home, Review, ticket used, back to Home: rest scene and N01 at once;
(a') the same with a resume while Review is in front; (b) a cold start into
the rest scene; (c) never twice after "Not now", across tab switches and a
resume; (c') never twice after a swipe close. (a) and (c') fail on the old
code.

### B1. V24f (and V24): full-bleed scene, attached sheet

**What was wrong:** both rest scenes were a separate rounded card, the art
about 2× zoomed in, the fire cut at the card's edge, the dream bubble in
the middle. The boards: the scene full-bleed from the top of the screen
(behind the status bar), the night sheet attached under it.

**Fix (`d445e59`).** `RestScene` is rewritten: the scene is full-bleed from
y = 0 with the art at the boards' scale (600 px of art over 390 pt), never
scaled up; the night sheet is attached under it (rounded top corners, down
to the page's end). After layout the sheet's top is fitted so its anchor
ends 8 pt above the nav bar: V24f's "Wake <Hero> up" card, V24's last row.
The scene is cropped from the top for it, never so far that the camp (tent
top to fire foot) loses 12 pt above the sheet. Dream bubble top left,
capsule top right; V24's chip and bubble as on its board. This replaces
integration decision I-7 (a shorter, scaled-up scene). V24 had the same
card, so it got the same treatment.

**Tests.** `home_screen_test` "B1 V24/V24f size, text": both scenes ×
default and largest text × 375 × 667, 390 × 844, 393 × 852, 402 × 874,
428 × 926, 440 × 956: the scene full-bleed (top 0, full width), the sheet
attached at its bottom, the camp (tent, companion, fire) inside the safe
area and ≥ 12 pt above the sheet, Wake ≥ 8 pt above the bar where the
screen is at least 800 pt tall, the row reachable by scrolling. No 375 ×
667 or 428 × 926 simulator exists, so all sizes are widget-test renders
(`FIX3_CAPTURE=1`: `build/fix3-captures/V24*-<w>x<h>-<text>.png`).

Measured (points; "sheet top" is the scene's height above the sheet):

| Board | Size | Text | Sheet top (= scene height above the sheet) | Camp gap above the sheet | Wake above the bar |
|---|---|---|---|---|---|
| V24f | 375 × 667 | default | 240.8 (minimum: camp + bubble band) | 12.0 | −32.8 (a short scroll) |
| V24f | 390 × 844 | default | 364.0 | 86.1 | 9.0 |
| V24f | 393 × 852 | default | 372.0 | 86.9 | 9.0 |
| V24f | 402 × 874 | default | 394.0 | 89.6 | 9.0 |
| V24f | 428 × 926 | default | 446.0 | 97.2 | 9.0 |
| V24f | 440 × 956 | default | 476.0 | 100.7 | 9.0 |
| V24f | 375 × 667 | largest | 240.8 (minimum) | 12.0 | −50.8 (a short scroll) |
| V24f | 390 × 844 | largest | 324.0 | 63.7 | 9.0 |
| V24f | 393 × 852 | largest | 332.0 | 58.8 | 9.0 |
| V24f | 402 × 874 | largest | 354.0 | 75.1 | 9.0 |
| V24f | 428 × 926 | largest | 430.0 | 97.2 | 9.0 |
| V24f | 440 × 956 | largest | 460.0 | 100.7 | 9.0 |
| V24 | 375 × 667 | default | 292.0 | 63.2 | (the row) |
| V24 | 390 × 844 | default | 435.0 | 86.1 | |
| V24 | 393 × 852 | default | 443.0 | 86.9 | |
| V24 | 402 × 874 | default | 465.0 | 89.6 | |
| V24 | 428 × 926 | default | 517.0 | 97.2 | |
| V24 | 440 × 956 | default | 547.0 | 100.7 | |
| V24 | 375 × 667 | largest | 279.0 | 50.2 | |
| V24 | 390 × 844 | largest | 422.0 | 86.1 | |
| V24 | 393 × 852 | largest | 430.0 | 86.9 | |
| V24 | 402 × 874 | largest | 452.0 | 89.6 | |
| V24 | 428 × 926 | largest | 504.0 | 97.2 | |
| V24 | 440 × 956 | largest | 534.0 | 100.7 | |

On the SE, Wake is a short scroll below the first view (F3-3).

### B2. V05b's bar

**What differed from the board:** the track was grey and its stripes dark
and still; no gloss; the stops were 26 pt and shrank while pending; the
pennant floated without its pole; every row not done was greyed; no disc
or sparkles round the companion.

**Fix (`8ae5467`).** A warm track (new `warmTrack` token, light and dark)
with an inset top shadow; light stripes that travel; a gloss line; 28 pt
stops that pop into green ticks; the last stop 16 pt from the end with the
flag's pole standing on it and the pennant waving; a gold glow when full;
the running row in full colour with pulsing dots, rows not started faint;
the percentage at −2 letter spacing; the board's white disc and four
sparkles round the companion. Loops stop with Reduce Motion.
**Test:** `test/fix3_ready_bar_test.dart`, the bar's geometry in light and
dark (fill 26 pt; stops 28 pt at 1/3 and 2/3; the last 16 pt from the end;
the pole centred on it, its foot on the fill; the pennant at the pole).

### B3. V05's tilt

**Cause:** the tilt came from a per-goal list (−2, +2, +1.5, −1.5); with
School added, cards 2 and 3 leaned the same way. **Fix (`66aeca3`):**
`GoalCard.tiltFor(position)`: +2° for even positions, −2° for odd, so
right, left, right, left whatever the goals. **Test:**
`test/fix3_goal_tilt_test.dart`.

### B4. One shared shine

**Cause of the device's small square:** `PressableButton` laid the band
out in a `Stack` sized by the label (inside the face's padding), and the
skew was passed as a tangent to `Matrix4.skewX`, which takes an angle.
**Fix (`1535036`):** `ButtonShine` is the one implementation: a band the
face's full height, 38 % of its width, skewed −20°, white 0 → 50 % → 0,
travelling from −140 % to +320 % of its width in the first 55 % of a 3 s
loop, clipped to the button's shape. `PressableButton` lays it over its
whole face; the paywall's `CtaGlow` uses the same widget. **Test:**
`test/fix3_button_shine_test.dart` (full height, 38 %, −20°, clipped).

Buttons that shine: Welcome "Get started" (V02); the buddy picker's "Climb
with <Hero>" (V03); the lucky wheel's button (V03b); the goal screen's
Continue once a goal is picked (V05); "Take my first step" (V06); the Daily
Test card's button (X05, V14); the results' "Climb my first step" (V10);
the month card's button (R04); "Wake <Hero> up" (V24f); the paywall's CTA
through `CtaGlow` (V13, V13r).

### B5. Switches

**Cause:** no theme-level switch style; Material 3's default thumb is dark
on this palette. **Fix (`3cf7f99`):** `buildAppTheme` sets
`appSwitchTheme` for light and dark: a white thumb in both states (full
size when off), the track navy when on and the `track` token when off, no
outline. N03 drops its own override; V24f's reminder row keeps its green
track (F3-6). **Test:** `test/fix3_switch_theme_test.dart`.

### B6. V06's flag on each art's apex

**Cause:** the pole stood on the trail's last point, which is under the
peak: about 0.02 image widths right of it and 0.07 below. **Fix
(`e1aea44`):** `tool/scene_art/summit_apex.py` measures every monthly
mountain image (light and dark): the sky colour per row from the window's
outer columns, the mountain as the region connected to a seed under the
peak, its highest row's middle column. It writes
`lib/widgets/monthly_climb/climb_summit_table.dart` next to the trail
table, and `MountainScene.flagPointFor(theme, brightness)` stands the
pole's foot on that point, 6 px of art into it (F3-7). Measured (px of
1536 × 2048): Green Slope (791, 234) / dark (783, 233); Ember Peak
(784, 229) / (782, 230); Glacier Peak (782, 223) / (780, 224); Red Canyon
(785, 224) / (790, 224). Checked by eye on zoomed crops and on the V06
captures. **Tests:** `test/fix3_summit_apex_test.dart`: every ready
theme's two images have a row; the apex is above the trail's end; the
image's pixels are mountain at and under the point and sky 6 px above it
across ±40 px (decoded from the asset, so a new art fails until it is
measured); V06 for each theme in light and dark puts the pole's foot on
the point with the whole flag in the scene. `fix_round2_summit_flag_test`
now checks the apex at four sizes. Captures:
`build/fix3-captures/(dark/)V06-<theme>-<month>.png`, this month (November,
Ember Peak) and October, December, January.

### B7. V18 practice loading

**What was wrong (weak-spot practice on the device):** the skeletons were
narrower than the hint card, the weak spot's name sat at the top left as a
big title, and the hint card was yellow. **Cause:** `PageLoading` drew each
page's header over the preparing view, and `PracticePreparing` followed an
older layout (three skeletons in a centred column, a gold card).
**Fix (`0508d39`):** one V18 for topic, ticket and weak-spot practice, as
on the board: no page title; a 130 pt thinking companion over three
pulsing navy dots; the message "Writing 3 questions on <topic>…" (new
string `practicePreparingTopic`, 8 languages; the count comes from
`launchPracticeSet`, F3-8); two skeleton cards (bars 40/90/70 %, 14 pt)
and the hint card in one column at the content's width, 16 pt apart; the
hint card on the sky card with a navy "DID YOU KNOW?" and a pager. The
weak-spot page keeps its back button (F3-9). **Tests:**
`test/fix3_v18_preparing_test.dart` drives both entry points for real
(Topic Practice and the weak spot's "Use today's ticket", generation held
open) in light and dark: no text above the companion, the cards one width
(the content's), two skeletons, the sky card, the message; and a page
header passed with a topic (Review's ticket) is not drawn. Captures:
`V18-topic`, `V18-weakspot` (light and dark).

### B8. The expression kit everywhere

**What was wrong:** five uses hid their prop (`companion_dialog`,
`error_state`, `medal_celebration`, `lucky_wheel_screen`,
`daily_test_card`'s loading state), so the sad dialogs had no cloud, and
three moods differed from their boards (R03 think, N01 wave, V21's upsell
wave; the boards draw the base pose). The Daily Test's wrong answers
already used `oops` (V09, Q04, Q05 share its feedback panel); practice
has no per-answer moment (F3-10).

**Fix (`2a668a0`).** Every `CompanionView` use was compared with its board
(the board's image: `<hero>_<mood>.webp`, or `avatar_NN.webp` for the base
pose) and SPEC's screen text. The five hidden props show again; R03, N01
and V21's upsell use the base pose. The Daily Test footer's
`showProp: hasAnswer` went (idle has no prop, so it did nothing).
`prop_tear.webp` stays unused: X01's kit has five props (sparkle, thought,
cloud, Zzz, sweat) and no board uses a tear; it is not deleted.

| Screen | Board | Mood | Prop |
|---|---|---|---|
| V02 Welcome trio (`welcome_screen`) | V02: fox, frog, panda wave | wave (Fox sways; sides float) | — (wave has none) |
| V03 Meet turntable (`buddy_picker`) | V03: fox wave | wave | — |
| V03b wheel, landed (`lucky_wheel_screen`) | V03b: frog cheer | cheer | sparkle ✱ (was hidden) |
| V04 Name (`name_companion_stage`, C2) | V04/V04s (v11): wave → inspect → cheer | wave / inspect / cheer (one hop) | **hidden**: the board's three sparkles replace cheer's one (F3-16) |
| V05 goal pop-out (`onboarding_screen` `_PopOut`) | V05: fox cheer | cheer | sparkle |
| V05b Getting ready (`getting_ready_screen`) | V05b: fox inspect, fox cheer | inspect → cheer | sparkle at cheer |
| V06, V12 pawn (`mountain_scene`) | base pose | idle; cheer on V12's arrival | sparkle on arrival |
| V07, V08 footer (`daily_test_screen` `_CheckFooter`) | V07 base, V08 fox cheer | idle → cheer once answered | sparkle at cheer |
| V08 right / V09, Q04, Q05 wrong (`_FeedbackPanel`) | V08 fox cheer; V09 base (SPEC v11: oops) | cheer / oops | sparkle / sweat, head shake |
| V10 Results (`daily_test_result_screen`) | V10: fox cheer | cheer | sparkle |
| V11 badge, R05 medal (`medal_celebration`) | V11, R05: fox cheer | cheer | sparkle ✱ (was hidden) |
| V13 paywall trio (`premium_screen` `_AvatarHero`) | V13: base poses | idle (sides float, middle hops) | — |
| V13c comparison (`premium_screen`) | V13c: fox cheer | cheer (hop) | sparkle |
| V13r rest paywall (`premium_screen` `_RestTop`) | V13r: fox wave | wave | — |
| V13b, R10, R08 reset (`companion_dialog`) | V13b, R10: fox sad | sad | cloud ✱ (was hidden) |
| X05, H03 card loading (`daily_test_card`) | X05: fox think | think | thought bubble ✱ (was hidden) |
| V14, V15 card to do (`daily_test_card`) | V14: base pose | idle, hopping | — |
| PW05, PW05r (`premium_on_screen`) | fox cheer | cheer (hop) | sparkle |
| V16 / RV05 Review empty (`review_parts`) | RV05: fox cheer | cheer (hop) | sparkle |
| R03 weak spot (`weak_spot_detail_screen`) | R03: base pose | idle ✱ (was think) | — |
| V18 Preparing (`practice_preparing`) | V18: fox think | think | thought bubble (F3-11) |
| V20 Reviewing (`practice_reviewing`) | V20: fox inspect | inspect | — |
| V21 Results (`results_screen`) | V21: fox cheer; upsell base pose | cheer; idle ✱ (was wave) | sparkle; — |
| V23 Profile stage (`profile_stage`) | V23: base pose | idle, wave on tap | — |
| PF04 Edit name (`settings_screen`) | PF04: fox wave | wave | — |
| V24 rest (`rest_scene`) | V24: fox sleep | sleep | Zzz |
| V24f rest, free (`rest_scene`) | V24f: fox sleep, dream bubble | sleep | **hidden**: the dream bubble replaces the Zzz (SPEC §3.5) |
| V24s waking (`rest_scene`) | V24s: fox wave, fox cheer | wave → cheer | sparkle at cheer |
| P08 daily limit (`practice_launch`) | P08: fox sleep | sleep | Zzz |
| R04, R04b month card (`month_card_sheet`) | fox cheer | cheer | sparkle |
| R09 Credits (`credits_screen`) | base poses; SPEC: the middle one waves | idle, wave, idle | — |
| R11 error (`error_state`) | R11: fox sad | sad | cloud ✱ (was hidden) |
| N01 soft ask (`reminder_soft_ask`) | N01: base pose | idle ✱ (was wave) | — |
| N03 notifications (`notification_settings_screen`) | N03: base pose | idle | — |

✱ = changed by B8. Props still hidden: V24f's Zzz (the board's dream
bubble takes its place) and V04's cheer sparkle (the board draws three of
its own). V05's small waving greeting chip is gone with C2 (its board has
none; the greeting is V04's now). Checked on renders that no newly shown prop
covers text: the dialog's cloud sits above the card; R11's cloud above the
head; the card's thought bubble beside the slot, above no text; the medal's
sparkle beside the head, under the medal.

**Tests:** `test/fix3_expression_kit_test.dart`: a wrong answer on V09 (fill
in the blank), Q05 (error correction) and Q04 (two blanks) shows `oops`
with the sweat drop and a head shake, and no cheer; the companion dialog
(V13b, R10, R08 reset share it) shows the sad companion's cloud over no
text (fails before B8); R11's error state shows its cloud. Captures:
`V09-oops`, `V13b-cloud`, `R11-cloud`.

### C1. Splash (V01)

**Change (`8ce54bd`).** The first launch takes 2.2 s (was 1.4 s, "rushed" on
the device): the icon assembles as before, the wordmark rises at 1 s, the
small lens scans the word from 1.15 s for 900 ms (was 300 ms), and the intro
ends at 2.2 s, then the 200 ms fade to the app. Later launches keep the
square and the wordmark only, 600 ms (F3-12). **Tests:**
`test/fix3_splash_test.dart` (the lens crosses the word left to right in its
window, gone after it; the intro ends at 2.2 s; a later launch shows no lens
and ends within 800 ms); `launch_gate_test`'s timing check follows v11.

### C2. The name screen (V04, V04s)

**Change (`c71aff4`).** `NameCompanionStage`: the companion 142 pt and
centred over a white disc in a warm radial glow that breathes (3.2 s), its
bubble above it (tail down, 18/900, pops on each change). Three states,
driven by the field: **asks** (empty: wave, "Hi! What should I call
you?", Continue disabled), **listens** (typing: inspect, three navy dots),
**greets** (700 ms after the last key with a valid name: cheer, one hop,
the board's three sparkles, "Nice to meet you, <name>!" with the name in
orange and cut to 16 characters + "…", a green tick at the field's end, a
light haptic once per name). Typing again listens; clearing asks. The field
has the board's 3 pt navy border and 6 pt sky focus ring, 24/800 text, and
the note with an n/40 counter beside it. Validation unchanged (trimmed,
not empty, 40 at most). New string `onboardingNameAsk` (8 languages); the
greeting reuses `onboardingNiceToMeet` (F3-13). Opening: the companion rises
12 pt with a fade (300 ms), the bubble pops (350 ms). Reduce Motion: no
hop, no glow loop, no rise or pop. **Tests:**
`test/fix3_name_screen_test.dart`: asks → listens → (not at 650 ms) greets
at 700 ms → listens again → greets (a new name: a second haptic; a name
already greeted: none) → asks; spaces only never greet; the 16-character
cut with the field whole; the board's layout (142 pt, centred, the bubble
13 pt above, the glow under the companion); the bubble in all 8 languages
at the largest text size with a 20-character name (no overflow, inside
the screen). Captures: `V04-asks`, `V04-listens`, `V04-greets` (light and
dark).

### C3. V12's bubble

**Change (`7c02cd6`).** `AnchoredBubble` places "First step done! 29 to the
summit." from the companion's box in the wide shot (the scene's own
mapping): the tail's tip 12 pt above the head and under its centre, the
bubble ≥ 16 pt from the screen's sides and between the step chip and
Continue (8 pt off each, measured after layout); below with the tail up
when there is no room above, else the side with more room. It fades in
with Continue when the camera has opened back up. **Tests:**
`test/fix3_v12_bubble_test.dart` on the real V12 at 375 × 667, 390 × 844,
393 × 852, 402 × 874, 428 × 926 and 440 × 956 (tip 12 pt above the head,
tail under the centre, inside the edges, between chip and button), and the
bubble alone opening below a companion near the top and clamped at a screen
edge with the tail still over the companion. Captures: `V12-end-<size>`
(and dark at 390 × 844).

### C4. Paywall order (V13 → V13c → V13a)

**Change (`480f175`).** The page now reads: the first view (unchanged, no
price boxes) → the "Compare plans" hint (new string, 8 languages; "See
plans" removed) → Free vs Premium with its companion and the "Cancel
anytime" note → a "Choose your plan" hint → "Choose your plan" (20/900) and
the plan rows → the trial timeline. Both hints are the boards' small grey
label over a chevron, floating every 1.8 s, and scroll to their section.
The pinned button and its full price line are unchanged and always on
screen; the yearly plan stays preselected and drives the button and the
line from the first view. In each plan row the billed amount was already
the largest text (titleLarge 900; the monthly equivalent and the struck-out
price are label size). V13r shares the page, so it has the same order
under its rest top. **Tests** (`premium_screen_test`, group "C4"): the first
view (the hint above the footer, no plan box above the footer, "Start my
7-day free trial" and the yearly price line); the order down the page; the
button and the price line still on screen at the page's end; the billed
amount larger than every other text in each plan row (live prices); V13r's
order. The two older tests that encoded 13 → 13a → 13c follow v11. iPad
(App Review uses one): the first view on the iPad Pro 13" simulator, light
and dark (`build/fix3-captures/iPad-V13-Paywall*.png`): the page in its
640 pt column, "Compare plans" and the start of Free vs Premium on the
first view, the pinned button, its price line and the links in view.

### C5. Profile ribbon (V23)

**Change (`78a1bd1`).** The ribbon, tails included, is the screen's width −
60 (330 at 390, 368 at 428; on a tablet, no wider than the page's column),
replacing fix round 2's fixed 286 pt body. The name and the "Climbing with"
line each stay on one line (`OneLineText`): a line that does not fit
shrinks, to 85 % at most, then ends with "…". 62 pt tall at the default
text size. **Tests:** `test/fix3_profile_ribbon_test.dart` at 375 × 667,
390 × 844, 402 × 874, 428 × 926 and 440 × 956, default and largest text
(width, centred, 62 pt, one line each at ≥ 85 %), and a long name (85 %,
"…"); `fix_round2_profile_test` follows the new width. Captures:
`V23-ribbon-<size>-<text>`.

### C6. Pose changes

**Change (`73913f8`).** In `CompanionView`: a change of pose cross-fades
(200 ms by default; V24s keeps its 400 ms for falling asleep) and the new
pose scales 0.96 → 1; under Reduce Motion a plain 150 ms fade instead of a
cut. Every screen gets it: Profile's wave on tap, the rest scene's wake,
V04's three states, V05b. A `cheerHops` option (two by default, V04 one).
**Test:** `test/fix3_pose_switch_test.dart` (both poses for 200 ms, the old
one only fading, the new one from 0.96 to 1; Reduce Motion: 150 ms, no
scale).

### D. Dark mode (SY03)

**What was wrong:** navy text and icons stayed navy on the dark page and
cards (1.5–1.8:1); the right answer's chip was dark green on a dark green
fill (2.1:1), the wrong answer's red on its fill 4.0:1; gold text 2.2:1;
orange eyebrows 3.2–3.6:1.

**1. Inventory.** The colours come from three places:
- `AppColors` (the UI polish tokens, light and dark sets): text, muted,
  the accents (orange, navy, green, red, gold), their deep and soft
  variants and their `on…` text, lip, line, page, card, track, skeleton,
  toast, the night sky. Accents were the same in both themes and used both
  as fills and as text.
- The Material `ColorScheme` (`theme.dart`), which the older screens and
  the paywall read; it already had dark roles (e.g. `secondary` is a light
  blue in dark).
- Colours written in widgets: shadows and scrims (black or white with
  alpha), gloss bands (white with alpha), the medal tiers and the medal
  celebration's palette (art on its own navy layer, the same in both
  themes), the blanks' colours (already a light and a dark set), the
  companion stage's ground shadow. None of them is text on a themed
  surface, so none moved to a token.

**2. Dark counterparts (`5e828ad`).** New text tokens, each a light-mode
accent and its light counterpart on dark surfaces: `navyText` (#0D3B8F /
#9DB8FF), `orangeText` (#A14805 / #FFA463), `goldText` (#8A5C00 /
#F2C66B), `greenText` (#13734A / #7FD6A6), `redText` (#B83232 / #FF9C92).
About sixty uses of navy, orangeDeep, goldDeep, greenDeep and red as text,
icons, outlines, dots and progress strokes moved to them; fills that carry
white text keep navy, orange and red (buttons, chips, the ribbon, the
Premium card, the toast's discs). Dark values changed by SY03: greenSoft
#173A2A with #7FD6A6 text, redSoft #42201F with #FF9C92 text, the card lip
#2E2C36 (a lighter line instead of a shadow colour); dark green and red
were brighter than the light ones and white ticks and labels on them failed
(2.6:1, 3.6:1), so they now match light's strength (#1F9D63, #C93A3A). The
warning toast's "!" is dark ink on its orange disc (white was 2.5:1, in
both themes). Page and card keep D1-1's values (every ratio passes). B5's
switch track became a value map in the same pass (`1c0ea98`): as a closure
it made every build of the theme unequal, so `AnimatedTheme` animated on
each rebuild.

**3. The ratio test.** `test/fix3_contrast_test.dart` measures every pair
below in both themes (WCAG relative luminance; translucent colours blended
on their background): text at least 4.5:1 (large text is held to 4.5 too),
icons at least 3:1; and the colour scheme's text roles at 4.5:1. All pass.

| Foreground | Background | Role | Light | Dark | Min |
|---|---|---|---|---|---|
| text | page | text | 14.96 | 15.51 | 4.5 |
| muted | page | text | 6.43 | 7.63 | 4.5 |
| text | card | text | 16.64 | 13.00 | 4.5 |
| muted | card | text | 7.15 | 6.39 | 4.5 |
| text | sky | text | 13.70 | 10.00 | 4.5 |
| muted | sky | text | 5.88 | 4.92 | 4.5 |
| text | cream | text | 15.48 | 11.69 | 4.5 |
| muted | cream | text | 6.65 | 5.75 | 4.5 |
| text | orangeSoft | text | 14.04 | 11.69 | 4.5 |
| muted | orangeSoft | text | 6.03 | 5.75 | 4.5 |
| text | goldSoft | text | 15.25 | 10.71 | 4.5 |
| muted | goldSoft | text | 6.55 | 5.27 | 4.5 |
| text | greenSoft | text | 14.76 | 10.66 | 4.5 |
| muted | greenSoft | text | 6.34 | 5.24 | 4.5 |
| text | redSoft | text | 14.39 | 12.25 | 4.5 |
| muted | redSoft | text | 6.18 | 6.02 | 4.5 |
| text | lilac | text | 14.21 | 12.02 | 4.5 |
| muted | lilac | text | 6.10 | 5.92 | 4.5 |
| navyText | page | text | 8.97 | 9.32 | 4.5 |
| orangeText | page | text | 5.31 | 9.33 | 4.5 |
| goldText | page | text | 5.07 | 11.35 | 4.5 |
| greenText | page | text | 5.11 | 10.48 | 4.5 |
| redText | page | text | 5.17 | 9.05 | 4.5 |
| green (icons) | page | icon | 3.02 | 5.26 | 3.0 |
| red (icons) | page | icon | 5.17 | 3.60 | 3.0 |
| navyText | card | text | 9.98 | 7.81 | 4.5 |
| orangeText | card | text | 5.91 | 7.82 | 4.5 |
| goldText | card | text | 5.64 | 9.51 | 4.5 |
| greenText | card | text | 5.69 | 8.79 | 4.5 |
| redText | card | text | 5.75 | 7.59 | 4.5 |
| green (icons) | card | icon | 3.36 | 4.41 | 3.0 |
| red (icons) | card | icon | 5.75 | 3.02 | 3.0 |
| navyText | sky | text | 8.22 | 6.01 | 4.5 |
| orangeText | orangeSoft | text | 4.99 | 7.03 | 4.5 |
| orangeText | cream | text | 5.50 | 7.03 | 4.5 |
| goldText | goldSoft | text | 5.17 | 7.83 | 4.5 |
| greenText | greenSoft | text | 5.04 | 7.21 | 4.5 |
| redText | redSoft | text | 4.97 | 7.15 | 4.5 |
| onSky | sky | text | 10.23 | 9.04 | 4.5 |
| onGreenSoft | greenSoft | text | 5.04 | 7.21 | 4.5 |
| onRedSoft | redSoft | text | 7.33 | 7.15 | 4.5 |
| onLilac | lilac | text | 6.83 | 9.15 | 4.5 |
| onNavy | navy | text | 10.30 | 10.30 | 4.5 |
| onNavyMuted | navy | text | 8.37 | 8.37 | 4.5 |
| onRibbonMuted | navy (ribbon) | text | 7.13 | 7.13 | 4.5 |
| onRibbonMuted | ribbonTop | text | 5.21 | 5.21 | 4.5 |
| onOrange | orange | text | 6.93 | 6.93 | 4.5 |
| onNavy (white) | red (button) | text | 5.93 | 5.06 | 4.5 |
| onNavy (white) | greenDeep (button) | text | 5.87 | 5.87 | 4.5 |
| onNavy (white tick) | green (disc) | icon | 3.46 | 3.46 | 3.0 |
| onToast | toast | text | 13.15 | 9.96 | 4.5 |
| onOrange (warning "!") | orange (disc) | icon | 6.93 | 6.93 | 3.0 |
| text | night sheet (top) | text | 15.24 | 18.53 | 4.5 |
| scheme: onSurface | surfaceContainerLow | text | 14.96 | 15.51 | 4.5 |
| scheme: onSurface | surfaceContainerHigh | text | 16.64 | 13.00 | 4.5 |
| scheme: onSurfaceVariant | surfaceContainerLow | text | 8.14 | 10.75 | 4.5 |
| scheme: onSurfaceVariant | surfaceContainerHigh | text | 9.05 | 9.01 | 4.5 |
| scheme: secondary | surfaceContainerLow | text | 8.97 | 10.98 | 4.5 |
| scheme: secondary | surfaceContainerHigh | text | 9.98 | 9.20 | 4.5 |
| scheme: onSecondaryContainer | secondaryContainer | text | 9.79 | 9.04 | 4.5 |
| scheme: onPrimary | primary | text | 6.93 | 7.71 | 4.5 |

Not in the test (graphics, not text or icons): borders, progress segments
and rings, e.g. the wrong answer's soft orange border and segment
(`wrong`, #E38B5A: 2.5:1 on the light card; the boards' colour, unchanged),
the orange bars and the empty tracks.

**4. Dark captures.** Every gallery board (72, with their extra frames: 99
images) captured in dark on the iPhone 18 Pro simulator into
`build/fix3-captures/dark/` (`<board>-dark*.png`), plus the widget-test
renders of the boards the gallery does not cover (V04's states, V06 for
four months, V09's oops, V13b's cloud, V18 from both entry points, V23's
ribbon, V24 / V24f at six sizes, V01, V05, N03). Looked at each. Hard to
read and fixed: R10's red "Leave" on the dialog card (the danger button
used the red fill colour, 3.0:1 → `redText`, `6d3f83d`); PF02's Silver and
Bronze counters (light fills with dark text on the dark layer → dark tints,
`71cd9c7`). Found on the way: the gallery's V13a and V13c shots were
swapped by C4's new order (`85fab62`). Everything else reads: navy text,
links and eyebrows are light blue, the right/wrong chips and the "Almost!"
panel are dark tints with light text, soft cards are dark tints, the art is
unchanged. Those three boards were captured again after the fixes.

### Decisions (F3-n)

- **F3-1. R05's order.** Question: should a later day's tier medal also
  wait for a button, like the Welcome badge? Options: (a) keep it opening
  over the results when the save lands; (b) open it from the results'
  button. Choice: (a). Why: SPEC R05 says it opens "right after the Daily
  Test results"; v11 changed only V10 → V11 → V12, and FIX3 keeps R05 as it
  is unless SPEC says otherwise.
- **F3-2. The Xcode script and the owner's team.** Question:
  `tool/ios/configure_xcode_project.rb` removed `DEVELOPMENT_TEAM` and the
  other signing keys from the widget target on every run, so the next run
  would undo E1. Options: (a) leave it; (b) strip signing keys only when
  the script creates the target. Choice: (b). Why: the owner's own setting
  must survive; a new target still gets no signing setting from the run.
  The dry run now says "Nothing to change."
- **F3-3. V24f on the 375 × 667 SE.** Question: the camp, its 12 pt and the
  bubble band leave no room for Wake above the bar on the first view (33 pt
  short at default text, 51 pt at the largest). Options: (a) scale the art
  down; (b) give up the camp's 12 pt; (c) let the page scroll. Choice: (c).
  Why: FIX3 forbids (a) and (b); the scroll is short and the card stays
  whole. Every other size keeps Wake on the first view.
- **F3-4. The rest scene's fit.** Question: how to place the sheet so the
  anchor ends 8 pt above the bar at any size and text size. Options: (a)
  fixed sheet tops per board; (b) measure the anchor after layout and
  re-place the sheet. Choice: (b), clamped between the camp's minimum and
  the board's gap. Why: the sheet's content height depends on the text
  size and the store's trial line; fixed numbers broke at the largest text.
- **F3-5. Where V24's anchor is.** V24 has no Wake button; its sheet's last
  row (the reminder row) is the anchor. Why: same rule as V24f, the whole
  sheet on the first view.
- **F3-6. V24f's switch colour.** Options: (a) the theme's navy track; (b)
  the board's green track on the reminder row. Choice: (b). Why: rule 3,
  V24f's board draws it green on the night sheet; the thumb is the theme's
  white either way.
- **F3-7. Where the pole's foot stands.** Options: (a) on the measured
  point (the first non-sky pixel); (b) a few pixels into it. Choice: (b),
  6 px of the 1536 px art (about 1.6 pt on V06). Why: the outline is
  anti-aliased; on it the foot reads as floating. The tool is plain Python
  plus ImageMagick: the scene-art venv (PIL) is not installed, and adding
  it would add a package.
- **F3-8. V18's message.** Options: (a) keep "Preparing your questions…";
  (b) the board's "Writing 3 questions on superlatives…". Choice: (b), a
  new string with the count and the topic's title in 8 languages. Why:
  rule 3 (the board) comes before rule 4 (the app's current text). The
  topic's title keeps its own capitals ("on Gerund vs. Infinitive…"):
  lower-casing it is not safe across the languages (German nouns).
  "Preparing your questions…" stays the fallback when no count is known.
- **F3-9. V18's way out.** The board shows no navigation. Options: (a)
  remove the weak-spot page's back button while generating; (b) keep it.
  Choice: (b). Why: rule 4, the app's current behaviour; generation can
  take several seconds and the button is the only way out. Topic Practice
  and Review had none and still have none.
- **F3-10. "Practice wrong" (SPEC §3.5).** Practice answers are evaluated
  together at the end (V19), so no companion reacts to a single wrong
  practice answer; V21's board draws the companion cheering beside "2/3
  correct". Options: (a) leave V21's cheer; (b) switch V21 to oops when
  anything was wrong. Choice: (a). Why: rule 3, V21's board and SPEC V21
  ("Companion cheers"); the wrong-answer `oops` covers every place that
  reacts to one answer (V09, Q04, Q05).
- **F3-11. V18's thought bubble.** The V18 board draws the thinking pose
  without a bubble (with three dots under it). Options: (a) hide the
  bubble; (b) show it. Choice: (b). Why: SPEC §3.5 v11 shows each mood's
  prop unless the board replaces it or it covers text; the boards were
  drawn before the kit, and the dots sit under the companion, not where
  the bubble goes.
- **F3-12. Later launches' splash.** SPEC: at most 800 ms. Options: (a) keep
  600 ms; (b) lengthen to 800 ms. Choice: (a). Why: within the limit, the
  device test did not mention later launches, and daily users open the app
  every day (rule 5).
- **F3-13. The greeting's string.** "Nice to meet you, {name}!" already
  existed in all 8 languages (`onboardingNiceToMeet`), shown on V05's small
  greeting chip. Options: (a) a new key and keep V05's chip; (b) reuse the
  key on V04 and drop V05's chip. Choice: (b). Why: V05's board has no chip
  and v11 moves the greeting to V04 (rule 3); both would greet twice. The
  key's description now names V04.
- **F3-14. V04's hop.** SPEC: "cheer pose, one hop"; the board loops
  `gl-hop`. Choice: one hop, then still (the sparkles and the glow keep
  moving). Why: rule 2 (SPEC) before rule 3 (the board).
- **F3-15. "Once per name".** Options: (a) once per greeting of a name
  different from the last; (b) once per distinct name while the screen is
  open. Choice: (b), a set of the names greeted. Why: "Ada" → "Adam" →
  "Ada" would otherwise buzz three times for two names.
- **F3-16. V04's props.** The board draws three sparkles round the
  greeting companion where cheer's kit sparkle would sit. Choice: the
  board's three, the kit's hidden (listed in B8's table). Back from V05,
  V04 opens greeting the name already given, without a haptic.
- **F3-17. V12's bubble limits.** SPEC gives the gap and the edges, not the
  vertical limits. Choice: between the step chip and Continue, 8 pt off
  each, measured after layout; when neither side fits, the side with more
  room. Why: the chips and the button stay readable (rule 5).
- **F3-18. C4's second hint.** The V13c board's hint under the note reads
  "Choose your plan", the same words as V13a's title. Choice: reuse
  `paywallChoosePlan` for both; "See plans" (`paywallSeePlans`) is removed
  from the 8 ARB files since nothing uses it.
- **F3-19. The plan label over the pinned button.** Fix round 2 shows the
  selected plan's name above the button once the plans have scrolled out
  of view upwards. Kept: with the plans at the page's end it shows only
  when the timeline is scrolled to the top. Why: rule 4, harmless.
- **F3-20. The ribbon on a tablet.** "Screen width − 60" would be about
  960 pt on an iPad. Choice: no wider than the page's column (640 pt).
  Why: rule 5; the stage above it is that wide.
- **F3-21. Paywall hint taps.** The boards draw the hints as decorations
  (`aria-hidden`). Choice: they stay buttons (scroll to their section, 44 pt
  to tap), as "See plans" was. Why: rule 4.
- **F3-22. Orange text in light mode.** The 4.5:1 rule is for both themes;
  the boards' #C95A08 measures 3.5–4.1:1 on the light page, cards and soft
  fills, where it sets 12–13 pt eyebrows. Options: (a) keep it (light was
  approved); (b) a darker orange for text only. Choice: (b), #A14805
  (4.9:1 or more on every light surface); the button lip and fills keep
  #C95A08. Why: SPEC §1.19 / SY03's ratio is the rule (rule 1, 2).
- **F3-23. Navy in dark mode.** Options: (a) make `navy` itself light blue
  in dark and add a fill token; (b) keep `navy` as the fill (white text,
  10.3:1) and add `navyText`. Choice: (b). Why: SY03 says navy stays a fill
  where white text sits on it; fewer uses change.
- **F3-24. Dark green and red.** SY03 gives the soft fills and their text,
  not the solid accents. Their brighter dark values failed under white
  content; they now match the light ones' strength. Why: the ratio rule;
  both still read on the dark page (5.3:1, 3.6:1 as graphics).
- **F3-25. Dark lip and line.** SY03: "a lighter line (#2E2C36 or so)
  instead of the light shadow colour". The lip becomes #2E2C36; the border
  line keeps #45454D (already lighter than the card).
- **F3-26. "Compare plans" on 6.1"–6.3" phones.** The app's first view is
  taller than the board's (the GRAMMARLENS PREMIUM label over the
  headline, the supporting line, and a pinned footer with "Maybe later"),
  so at 390–402 pt wide the hint sits just under the footer, as "See plans"
  did since fix round 2; from 6.7" up it is on the first view. Options: (a)
  reshape the first view to fit it; (b) keep it. Choice: (b) for this
  round. Why: C4 asked for the order, the hint's text and the pinned button;
  reshaping the first view is outside it (rule 5); recorded for the owner.

### Checks: the listed captures against their boards

Light renders in `build/fix3-captures/`, dark in `build/fix3-captures/dark/`
(widget-test renders at a phone's size with the app's font, `FIX3_CAPTURE=1`,
and the gallery on the iPhone 18 Pro simulator, `<board>[-dark].png`).
"Match" means the board's layout, colours, copy and motion state as far as
a still shows them; differences are listed.

| Board | Light | Dark | Result |
|---|---|---|---|
| V01 (two frames) | `V01-frame1-icon`, `V01-frame2-scan`; gallery `V01-Splash(-mid)` | same names | match: the square, the lens, then the wordmark with the small lens crossing it (C1's timing) |
| V04 (three states) | `V04-asks`, `V04-listens`, `V04-greets` | same | match (the glow, the disc, the bubble above, the dots, the tick, n/40) |
| V05 (each card selected) | `V05-examPrep`, `-work`, `-school`, `-general` | same | match: the frame, the lift, the tilt by position, the reaction line, the pop-out companion. Differences kept from earlier rounds: "3 of 4" (the app's four onboarding steps), the subline, the privacy note |
| V05b | gallery `V05b-GettingReady(-100)` | same | match (B2's bar); at a stop the companion thinks (SPEC §1.16's waiting state), as designed |
| V06 (this month and two others) | `V06-ember_peak-november`, `-glacier_peak-december`, `-red_canyon-january`, `-green_slope-october` | same | match: the flag on each summit's apex |
| V10 → V11 (two frames) | gallery `V10-Results`, `V11-Badge`; the order: the A1 flow test and the smoke walk | same | match (the gallery's V10 is a later day: "Today's test complete!", "See your climb") |
| V12 (end frame) | `V12-end-<size>` (six sizes), gallery `V12-Climb` | `V12-end-390x844`, gallery | the bubble: match (C3). Differences outside C3: Continue is orange (board: white), the step chip gold with a flag (board: orange with an arrow), the mountain's name chip, the walked trail painted solid (board: white dots) |
| V13 | gallery `V13-Paywall(-t2)`; iPad Pro 13" `iPad-V13-Paywall` | same; `iPad-V13-Paywall-dark` | match apart from the hint: at 390–402 pt wide the first view ends with the benefits card and "Compare plans" sits just under the pinned footer (it shows from 6.7" up: 8 pt clear at 428 × 926); the footer is taller than the board's ("Maybe later", the links row). Kept (F3-26) |
| V13c, V13a | gallery `V13c-PaywallCompare`, `V13a-PaywallPlans` (light captured after the offset fix) | gallery (before the fix the two names were swapped; see D) | match: 13c then 13a, the billed price largest, the pinned button and price line |
| V18 (both entry points) | `V18-topic`, `V18-weakspot` | same | match, with the thought bubble on the companion (F3-11) and the count in the message |
| V23 | `V23-ribbon-<size>-<text>`, gallery `V23-Profile(-420)` | `V23-ribbon-428x926`, gallery | match (C5) |
| V24f, V24 (five sizes) | `V24f-<size>-medium/large`, `V24-<size>-medium/large` | `V24f-<size>-medium`, `V24-<size>-medium` | match (B1); on the 375 × 667 SE Wake is a short scroll (F3-3) |
| N03 | `N03` | `N03` | match: white thumbs, the navy track when on (B5) |
| A wrong answer with oops | `V09-oops`, gallery `V09-Wrong` | same | match per SPEC v11 (the board draws the base pose; v11 says oops) |
| V13b with the cloud | `V13b-cloud`, gallery `V13b-ExitReminder` | same | match per SPEC v11 (the cloud over the sad companion) |

### Checks: builds and tests

After the last code change (`ee40468`; the run at `cd88b12`, which only
added docs since):
- `flutter analyze`: no issues.
- `flutter test`: 2742 passed, 0 failed.
- Swift tests (`xcodebuild test`, scheme Runner, RunnerTests with the widget
  snapshots, iPhone 18 Pro simulator, parallel testing off): 22 executed,
  0 failures, TEST SUCCEEDED.
- Simulator build of Runner with the widget extension (`xcodebuild build`):
  BUILD SUCCEEDED.
- `flutter build ios --release --no-codesign`: built `Runner.app` (50.1 MB,
  arm64, 1.4.0 (7)) with `GrammarLensWidgets.appex` inside.

One full-suite run during the round failed one layout test
(`l10n_layout_test` "pt at 320 pt, Large Profile") while an Xcode build ran
beside it; the test passed alone, as a file, and in the final run above.

**Disk.** 8.5 GiB free at the start, 11 GiB after §0's cleanup. Mid-run the
disk filled (680 MiB free: the simulators, including another booted
simulator not from this run, and Xcode's shared caches had grown); only the
allowed items were deleted then (`build/ios`, this project's DerivedData).
At the end: `flutter clean` (the captures in `build/fix3-captures/` moved
aside and back) and the DerivedData folders whose WorkspacePath is in
`~/GrammarLens` (`Runner-gqpsqce…` 1.7 GB, `Runner-ghmgufz…`); two `Runner-*`
folders without an info.plist were left alone. Free after: **19 GiB**
(the target was 15).

### Checks: the smoke walk

Driven by `tool/ui_polish/smoke_driver.dart` (Flutter Driver, simulator
screenshots after each step) on the seeded app with no seeding, with a
local stand-in for the practice proxy (canned items and feedback on
localhost; no AI call). The full walk: `build/fix3-captures/smoke3/`, a first install on
the iPhone Air simulator (420 × 912), the app in English (`SEED_LANGUAGE`).
Earlier attempts, kept: `smoke/` (iPhone 18 Pro, no profile or test in its
data, stopped at the last step, see below) and `smoke2/` (the iPhone 18 Pro
Max, which runs in Turkish; stopped after onboarding because the driver's
later steps tap English labels).

What was seen, in order: Welcome; the name screen asking ("Hi! What should
I call you?", wave, Continue disabled, 0/40), then greeting after "Ada"
(cheer, sparkles, the name in orange, the green tick, 3/40); the goals with
Work picked (its frame, tilt and reaction line); getting ready (the striped
bar, ticks, the pole on the last stop); the mountain intro with the flag on
Ember Peak's summit; the Day 0 test's first answer wrong ("eat": oops with
the sweat drop, the red-tinted "Almost!" sheet); **the results first** ("Day
1 complete!", 4/5, "Climb my first step"), **then the Welcome badge**, then
the first climb with "First step done! 29 to the summit." right above the
companion; the paywall (first view) and the exit pop-up with the cloud;
Home; Review with the new weak spot and the ticket; the AI consent; the
practice (3 questions from the stand-in); the practice results.
Then **the A2 path**: on Review the ticket read "Used today"; a tap
on the Climb tab showed the free rest scene (V24f, "Fox is dreaming of…
Gerund vs. Infinitive") with N01 ("When do you have 2 minutes?") already
open in the first screenshot, 1.2 s after the tap, without another tab
switch.

The first walk's last step tapped the Climb tab while the practice results
(a route over the tabs) were open, and stopped there; the driver now goes
back through "Back to topics" first. The iPhone Air was shut down twice
under the first attempts (three simulators and two builds at once); with
one other simulator booted it ran the whole walk. The stand-in answers at once, so V18's loading screen is gone before
a screenshot; it is checked by its renders (B7).

### 5. Docs

Done: this section (each item's cause, fix and tests; decisions F3-1 to
F3-26; the checks; what is not verified) and the final summary's status;
`docs/build-log.md` (an entry for 2026-11-18); `docs/roadmap.md` (the UI
polish status: fix round 3 done on `ui-polish-widgets`, waiting for the
owner's second device pass, not on `main`, not shipped); `product.yaml`
(fix round 3 on top of `recent`, the oldest of the five dropped; the UI
polish `planned` line; `updated_at` 2026-11-18). No `legal`, `status` or
`versions` change: no package, service or data collected changed, so the
legal pages need no review for this round.

### 6. DEVICE-CHECKS.md

Done: a new first section, "Fix round 3 — second pass": FR3-1 build and
install (section 1's commands; no Xcode step now the team is set; over the
current test build), FR3-2 on this install (each item says whether today's
Daily Test must be done), FR3-3 before the next day's test, FR3-4 after a
delete and reinstall, in FIX3 §6's order and with every item it lists.

### Not verified

- **Anything on a device**: haptics (V04's greeting, the buttons), the real
  keyboard on V04, the splash's feel, performance, the dark mode walk on
  the phone's own screen, the widgets' "before the test" state. The second
  pass is the first section of `DEVICE-CHECKS.md`.
- **A2's exact moment on the phone**: the two causes found are fixed and the
  owner's path passes in the app-level tests and in the simulator walk;
  which refresh brought the rest scene on the phone could not be replayed.
- **375 × 667 and 428 × 926**: no such simulator; checked as widget-test
  renders at those sizes (B1, C3, C5).
- **The practice in the smoke walk** used a local stand-in for the proxy
  (canned items and feedback on localhost): no real generation or scoring,
  no paid call. No purchase (the seeded app has no store).
- **Contrast of graphics** (borders, progress segments, rings) is not in the
  ratio test; see D.

## Integration (branch `ui-polish-widgets`, 2026-11-17)

`INTEGRATE.md`: `ui-polish` (fix round 2, `7f38e21`) and
`widgets-notifications` (W1–W6, `37a94bd`) together on a new branch, the
parts each could not see connected, three gaps closed, one build and one
checklist for the owner's phone. **Status: steps 0–6 done** on
`ui-polish-widgets` (pushed). Not on `main`, not shipped, **not checked on a
device**: everything below ran on this Mac and the iPhone 18 Pro simulator
(iOS 27.2, 402 × 874). `ui-polish`, `widgets-notifications` and `main` were
not touched.

| Step | Status | Commits |
|---|---|---|
| 0 Disk | done | none (files outside git) |
| 1 Branch | done | `abd2bde` |
| 2 Merge | done | `c3d9cba` (merge), `dea05a4`, `90dd2a2` |
| 3a V24f's reminder row | done | `dea05a4`, `12e09b7`, `aa4557e` |
| 3b The pawn on 6.1"–6.3" | done | `12e09b7` |
| 3c Nunito Sans in the widgets | done | `7dc49b5` |
| 3d `TASK-widgets.md` in English | done, no change needed | none |
| 3e Release build check | done: builds | none |
| 4 Checks, captures, smoke walk | done | `ca642b2` (a fix it found) |
| 5 Docs | done | `4561ebc` |
| 6 `DEVICE-CHECKS.md` | done | `4561ebc` |

### 0. Disk

Free space on the data volume: **7.1 GiB before, 14 GiB after the
cleanup**, 11 GiB at the end of the run (after the simulator, release
and gallery builds; `flutter clean` frees it again).

Deleted, only what `INTEGRATE.md` §0 allows:

| What | Size | How |
|---|---|---|
| `~/GrammarLens`: `flutter clean` (`build/`, `.dart_tool/`, ephemeral files) | 2.2 GB `build/` + 88 MB | `flutter clean` |
| `~/GrammarLens-widgets`: `flutter clean` (its `build/` held old logs, `widget-snapshots/`, captures) | 2.4 GB `build/` + 476 MB | `flutter clean` |
| DerivedData `Runner-fdbimsrc…` (WorkspacePath `~/GrammarLens-widgets/ios/Runner.xcworkspace`) | 1.6 GB after the clean | `rm -rf`, path checked first |
| DerivedData `Runner-gqpsqce…` (`~/GrammarLens/ios/Runner.xcworkspace`) | 72 KB after the clean | same |
| DerivedData `Runner-ghmgufz…` (`~/GrammarLens/macos/Runner.xcworkspace`) | 72 KB | same |

Also stopped: a Crashlytics `upload-symbols` process left over from fix
round 2's gallery build, hanging for 4 hours on files in `build/`.

Not deleted, report only (the owner's call): DerivedData of other projects
(`Seher-…` 4.0 GB, `BirdApp-…` 1.2 GB, `Runner-adlzgt…` for ScanStash 1.1
GB), Xcode's shared caches (`ModuleCache.noindex` 1.9 GB,
`SDKExplicitPrecompiledModules` 850 MB), four small `Runner-*` folders whose
`info.plist` is missing (under 8 MB together), and the prunable worktree
`/private/tmp/grammarlens-140-build7` (worktree deletion is not allowed in
this run).

### 1. Branch

`ui-polish` was at `7f38e21` and up to date with origin; `git fetch`, then
`git switch -c ui-polish-widgets`; `INTEGRATE.md` committed as
"docs: integration task" (`abd2bde`) and pushed with `-u`.

### 2. Merge

`git merge --no-ff origin/widgets-notifications` (`37a94bd`; merge base
`ca3a847`, the SPEC v10 docs commit). Merge commit `c3d9cba`. Conflicts and
how each was resolved (both sides kept every time):

- **ARB files (8):** merged by key against the merge base. The widgets
  branch added 48 keys (96 lines with metadata in English), fix round 2
  added its own; **no key was added or changed on both sides**, so nothing
  needed SPEC v10's tie-break. The seven paywall keys fix round 2 removed
  (`paywallRow*`, `paywallFreePerDayShort`, `paywallHeader*`) stay removed;
  the widgets branch had not touched them. l10n tests pass.
- **`lib/widgets/rest_scene.dart`:** `RestScene` takes both `reminder`
  (widgets) and `offer` (V24f); V24 keeps the row under its countdown.
- **`lib/screens/home_screen.dart`:** Home passes `RestReminderRow` and keeps
  fix round 2's free/Premium test line.
- **`docs/build-log.md`:** both 2026-11-17 entries, the widgets one first
  (it was written earlier that day).
- Auto-merged without conflict: `docs/roadmap.md`, `product.yaml` (the
  widgets branch's `recent` entry on top, `recent` still five items),
  `settings_screen.dart`, `home_screen_test.dart`, `app.dart` and storage
  (the widgets branch's `DeviceSync`, reminder and link wiring sit next to
  fix round 2's changes; neither side edited the other's lines).

**A semantic conflict the merge could not show:** the widgets branch's N01
test expects the reminder row on the first rest scene of a *free* user,
which after fix round 2 is V24f, and V24f had no place for the row. The
first `flutter test` on the merge: 2595 passed, **1 failed** ("the first
rest scene opens N01 once; Not now is final"). Fixed before anything else
changed (`dea05a4`: the row under V24f's Premium card, as on the board).

**Database:** 1.4.0, the live App Store build (build 7, source `c37757a`),
stores schema **v26**; `ui-polish` did not change the schema; the widgets
branch moved it to **v27** (`reminder_settings`). An install over 1.4.0
therefore migrates in one step (`oldVersion < 27` creates the table; no
other step runs). New test `test/upgrade_from_140_test.dart` (`90dd2a2`):
1.4.0's `onCreate` frozen verbatim from `c37757a` as
`test/fixtures/storage_v26_140.sql` (19 tables), a row in every table,
opened by today's `StorageService`: v27 in one step, every row of every
table unchanged, the profile's name and goal kept, the retired Tiger
(`avatar_03`) read and stored as Fox (`avatar_14`), this month's and last
month's completions and the first test on record, weak spots by
frequency, October's silver and the Welcome badge, language, text size,
theme, review order, the AI permission, the device id and the month
themes; `reminder_settings` empty and read as the defaults (all off,
20:00, not asked). A current hero and the new School goal round-trip.

**Checks on the merge, before anything else changed:** `flutter analyze`
no issues; `flutter test` **2597 passed** (after `dea05a4`, `90dd2a2`);
Runner + `GrammarLensWidgets` simulator build **BUILD SUCCEEDED** (on
`c3d9cba`); Swift `xcodebuild test` **TEST SUCCEEDED, 21 passed, 0
failed**, 50 snapshot PNGs (on `90dd2a2`; only Dart changed after
`c3d9cba`). That first `xcodebuild test` ran with parallel testing on, so
Xcode made a temporary "Clone 1 of iPhone 18 Pro" for the run and removed it
itself; every later run used `-parallel-testing-enabled NO` (no simulator
created).

### 3a. V24f gets the reminder row

- The row (`RestReminderRow`, unchanged) sits under V24f's Premium card,
  12 pt below it, as on the board (`dea05a4`).
- N01's first-appearance trigger was already on Home's rest-scene branch,
  which serves both V24 and V24f; tests now cover both ("N01 opens over
  whichever rest scene comes first": V24 Premium, V24f free).
- **The Wake button was not on the first view** at 6.1"–6.3": measured in
  the app's font with each phone's real safe area, its bottom was 26 pt
  under the nav bar's top at 390 × 844, 30 pt at 393 × 852, 11 pt at
  402 × 874 (with or without the row: the two done ticks in the header wrap
  to two lines at these widths). V24f's scene now gets shorter after layout
  until the button's bottom is 8 pt above the bar (I-7): 265 / 261 / 280 pt
  instead of 300; 6.7" and 6.9" keep 300; never below 240 (the iPhone SE
  gets 240 and needs a scroll, which INTEGRATE allows below 390 × 844). The
  camera keeps the companion at the same distance from the scene's bottom.
  The row scrolls into view where it does not fit (`12e09b7`).
- Tests (`test/home_screen_test.dart`, "INTEGRATE 3a"): at 390 × 844,
  393 × 852, 402 × 874, 428 × 926 and 440 × 956 the button is fully above the
  bar on first view; on all six sizes (with 375 × 667) the row is under the
  card and, scrolled, above the bar with its switch tappable.
- The gallery's V24 / V24f boards now show the row switched on at 20:00 as
  on their boards, and a new `N01-OverRest` board shows the question over
  V24f (`aa4557e`).

### 3b. The pawn on 6.1"–6.3" screens

**Measured first** (the app's font, real safe areas, Home in the real
floating nav shell, November = 30 days): with the full 350 pt window the
pawn's feet were **31 pt under** the bar's top at 390 × 844 on day 0,
**34 pt** at 393 × 852, **14 pt** at 402 × 874, **149 pt** at 375 × 667; on
a mid-month day still 9–13 pt under at 390 / 393 wide. (Fix round 2's
measurement used a 47 pt top inset for every size, which hid most of this
at 402 × 874.)

**Choice: a shorter mountain window, fitted on first view (I-5).** On day 0
the camera is held by the art's bottom edge (the trail starts about 75 pt
above it), so no camera framing can lift the pawn, and Home's spacing above
the card is 48 pt in all, against a 47–50 pt shortfall on 6.1". Home now
measures where the window starts on first view and picks the tallest
window, at most 350 and at least 160 pt, in which the pawn's feet and the
next step's ring stay **16 pt above the bar on every day of the month**
(`MonthlyMountain.fitWindowHeight`; one height for the whole month, so the
card does not change size from day to day). Results: **303 pt** at
390 × 844, **299** at 393 × 852, **319** at 402 × 874, **160** (the minimum)
at 375 × 667; 428 × 926 and 440 × 956 keep **350**. `ClimbCamera`, the K-c
zoom overview, the card's bubble and the loading skeleton take the height.
On the SE's 160 pt window the speech bubble would cover the pawn, so it is
left out below 240 pt (I-6; the Daily Test card above says the same thing).
A screen shown without the nav bar keeps the full window (`12e09b7`).

Measured after the change (the test's numbers): day 0 clearance 16.2 pt at
390 × 844, 16.8 at 393 × 852, 16.7 at 402 × 874, **12.6 pt at 375 × 667**
(not covered, as asked; 16 pt is not reached there at the 160 pt minimum,
I-6). Tests ("INTEGRATE 3b"): six sizes × day 0, mid-month (15), the last
step waiting (29) and the summit (30): pawn and ring 16 pt above the bar
(SE: not covered), the bubble never over the pawn, the window full on 6.7"
and 6.9". Fix round 2's V15 test asks for 16 pt everywhere now (it allowed
0 at 6.3" on day 0).

### 3c. Nunito Sans in the widgets

The extension now bundles the app's own `assets/fonts/NunitoSans-Variable.ttf`
and `OFL-NunitoSans.txt` as resources (referenced from `assets/fonts/`, not
copied; added by `tool/ios/configure_xcode_project.rb`, which stays
idempotent and writes no signing setting; RunnerTests carries the font for
the snapshots). `WidgetFont` registers the file on first use
(`CTFontManagerRegisterFontsForURL`, process scope; I-9) and draws every
widget text in it at the boards' weights on its `wght` axis: 900 for titles
and labels, 700 for lines (W01: 900 / 800 / 700). Characters Nunito has no
glyph for fall back through a cascade list to the system's rounded font,
then the system font (Japanese, Korean, Arabic); without the file, the
system rounded font throughout (`7dc49b5`).

Verified: the release `GrammarLensWidgets.appex` contains both files; a new
Swift test checks the family, the 900 and 700 weights on the axis, Latin /
German / Turkish / Portuguese text in Nunito and Japanese / Korean / Arabic
in a system font; the 50 snapshot PNGs were regenerated and looked at. No
text is cut off: German small / medium / tip ("Stufe 15 von 30",
"Nächster Test in 10 Std.", "Heute erledigt" scaled in its box), Arabic
with two-digit steps ("15/30", RTL), Turkish, English waiting and done. The
small widget's subtitle reaches the fox's ear, as on the W01 board (its
92 pt fox starts under the subtitle too; I-10). Sheet:
`build/integration-captures/widgets-snapshot-sheet-nunito.png`.

### 3d. `TASK-widgets.md` in English

Already English: the widgets run saved the owner's Turkish message as an
English rendering in W0 (DW0-1), with the user-facing copy kept. Checked
for Turkish letters and common Turkish words: none. No change.

### 3e. Release build check

`flutter build ios --release --no-codesign` → **✓ Built
`build/ios/iphoneos/Runner.app` (50.0 MB)**, Xcode build 82 s, exit 0 (on
`7dc49b5`; again on the final `ca642b2`, 93 s, the same result).
`Runner.app/PlugIns/GrammarLensWidgets.appex` is inside, both binaries are
`arm64`, the extension's version is 1.4.0 (7) like the app, and it carries
the font and its licence. The known Flutter 3.44.6 / Xcode 27.2 problem
(`lipo -verify_arch` with two architectures) hits only `flutter build ios
--simulator` (a generic two-architecture simulator build, DW1-1); device
release builds are not affected. Nothing was upgraded. The build used the
default (no `config/prod.json`); the owner's device command in
`DEVICE-CHECKS.md` adds it.

### 4. Checks

**After the last code change** (HEAD `ca642b2`; only docs changed after
it), run together in this session (`build/final-integration.log`):
- `flutter analyze`: **No issues found.**
- `flutter test`: **2630 passed, 0 failed** ("All tests passed!").
- `xcodebuild build`, Runner + `GrammarLensWidgets`, Debug, iPhone 18 Pro
  simulator: **BUILD SUCCEEDED**.
- `xcodebuild test` (RunnerTests: bridge, payload, timeline, reminder
  requests, the widget snapshots and the new font test;
  `-parallel-testing-enabled NO`): **TEST SUCCEEDED, 22 passed, 0
  failed**, 50 snapshot PNGs in `build/widget-snapshots/`.
- `flutter build ios --release --no-codesign` (3e) again on `ca642b2`:
  **✓ Built `Runner.app` (50.0 MB)**, the extension `arm64` with the font
  and licence.

**Captures** (`build/integration-captures/`, not committed):
- `V24f-first-view-402x874.png` (the real app: the Wake button above the
  bar), `V24f-reminder-row-scrolled.png` (the row under the card),
  `N01-over-rest-scene.png` (N01 opened by itself over the first rest
  scene, V24f), from the smoke walk;
- from the board gallery (`tool/ui_polish/capture.sh`, iPhone 18 Pro, 0
  failed boards): `V15-HomeNextDay.png` and `V14-Home.png` (first view: the
  fitted window, the pawn and its ring above the bar), `V24-DayComplete.png`
  and `-400.png` (Premium; its row under the countdown needs a scroll on
  6.3"), `V24f-RestFree.png` and `-400.png` (free: Wake on the first view,
  the row switched on at 20:00 when scrolled), `N01-OverRest.png`; side by
  side in `sheet-home-rest.png`;
- `widgets-snapshot-sheet-nunito.png` (twelve widget snapshots: English,
  German, Arabic with two-digit steps, Turkish dark).

**Smoke walk** on a fresh install (the app deleted from the simulator
first), the real app through `tool/widgets/seeded_app.dart` with
`SEED_SKIP=true` (no seeding; Firebase and RevenueCat not started,
analytics dropped, the debug fixture offering), Debug, iPhone 18 Pro:
- Welcome (V02): the side companions float, Fox sways → "Get started".
- The turntable (V03) → "Try my luck" → the wheel (V03b) → it landed on
  Cat (not the current Fox) → "Climb with Cat".
- Name (V04): the field, "Ada", Continue lights up.
- Goal (V05): four goals, School & university third → picked it.
- Getting ready (V05b): "School English, here we come!", the three stops
  ticking, the "Your climb" chips with "School & university". **Found:**
  the goal chip drew the briefcase for every goal; fixed (`ca642b2`, the
  goal cards' icons shared).
- The mountain intro (V06): **the flag stands on the summit**, "Summit ·
  step 30".
- Day 0 test: question 1 right ("eating": Q04, +2, the cheering Cat),
  question 2 wrong on purpose ("Almost!", the correct sentence, "This goes
  to your weak spots", +1), three skipped.
- The Welcome badge (V11), then the results (V10: 1/5, +3 points, 1 step,
  1 weak spot) — the badge comes before the results in this flow.
- The first climb (V12): Cat walks to step 1, "First step done! 29 to the
  summit." → the paywall (V13: the trio floating, the CTA shining, the
  fixture's "7 days free, then $49.99 per year") → "Maybe later" → Home
  (step 1 of 30, "Step 2 opens tomorrow", the free ticket on Articles).
  N01 did not open after this first test (correct).
- Relaunched with today's free ticket used (`SEED_TICKET_USED=true`): **N01
  opened by itself over V24f** (the first rest scene) → "Not now" → V24f:
  "Cat is dreaming of… Articles", "All done for today", Daily Test 1/5, the
  ticket used, the countdown, the Premium card with one USED and four
  locked tickets, "Wake Cat up · 7 days free" **above the nav bar on first
  view**; scrolled: "Remind me tomorrow · 20:00" with its switch off → Wake
  → the companion wakes → **V13r** ("Cat is wide awake, Ada.", the waving
  Cat at the camp, "Practise it now: Articles, saved today → right after
  your trial starts", "Start my 7-day free trial") → "Maybe later" → back
  at the camp, Cat asleep. No purchase.

### 5. Docs

This section and the summary above; `docs/build-log.md` (one dated entry);
`docs/roadmap.md` (the 1.5.0 row and the UI polish status: both built and
integrated on `ui-polish-widgets`, not on `main`, not shipped, not checked
on a device); `product.yaml`: the two `planned` lines, a `recent` entry
(I-12) with the oldest dropped (still five), `updated_at` 2026-11-17;
`status`, `versions` and `legal` unchanged (no new third party, no new data
collected: the font is the app's own, nothing leaves the device).
`PROGRESS-widgets.md` stays the widgets record.

### 6. `DEVICE-CHECKS.md`

New, in this folder: one ordered checklist for the iPhone 14 Plus, merged
from fix round 2's "Owner device checks" (below) and `PROGRESS-widgets.md`'s
"Owner steps": (1) before the first device build, the Xcode steps for the
`GrammarLensWidgets` target (team, App Group for both App IDs) click by
click, the portal fallback and the exact release command with
`config/prod.json`; (2) install over 1.4.0 without deleting: data,
Reduce Motion, Home, motion, Daily Test, ticket, Review, practice, Profile,
the edit-name sheet, medals, the paywall, the free rest scene → Premium
with a sandbox trial, the widgets, the reminders, haptics; (3) delete and
reinstall for the first run; (4) performance in release. Each item has its
expected result and board ID.

### Decisions (integration)

- **I-1 ARB conflicts: a key-level three-way merge.** · Hand-edit the
  conflict hunks vs. merge by key. · **By key against the merge base**, so
  each side's additions, removals and changes are kept exactly; a key
  changed on both sides would have kept SPEC v10 (none existed). · Eight
  files, 96 new English lines: by hand would risk dropping one.
- **I-2 The merge's semantic fix went in before any other change**
  (`dea05a4`): the merge's checks must pass before the integration work
  starts, and the failing test was the integration point itself (the row on
  V24f).
- **I-3 The 1.4.0 schema comes from `c37757a`, not `main`.** `main` has
  `8d4183b` (a `StorageService` fix that is not in build 7); both are v26,
  but the test should open exactly what phones have.
- **I-4 Retired heroes migrate on the first profile read**, as built in B1;
  the upgrade test checks the stored id after that read.
- **I-5 3b: a fitted window, not camera framing or spacing** (why above).
  Options: change `ClimbCamera.pawnAt` (cannot lift day 0), tighten Home's
  spacing (48 pt in all, not enough), a per-device height table (breaks
  with text sizes and safe areas), or measure. · **Measure on first view and
  fit the window to the month's worst day, 160–350 pt, only under the
  floating nav bar.** · Exact at every size and text size, stable through
  the month, no change on 6.7" / 6.9", easy to undo (one parameter).
- **I-6 The iPhone SE reaches "not covered", not 16 pt**, at the 160 pt
  minimum window; the bubble is left out below 240 pt there. A smaller
  window would hardly show the mountain.
- **I-7 3a: V24f's scene shrinks after layout so "Wake" is 8 pt above the
  bar**, 240–300 pt, rather than a fixed height: the header's height changes
  with the language and the text size. The row may need a scroll (the
  button wins, as `INTEGRATE.md` says).
- **I-8 The reminder row's place on V24f** is 12 pt under the Premium card
  inside the night panel, as on the board.
- **I-9 3c: the font is registered at run time**, not through
  `UIAppFonts`: the same code works in the extension and in RunnerTests'
  snapshot run, and a missing file falls back to the system font instead of
  failing.
- **I-10 3c: weights 900 / 700** for the two styles the views use (heavy,
  bold), matching W01's 900 titles and labels and 700 lines; W01's 800
  chips draw at 900. The small widget's subtitle over the fox's ear is the
  board's own layout.
- **I-11 Smoke walk through the seeded runner**, not `main.dart`: the real
  app's screens and storage, with analytics dropped and no Firebase or
  RevenueCat, so a simulator run sends nothing; the paywall shows the debug
  fixture offering.
- **I-12 `product.yaml` `recent` gets an entry too.** `INTEGRATE.md` §5 names
  the `planned` lines and `updated_at`; `CLAUDE.md` says a completed fix goes
  on top of `recent`. Both done; the oldest entry (1.4.0 screenshots,
  2026-11-05) dropped to keep five.
- **I-13 The getting-ready goal chip fix** (`ca642b2`) is outside
  `INTEGRATE.md`'s list; it was found by the smoke walk it asks for, is one
  shared function, and the smallest fix that is easy to change.

### Not verified

Anything on a device: signing the extension, the App Group on a real
phone, the widgets and reminders on the home and lock screens, Nunito in a
real widget (the simulator's snapshots and the appex contents only), the
1.4.0 → v27 upgrade with the owner's real data (tested with a 1.4.0-shaped
database), haptics, the real keyboard, performance. A real purchase. A
delivered reminder's tap on the simulator (the widgets run found it does
not open the app there). All of it is in `DEVICE-CHECKS.md`.

## Final summary

**Status: B0–B11 done, fix round 1 done, fix round 2 done** on branch
`ui-polish` (pushed), **integrated with the widgets and reminders on
branch `ui-polish-widgets`** (pushed; "Integration" above), **and fix rounds
3, 4 and 5 done there** (pushed; "Fix round 5" at the top: the owner's
third device pass, SPEC v13; "Fix round 4" and "Fix round 3" under it). Not
merged into `main`, not shipped. The owner tested `ui-polish` and then
`ui-polish-widgets` on his iPhone 14 Plus three times; fix rounds 3 to 5
were built and checked **on the simulator and in tests only**. What only
the phone can confirm is in [`DEVICE-CHECKS.md`](DEVICE-CHECKS.md): its
first section, "Fix round 5 — fourth pass", in order. Decisions for the
owner to review: F5-1 to F5-19 ("Fix round 5", "Decisions"), and F4-1 to
F4-13 before them (F5-2 changes F4-1 and F4-4).

| Batch | Status | Commits |
|---|---|---|
| B0 Plan | done | `24baf18`, `12cdd9c` |
| B1 Foundations | done | `49302e1`, `a91ea97`, `85e7160`, `be7e333`, `0346fc4` |
| B2 Shared components | done | `9186d21`, `a1e08b9`, `5cb8578`, `6cb7aa2`, `1a7fca5`, `53b8006`, `db2e521` |
| B3 Launch and onboarding | done | `7435559`, `af5cbff`, `e6807b1`, `fde5fe8`, `51d38d6`, `531a525`, `3b70896`, `de8bc02` |
| B4 Daily Test and rewards | done | `a879129`, `95d1520`, `ea04792`, `ead1918`, `03dc9e6` |
| B5 Home and mountain | done | `592ef64`, `e6bf38b`, `00130c7` |
| B6 Review | done | `20afb23`, `4f4e250`, `1bf37c4` |
| B7 Practice + first-wave topics | done | `9ea926e`, `9a8024d`, `1fc2a1c`, `d872413` |
| B8 Paywall | done | `2981ab0`, `f303bad` |
| B9 Profile | done | `f98eac1`, `5c39c65` |
| B10 System and themes | done | `5dabea0`, `2aa88bd` |
| B11 Final sweep and docs | done | `a4228b3`, `cd3c33d`, `2c6ddaf` |
| Fix round 1 (owner, 2026-11-17) | done | see "Fix round 1" below |
| Fix round 2 (owner device test, 2026-11-17) | done | see "Fix round 2" below |
| Integration with the widgets (2026-11-17) | done | see "Integration" above |
| Fix round 3 (owner device test of the integration, 2026-11-18) | done | see "Fix round 3" above |
| Fix round 4 (owner's second device pass, 2026-11-18) | done | see "Fix round 4" above |
| Fix round 5 (owner's third device pass, 2026-11-18) | done | see "Fix round 5" at the top |

**Done.** Every in-scope board of SPEC §5 is built and captured on the
iPhone 18 Pro simulator (iOS 27.2) through the debug-only board gallery
(`tool/ui_polish/`); the comparison table is in B11 (updated by fix round
1). The first-wave topics are in the app and the proxy, switched off, with
tests for both states. Fix round 1 built the board's medal shelf, the
ribbon's "since" line, R02's ring, V09's book flight, the listed motion
details, keyboard focus on the language options, and found V05-Goal's
capture "hang" to be the tool's (fixed, recaptured).

Fix round 2 made every companion loop visible (board keyframes as
minimums), gave the paywall trio its float and hop and the CTA its shine
and pulse, rebuilt the Free vs Premium table, Profile's ribbon, the edit-name
sheet (it sat a keyboard too high) and the medals layer's order. It added
the fourth goal (School & university), made getting ready last at least 4 s,
put the V06 flag on the summit, kept Home's greeting on one line, and built
the free users' rest scene → Premium flow (V24f, V24s, V13r, PW05r).

**Not done** (each listed with its batch or in fix round 1): mastery strips
(D6-1 / D7-1, **deferred by the owner**: a separate feature later); a few
motion details outside fix round 1's list (V08's measured star path,
Q04's "—" fill, V14's capsule "+N" pop, V13c's Premium column fill, V19's
Next slide-in, V22's midnight stub, H03's think pose); PF03 stays the
existing medal detail rather than the board's bottom sheet (D9-3).

**Not verified.** Nothing on a physical device (haptics, real keyboard,
performance). Arabic and the largest text size are checked by tests, not
captures. No real purchase, no real AI generation, no proxy call; the proxy
is not deployed. Out of scope and untouched: W01, N01–N03, the reminder
switch on V24.

**Decisions approved by the owner (2026-11-17), kept as built:** D5-1,
D5-2, D5-3, D5-4, D6-3, D7-2, D8-1, D8-2, D8-3.

**Decisions closed by fix round 1:** D9-1 (the "since" line is built from
the first Daily Test on record), D9-2 (the board's shelf is built), D9-4
(keyboard focus is back), D6-1 / D7-1 (deferred by the owner).

**Decisions still open for the owner** (details under each batch and in fix
round 1): D6-2 ("new" chip = saved once), D6-4 (RV05's navy button), D6-5
(R03 shows the latest mistake only), D7-3 ("Back to topics"), D7-4, D7-5,
D8-4, D9-3 (PF03 is the existing detail), fix round 1's F1-1 to F1-9,
fix round 2's F2-1 to F2-12, and the integration's I-1 to I-13 (above;
I-5 to I-7 change what 6.1"–6.3" phones and the iPhone SE see).

## Owner device checks

Things the simulator cannot confirm (fix round 2). Since the integration,
the full ordered list, with the widgets and reminders and the Xcode steps,
is [`DEVICE-CHECKS.md`](DEVICE-CHECKS.md); this list is part of it. Please
check them on the iPhone 14 Plus before the merge:

1. **Is Reduce Motion on?** (Settings → Accessibility → Motion.) With it
   on, every companion loop stops by design (the app's rule since B1). If
   the companions looked still at the first test, check this first.
2. **Companion motion.** Each loop should be clearly visible:
   - Welcome: the sides float, Fox sways;
   - the Home card: it hops;
   - the paywall: the sides float, the middle hops, the CTA shines and
     pulses;
   - Profile: it breathes and floats; tap it and it waves;
   - the rest scene: Premium users see the breathing companion with a
     rising Zzz; free users see the dream bubble floating;
   - getting ready: it tilts, then hops.
3. **The V06 flag stands on the summit** of the month's mountain (the owner
   saw it off the peak).
4. **Home's greeting is on one line** with your own name, bold, at your
   text size.
5. **The free rest scene → Premium flow** (a free account with today's
   Daily Test done and the free ticket used):
   - the dream bubble shows today's weak spot;
   - "Wake Fox up · 7 days free" matches the store's trial;
   - waking opens the paywall from the bottom;
   - X shows the reminder once, then returns to the camp;
   - a sandbox trial leads to PW05r, and "Practise <weak spot>" opens that
     practice.
6. **Haptics:** Wake (medium) and the wake hop (light); Save name and the
   pencil (light); See all (light); the paywall CTA (medium); the goal
   cards (selection).
7. **Edit name with the real keyboard:** the sheet sits on the keyboard,
   with the companion stage visible and dimmed above it.
8. **Home on first open:** the pawn and its gold next-step ring are above
   the nav bar.
9. **Getting ready** feels unhurried (about 4 s) and never stalls.
10. **All medals** shows your real medals in the right order.
11. **The Free vs Premium table** reads well at your text size.
12. **School & university** appears as the third goal in onboarding.

## Decisions

Format: what · options · choice · why.

- **D0-1 Simulator.** TASK §6 asks for a 6.1"-class iPhone. Installed
  simulators: iPhone 18 Pro, iPhone 18 Pro Max, iPhone Air (iOS 27.2); no
  6.1" device. · Options: install another runtime/device; use the nearest.
  · **iPhone 18 Pro** (402 × 874 pt, the nearest to the boards' 390 × 844).
  · Rule 5: smallest choice; no download.
- **D0-2 Untracked files that are not part of this run.** `Claude outputs/`
  and `screenshots/icon-exploration/` (22 MB, owner's icon rounds) were
  untracked before the run. `git status` must be clean at the end. ·
  Options: commit them; delete them; ignore them locally. · **Listed in
  `.git/info/exclude`** (local only, not committed, nothing deleted). ·
  Committing someone else's 22 MB of images or deleting them would be wrong;
  a local exclude is invisible to the repo and undone by removing two lines.
- **D0-3 Asset briefs.** `docs/design/ui-polish/asset-requests*.md` were
  untracked next to the handoff and the roadmap links them. · **Committed
  with the handoff** in the first commit.
- **D0-4 Capture tooling.** TASK §6 allows debug-only entry points. · A
  **board gallery** under `tool/ui_polish/` (`gallery_app.dart` +
  `gallery_driver.dart` + `capture.sh`), like `tool/screenshots/`: a
  `flutter drive` run that opens each board's real widget with fixed sample
  data and saves `xcrun simctl io <udid> screenshot` into
  `build/ui-polish-captures/`. Nothing in `lib/` imports it
  (`test/tool_import_guard_test.dart`), so it never reaches a release build.
  Real flows (onboarding, Daily Test) are also walked by hand where
  practical.

- **D1-1 Dark page and card.** SPEC §3.1 lists SY03's dark page #15141A
  and card #211F27 but also says to keep the app's theme values where they
  exist. · Keep #151517 / #252528 (the app's dark theme) vs. switch the
  whole dark theme. · **Kept the app's values** in `AppColors.dark`
  (within a few steps of SY03's). · The rule's "keep the app's values";
  changing the app-wide dark surfaces is out of this run's scope.
- **D1-2 Mood filters.** SPEC X01 gives sad saturation 0.55 and sleep
  brightness 0.82; the boards' static renders show full colour. ·
  **Applied** (SPEC §5 outranks the render). Sad heroes look duller; easy
  to remove (`CompanionView._sadFilter`).
- **D1-3 Loops in tests.** ~2400 widget tests use `pumpAndSettle`, which
  never settles under an endless loop. · `AppMotion.loopsEnabled` is false
  in `test/flutter_test_config.dart`; loop tests turn it on. Haptics are
  recorded (`HapticMap.log`) instead of reaching the platform.
- **D1-4 Retired avatar files.** Deleted in B1 once nothing referenced
  them (ASSETS.md); their name strings removed from the 8 ARB files.

## Blocked / not verified

- Nothing is checked on a physical device in this run (TASK §6).
- Arabic (RTL) and the largest text size: by tests (`b10_system_pass_test`,
  `l10n_layout_test`), not by simulator captures.
- Purchases, AI generation and the proxy: not exercised (fakes and the
  debug fixture offering only); the proxy is not deployed (TASK).
- B11 recapture: the gallery driver hung twice on V05-Goal's tap. **Resolved
  in fix round 1:** a tool race, not the app (see fix round 1); V05 is
  recaptured.

## Fix round 2 (owner device test, 2026-11-17)

Status: **done** (on the simulator; the owner's device checks are open). Task: `FIX2.md` (SPEC v10). The owner tested the
branch on his iPhone 14 Plus (428 × 926 pt); this round fixes what he found
and adds the free users' rest scene → Premium flow. Everything is built and
checked on the simulator; what only the phone can confirm is in "Owner
device checks" below.

First commit: `ca3a847` (SPEC v10, FIX2.md, the new and changed boards).

### Simulator

`iPhone 18 Pro Max` (`306F22C5-E6BE-4651-9715-7DF8FA7F0AB7`, iOS 27.2,
6.9", 440 × 956 pt), the 6.7"–6.9" class FIX2 prefers. The iPhone 18 Pro
(`49ECC1F0-…`) was already booted when this round started; it may be the
widgets session's, so this round never installs, launches or captures on
it, and never shuts it down. No simulator was created, erased or deleted
(`simctl delete unavailable` found none).

### 0. Disk space

Commit `dba8f4c` (this record).

Free space (`df -h ~`): **before 6.5 GiB** (97 % used), **after 11 GiB**
(95 % used). At the end of the round, after the simulator builds and
captures, 6.9 GiB were free (the new `build/` and this repo's DerivedData
are regenerable; `flutter clean` frees them again).

Deleted (only what §0 allows):
- `flutter clean` in `~/GrammarLens`: `build/` (3.1 GB: `build/ios` 2.8 GB,
  the capture folders of earlier rounds `ui-polish-captures` 74 MB and
  `ui-polish-captures-pre-b11` 78 MB, test caches), `.dart_tool/` (764 MB),
  the ephemeral iOS/macOS files. `flutter pub get` restored `.dart_tool`.
- No other `build/` output folder exists in the repo. The `build/` folders
  under `proxy/node_modules/*` are files of installed npm packages, not
  build output; left alone.
- Xcode DerivedData `Runner-gqpsqcemuvgmtpfubbjqojoydaim` (1.0 GB):
  `WorkspacePath` = `/Users/ahmet/GrammarLens/ios/Runner.xcworkspace`,
  checked before deleting. The `~/GrammarLens-widgets` one
  (`Runner-fdbimsrcbtglzobktrwmmqsglozm`) was not touched.
- `xcrun simctl delete unavailable`: ran, nothing was unavailable.

Report only, **not touched** (the owner may run the command himself):

| Space user | Size | Safe command (owner) |
|---|---|---|
| CoreSimulator devices (all) | 21 GB | `xcrun simctl erase <udid>` on one he no longer needs (wipes its apps), or delete it in Xcode → Devices |
| · `Hemdem 16e` (`F9F073B8…`) | 5.7 GB | as above |
| · `iPhone 18 Pro` (`49ECC1F0…`) | 5.3 GB | as above (the widgets session may use it) |
| · `iPhone 18 Pro Max` (`306F22C5…`, this round's) | 3.4 GB | as above |
| · `BirdPerch Test 17e` (`CCF0EAEF…`) | 3.2 GB | as above |
| · `Hemdem 16` (`BA036CBC…`) | 3.1 GB | as above |
| Simulator runtimes iOS 27.0 + 27.2 | 15.3 GB | `xcrun simctl runtime delete <id>` for iOS 27.0 if no simulator needs it |
| `~/Library/Developer/Xcode/iOS DeviceSupport/iPhone14,8 27.0` | 6.4 GB | delete the folder; Xcode rebuilds it on the next device connect |
| DerivedData `Seher-…` (`~/Projects/seher`) | 4.0 GB | `rm -rf ~/Library/Developer/Xcode/DerivedData/Seher-*` |
| DerivedData `Runner-fdbimsrcb…` (`~/GrammarLens-widgets`) | 2.9 GB | only after the widgets session is finished |
| DerivedData `ModuleCache.noindex` | 1.9 GB | rebuilt by Xcode; delete with Xcode closed |
| DerivedData `BirdApp-…` (`~/Projects/BirdPerch`) | 1.2 GB | `rm -rf ~/Library/Developer/Xcode/DerivedData/BirdApp-*` |
| DerivedData `Runner-adlzgtau…` (`~/Projects/ScanStash`) | 1.1 GB | `rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-adlzgtau*` |
| DerivedData `SDKExplicitPrecompiledModules` | 850 MB | rebuilt by Xcode |
| Repo: `proxy/node_modules/` (ignored) | 491 MB | `rm -rf proxy/node_modules` (then `npm ci` in `proxy/` before the next proxy job) |
| `~/.pub-cache` | 248 MB | keep (every Flutter build needs it) |
| Repo: `screenshots/icon-exploration/` (owner, untracked) | 22 MB | owner's material |
| Repo: `proxy/eval/out/`, `proxy/.wrangler/` (ignored) | 4.4 MB, 2.4 MB | owner's eval output / wrangler cache |
| Repo: `Claude outputs/` (owner, untracked) | 12 KB | owner's material |

### 1. Companion motion

Commit `00b6981`.

**Diagnosis.**
- (a) `AppMotion.loopsEnabled` is a plain `static bool loopsEnabled = true`
  with no build-mode check, so it is `true` in debug, profile and release.
  Only `test/flutter_test_config.dart` sets it to `false` (for
  `pumpAndSettle`). A guard test now checks that nothing in `lib/` assigns
  it.
- (b) `AppMotion.loopsOn` turns loops off only for
  `MediaQuery.disableAnimations` (the system's Reduce Motion) or a muted
  `TickerMode` (a hidden tab or a covered route). Nothing else turns them
  off: not low-power mode, not VoiceOver. If the phone has Reduce Motion on,
  every loop stops, by design. That is now an owner device check.
- (c) Plain images instead of `CompanionView`:
  - The paywall trio used `AvatarTile`: round still tiles, **no motion at
    all**. Fixed in item 2.
  - The mountain pawn (`monthly_mountain.dart`) is an `AvatarTile` by
    design: the boards draw it as a tile that hops on arrival.
  - The buddy picker's side heroes are still images by design: only the
    front one waves.
  - The lucky wheel's segments are still images by design.
  - Welcome, Credits, the Home card, Profile, the rest scene and every
    other screen already used `CompanionView`.
- (d) `CompanionView` syncs its loop in `didChangeDependencies`, and
  MediaQuery and TickerMode are both dependencies. So a loop does start when
  a hidden tab or a covered route comes back, and stops on dispose. The one
  "plays once and stops" case was **cheer**: two hops on mount, then only a
  4 % breath, so it looked still after 0.6 s. Welcome's loops wait for the
  splash to lift, by design.
- (e) **Amplitudes too small to see.** This was the main cause:
  - wave turned only ±1°, with a 4 px bob scaled down below 110 pt (1.6 px
    on V04's 44 pt companion);
  - idle only breathed (4 %), with no float;
  - inspect tilted 2°;
  - sleep breathed 3 % in Y, and its Zzz bobbed 8 px in place;
  - think was 0 → −6° (borderline).
  - Every distance also shrank with the companion's size (`size / 110`).

The table below lists every companion in the app (✱ = changed by this
round).

| Screen | Widget | Mood | Expected (SPEC §3.5 / board) | Before → now |
|---|---|---|---|---|
| V02 Welcome trio | `welcome_screen` `_Trio` | wave | sides `gl-float` 8 px; Fox `gl-wave` | all three ±1° and floated → ✱ sides float, Fox sways −9°/+7°/−6°/+3° |
| V03 Meet (front hero) | `buddy_picker` | wave | the pose + bob | ±1° → ✱ `gl-wave` |
| V03b wheel result | `lucky_wheel_screen` | cheer | two hops | once → ✱ every 2.4 s |
| V04 Name (stage, chip) | `onboarding_screen` | idle 92, wave 44 | breathe + float; wave | breathe only; 1.6 px → ✱ float 6 px, `gl-wave` |
| V05 Goal reaction | `onboarding_screen` | cheer 76 | hop | once → ✱ every 2.4 s |
| V05b Getting ready | `getting_ready_screen` | inspect → cheer | `gl-tilt`, hop | 2°; once → ✱ ±4°, every 2.4 s |
| V06 / V12 mountain | `mountain_scene` | per scene | per mood | ✱ (shared widget) |
| V07 / V08 / V09 Daily Test | `daily_test_screen` | idle / cheer / oops | per mood | ✱ idle float, cheer loop |
| V10 Results | `daily_test_result_screen` | cheer 118 | `gl-hop` | once → ✱ every 2.4 s |
| V11 / R05 medal | `medal_celebration` | cheer 132 | hop | once → ✱ every 2.4 s |
| V14 / V15 Home card | `daily_test_card` | think (loading), idle + hop (todo) | `gl-tilt`; `gl-hop` | hop already ran; ✱ think +3° ↔ −6° |
| V13 paywall trio | `premium_screen` `_AvatarHero` | — (`AvatarTile`) | sides float, middle hops | **still** → ✱ item 2 |
| V13b / R10 / R08 dialogs | `companion_dialog` | sad / … | droop | droop already visible (±3°) |
| PW05 Premium on | `premium_on_screen` | cheer + hop 150 | `gl-hop` | already ran |
| V16 Review | `review_parts` | cheer + hop 120 | `gl-hop` | already ran |
| V18 Preparing | `practice_preparing` | think 104 | `gl-tilt` | ✱ +3° ↔ −6° |
| V20 Reviewing | `practice_reviewing` | inspect 96 | `gl-tilt` ±4° | 2° → ✱ ±4° |
| V21 Results | `results_screen` | cheer 76, wave 48 | hop; wave | ✱ |
| R03 weak spot | `weak_spot_detail_screen` | think 64 | tilt | ✱ |
| V23 Profile stage | `profile_stage` | idle 150 (wave on tap) | `gl-breathe` + float | breathe only → ✱ float 6.8 px |
| PF04 Edit name | `settings_screen` | think 64 | tilt | ✱ |
| V24 rest scene | `rest_scene` | sleep | `gl-breathe`; Zzz `gl-zz2` | 3 %, Zzz in place → ✱ 1.05 breath, Zzz rises 30 and fades every 2.4 s |
| P08 daily limit | `practice_launch` | sleep 104 | as V24 | ✱ |
| R09 Credits | `credits_screen` | idle, wave, idle | sides float (parent), Fox waves | double float risk → ✱ sides float only via the parent |
| R11 error | `error_state` | sad 132 | `gl-droop` | already visible |
| Home pawn | `monthly_mountain` | `AvatarTile` | tile + arrival hop | by design, unchanged |

**Fix (`CompanionView`).** The loops now follow the boards' keyframes.
SPEC §3.5's values are treated as minimums.
- Distances follow the size above 110 pt but never fall below the boards'
  points.
- idle: breathes 1 ↔ 1.04 and floats 6 px (±3 px), every 3 s.
- wave: sways like `gl-wave` (0, −9°, +7°, −6°, +3°, 0) and bobs 4 px,
  every 2.2 s.
- cheer: hops twice (`gl-hop`, 16 px, 600 ms each) and then breathes, every
  2.4 s, with the sparkle twice per loop.
- think: tilts +3° ↔ −6° (2.4 s).
- inspect: tilts ±4° (`gl-tilt`, 2.4 s).
- sad: unchanged (it already matched `gl-droop`).
- sleep: breathes 1.02 × 1.05 (3.6 s) while the Zzz rises 30 px, drifts
  14 px, grows from .6 to 1.1 and fades in and out (`gl-zz2`, 2.4 s).
- oops: unchanged.
- The pivot is the feet (the boards' `transform-origin: 50% 92%`).
- New `ambient` option (`mood`, `hop`, `float`, `none`): the paywall's side
  companions float and the middle one hops. Welcome's and Credits' side
  companions get no loop of their own, because their parent floats them.
- Under Reduce Motion every loop stops and the one-shots are skipped
  (unchanged rule).

**Tests.** `test/fix_round2_companion_motion_test.dart`:
- every mood's frames are above its minimum;
- the loop really runs inside the widget for idle, wave, cheer (again in its
  second loop), think, inspect, sleep (the Zzz moves more than 25 px and
  fades), hop and float;
- every mood is still under Reduce Motion;
- the (a) guard.

### 2. Paywall companions (V13)

Commit `4c8b87d`.

**Diagnosis.**
- The trio was three `AvatarTile`s (66 / 124 / 66, round stage tiles), with
  no loop at all.
- The pinned CTA was a plain `FilledButton`, with no shine and no pulse.
- The "See plans" arrow used fix round 1's nudge (6 px, still for 60 % of
  every 1.8 s). The board uses `gl-float` 1.8 s, a continuous 8 px.

**Fix.**
- The board's trio: `CompanionView`s of 70 / 110 / 64 pt with soft blurred
  shadows. The sides float (`gl-float` 8 px, 3.2 s) and the middle hops
  (`gl-hop`, 1.2 s).
- The row keeps its 124 pt height, so nothing below moves.
- The CTA is wrapped in a new `CtaGlow`: the shine sweep inside the button
  (3 s) and the pulse ring behind it (1.8 s). Both only run while the button
  is enabled and loops run.
- The arrow floats 8 px every 1.8 s.

**Tests.** `premium_screen_test`:
- The hero tests now read the `CompanionView`s, at the board's sizes and
  gap (4 pt).
- Because the board's side companions are 70 and 64 pt, the middle one sits
  3 pt off centre, and the test allows that.
- A new "V13 motion" group checks that the sides float more than 7 px, the
  middle hops more than 14 px, the arrow floats, and the CTA shine and pulse
  are present but absent under Reduce Motion.

### 3. Free vs Premium table (V13c)

Commit `effdf6b`.

**Diagnosis.** The table was the 1.2.0 design, not the board:
- four rows ("Daily Test, refreshed every day", "Topic Practice, all N
  topics", "Practice your weak spots", "Sessions of 3, 5 or 10 questions");
- uppercase FREE / PREMIUM headers;
- a Premium strip in the theme's secondary container, painted cell by cell;
- no heading companion, no green note;
- a stacked fallback layout.

**Fix.** The board's table:
- "Free vs Premium" (22/900), with the user's companion (cheer, hopping,
  60 pt) at its end.
- A card (radius 26, 2 pt line border, lip) whose Premium column is one
  piece from the header to the last row: 92 pt wide, a cream → soft-orange
  gradient, a 2 pt orange border, a 4 pt deep-orange lip, and the navy
  "Premium" pill on top.
- Columns: label, Free 76 pt, Premium 92 pt.
- Six rows, each an icon tile (32 pt, sky) and a label (15/800), all read
  from the real rules:
  - Daily Test: 1 a day / 1 a day.
  - AI practice: `freeDailyPracticeLimit` / `dailySessionLimit` a day.
  - Weak-spot practice: ✓ / ✓.
  - All N topics (`practiceTopics()`): — / ✓.
  - Session length: 3 (a free session is always `PracticeLength.quick`) /
    3 · 5 · 10.
  - Monthly Climb: ✓ / ✓.
- The green "Cancel anytime…" note under the card.
- VoiceOver reads each row as one sentence ("AI practice. Free: 1 a day.
  Premium: 5 a day").

The old table, its stacked fallback and their seven strings are removed.

**Tests.** `premium_screen_test`:
- the old-table tests are replaced by a V13c group: copy and values,
  check styles, the one-piece column, semantics, no overflow at 320 pt and
  ×1, 390 pt and ×1.3, 428 pt and ×2.0, both themes;
- two helpers centre their tap target, because the longer page could
  scroll a plan under the pinned top bar.

### 4. Profile ribbon (V23)

Commit `2c96960`.

**Diagnosis.** The ribbon was a full-width navy card (radius 18) moved up
18 pt with a transform. It had no tails, no gradient, no lip of the board's
colour and no 40 pt overlap, so the board's ribbon was effectively
missing.

**Fix.** The board's values:
- Body 286 × 62, radius 16, #1B4FB0 → navy, a 5 pt #082A6B lip.
- Two 46 × 46 #082A6B tails with V-cut ends (the board's clip-path, notch
  at 34 %), 26 pt outside each end and 14 pt down; mirrored in RTL.
- It overlaps the stage by exactly 40 pt (the ribbon now sizes the stack,
  so a wrapped line grows it downwards, never into the stage).
- Name 23/900 white on one line (a long name scales down); line 12/700
  #C9D6FF; a 40 × 40 pencil (radius 12, white at 14 %) with a 44 pt target.
- It settles from 12 pt below in 300 ms (easeOutBack).
- On a 320 pt screen it narrows so the tails stay on screen.
- New tokens: `AppColors.ribbonTop`, `ribbonLip`, `onRibbonMuted`.

**Tests.** `fix_round2_profile_test.dart` (real font): body size, colours
and lip; name, line and pencil; tail geometry; the 40 pt overlap; settle and
Reduce Motion; a 20-character name; 320 pt; RTL.

### 5. Edit name (PF04)

Commit `fa50b36`.

**Diagnosis.** The keyboard inset was applied twice: `showAppSheet` pads
its content by `viewInsets.bottom`, and `_NameSheet` padded by it again. On
a phone with the keyboard up, the sheet grew by a whole keyboard's height
and filled the screen ("a full-screen page"). The simulator's software
keyboard is often hidden, so it did not show there.

**Fix.**
- The inset is now applied once. The sheet is sized to its content and sits
  on the keyboard, its top under the companion stage, which stays visible
  above, dimmed.
- The board's content: the waving companion (64) with the "What should I
  call you?" bubble; a 58 pt field (radius 18, 3 pt navy frame, 20/800)
  with the counter inside it; Cancel (outline) and Save (navy), 50 pt each.
  No grabber and no note line, as on the board.
- Save closes the sheet, the ribbon's name cross-fades (150 ms) and the
  "Name saved" snackbar shows (unchanged).
- Decision F2-4: the counter counts to the real limit, **n/40**
  (owner decision O2), not the board's "/20".

**Tests.** `profile_layout_test`:
- with a 336 pt keyboard at 390 × 844 the sheet's bottom is on the
  keyboard, its top below the companion, height < 260;
- Cancel saves nothing;
- the counter reads "3/40" inside the field.

### 6. All medals (PF02)

Commits `fc8efe3`, `3145097` (the empty-collection test follows the new
layer).

**Diagnosis.**
- Year and month order were already newest first: `shelf()` sorts by
  year × 12 + month, and the years keep that order. A Dec 2025 → Feb 2026
  fixture confirmed it.
- What did not match the design was the Welcome badge. It was drawn
  after every year, at the very bottom, instead of at the month it was
  earned. With the owner's badge earned in his first month, that put his
  newest-looking item last.
- There were no tier counters. "N earned" stood in for them.
- The year rows were a `Wrap` with leftover space, not a 3-column grid.

**Fix.**
- `allSlots()` is the one ordering, newest first: the running month, then
  past medals and the earned Welcome badge at its month (the shelf's own
  rule). The shelf shows its first three.
- Tier counters on top (n Gold, n Silver, n Bronze, n Welcome) count
  finalized medals only (decision F2-5: the running month's tier is not
  final; the board does the same).
- "All medals" / "Newest first" heading and a 44 pt close button.
- Under each year header (16/900), newest year first, a 3-column grid read
  left to right and top to bottom. Each cell shows the medal, the short
  month and either its tier, "in progress" or "Welcome".

**Tests.** `fix_round2_medals_layer_test.dart`, with a Nov 2025 – Mar 2026
fixture and a Welcome badge from Dec 2025:
- the order, and that the shelf shows the first three;
- the counters (1 Gold, 2 Silver, 1 Bronze, 1 Welcome);
- 2026 above 2025, each a row read left to right, the columns aligned;
- the Welcome badge after December;
- a fourth medal starts a new row at the left;
- RTL.

### 7. Goal screen (V05)

Commit `7e2d856`.

- `LearningGoal` gains `school` (stored and reported as `school`, a new
  value of the existing `learning_goal` user property, documented in
  `docs/analytics-plan.md`). Builds before this round read it as
  `general`.
- V05 lists four cards in the board's order: Exam prep, Work, School &
  university (lilac tile, book icon), Everyday English. Work and Everyday
  English get the board's new descriptions.
- The cards use the board's v10 sizes (min 80 pt, 13/14 padding, 50 pt
  tile) so all four and Continue fit the first view at 390 × 844 and
  428 × 926.
- Getting ready names the new goal ("School English, here we come!",
  "School & university").
- There is no goal editor in Profile, so V05 and V05b are the only places
  that list the goal.
- Strings in all 8 languages.

**Tests.** `onboarding_screen_test`: four goals, their order and copy, the
lilac tile, the reaction line, and the first-view fit at two sizes. The
existing per-goal "Continue finishes with the goal" test now covers
`school`. `first_launch_flow_test` and `analytics_service_test` check the
`school` value.

### 8. Getting ready (V05b)

Commit `de6e326`.

- Each stop takes at least 1.2 s **from the previous stop** (decision F2-6:
  a single 3.6 s ramp would let a fast task rush the next third after a
  slow one).
- The bar reaches 100 % at 3.6 s at the earliest; with the 0.6 s
  celebration the screen shows for at least 4.2 s.
- The bar's easing follows the ramp closely (a third of the gap per 25 ms),
  so a stop lands right after its 1.2 s.
- The honesty rule is unchanged: the bar never passes a stop before its
  task is done.
- While the bar waits on a slow task, the companion thinks.
- The 8 s error is unchanged.

**Tests.** `getting_ready_test`:
- instant work reaches each stop at least 1.2 s after the last and 100 %
  between 3.6 and 3.9 s;
- a slow first task still leaves 1.2 s between the later stops, with the
  waiting state on;
- the screen itself calls `onDone` between 4.0 and 4.6 s.

### 9. Mountain intro (V06): the flag

Commit `1c8f7cc`.

**Diagnosis.** The flag was placed in image coordinates (`SceneMap.toBox`
over the cover-scaled art). However, its point was
`ClimbRoute.at(climbLength)`, the climb's flag point on the trail (N32,
`climbFlagArc`), not the summit. That point is about 0.05 image widths left
of and 0.06 below the trail's last point. Cover-scaling on a tall phone
magnifies it to roughly 35 × 40 pt, which is "not on the summit".

**Fix.**
- `MountainScene.flagPoint` is now `ClimbRoute.summit`, the trail table's
  last point (also its highest).
- The pole's opaque foot (rows 25–997 of 1024 in the pole image) stands on
  it, and the pop grows from that foot.
- This covers every `MountainScene` (V06, V12, R04, R04b; the rest scene
  shows no flag).
- V06's summit chip now starts further right, so it scales down rather
  than run off a narrow screen.
- Decision F2-7: the climb's own last step (N32) still ends at the trail's
  flag point, so on R04 the last gold dot sits just below the summit flag.

**Evidence.** `fix_round2_summit_flag_test.dart` checks that the pole's foot
lands within 0.5 pt of the summit pixel of the art at 428 × 926 (the
owner's iPhone 14 Plus), 375 × 667, 440 × 956 and 1024 × 1366.
`CAPTURE_FLAG=1` writes the renders to
`build/ui-polish-captures/V06-flag-*.png`. They were viewed at 428 × 926 and
375 × 667: the flag is on the snow cap. The simulator capture is under
"Captures" below.

### 10. Home greeting (V14 / V15)

Commit `10d33ac`.

**Diagnosis.** Home passed `nameStyle` to `HomeGreeting`, which then always
drew two lines ("Good evening," above the name), the 1.2.0 brief's layout.
The boards draw one line.

**Fix.**
- One line, "Good evening, Ada", with the name bold inside it
  (`emphasizedSpans`).
- If it does not fit, the whole line scales down, never below 70 %.
- Decision F2-8: past that minimum (320 pt, Large text, a 40-character
  name) the end is cut with "…". VoiceOver still reads the whole greeting.

**Tests.**
- `fix_round2_greeting_test.dart` (real font): all 8 languages at 428 and
  390 pt with a 20-character name show one line with nothing cut; a short
  name stays at full size; the 320 pt / Large / 40-character case.
- `home_screen_test`: the style test now reads the spans; the overflow loop
  checks one line and the spoken text.

### 11. Free users' rest scene → Premium (V24f, V24s, V13r, PW05r)

Commits `c655cdd` (the flow), `8d3b5ed` (follow-ups from the captures:
the 300 pt free scene, the lifted camera, the button staying orange, the
paywall naming the scene's companion).

**V24f.** Shown to free users only (Premium users keep V24). Same camp with
three changes:
- No "See you tomorrow" chip and no Zzz. Instead a dream bubble ("FOX IS
  DREAMING OF…", today's weak spot, "today's weak spot") with three cloud
  dots appearing 200 ms apart and a 3.2 s float. No weak spot: no bubble.
- The sheet header: a moon, "All done for today", two done ticks ("Daily
  Test 4/5", "Free ticket used") and the countdown with "next free test".
- The Premium card:
  - navy → plum, a thin gold border and the R12 glint (3.6 s);
  - a "PREMIUM" chip with "Not sleepy yet?", and the title "Keep
    practising today";
  - five mini tickets, one used (dashed, "USED") and four locked (orange,
    lock), popping in 60 ms apart;
  - "Free: 1 ticket a day · Premium: 5 a day";
  - "Practise <weak spot> now, …" with the weak spot in gold, or, with no
    weak spot, "Pick any of the N topics, …";
  - the orange "Wake Fox up · 7 days free" button.
- The card slides up 300 ms after the scene. No haptic on open.
- No "Remind me tomorrow" row (that belongs to the other branch).
- Decision F2-9: the "· N days free" part comes from the store (the
  paywall's own rule: the annual plan's introductory offer, only when
  RevenueCat says the user is eligible). Otherwise the button reads "Wake
  Fox up".

**V24s.** On "Wake Fox up" (haptic medium):
- the card glows gold;
- the fire grows 1.25× (300 ms);
- the companion cross-fades sleep → wave (200 ms) and hops once (haptic
  light);
- the dream gives way to "I'm awake! One more round?";
- 600 ms later the paywall rises from the bottom (450 ms spring).

When the paywall closes, the companion falls asleep again (400 ms
cross-fade) and the dream returns.

**V13r.** The same `PremiumScreen`, with source `rest_scene` (a new value of
the existing `paywall_viewed` / `paywall_dismissed` source; no new event).
Only the top changes:
- the evening camp strip (the month's night art, the awake companion
  waving, the campfire) and the chip;
- "<Hero> is wide awake, <name>." and "Keep practising today. Your free
  ticket is used, Premium adds 4 more.";
- a "PRACTISE IT NOW" card with the weak spot, "saved today" and "→ right
  after your trial starts" (without a trial: "→ right after Premium
  starts");
- the benefits in V13r's order: 5 sessions (today 4 more), AI feedback on
  every answer, all N topics.

X shows V13b once per session (unchanged), then returns to the scene.

**PW05r.** "<Hero> is ready. Let's go!", the perks "AI feedback on every
weak spot", "All N topics…" and "4 more sessions today, 5 every day", and
the button "Practise <weak spot>". It opens that weak spot's screen with
practice starting at once (V18's preparing view), not Home. With no weak
spot the button is "Pick a topic" and opens the topics (R01).

Decision F2-10: the practice opens through the weak spot's own screen (as
Review does), so back returns there, then to Home.

Strings: 32 new keys in all 8 languages. The Turkish "Wake" line avoids a
name-dependent suffix ("{hero} uyansın").

**Tests.** `home_screen_test`:
- free → V24f, Premium → V24 (no card, no dream, "See you tomorrow");
- the dream, the tickets, the store-trial button, and no paywall without a
  tap;
- no weak spot: the fallback line and no bubble;
- Wake → awake bubble → V13r with `paywall_viewed(source: rest_scene)`;
- X → V13b → "Continue with free" → back to the scene, asleep;
- trial → PW05r ("Practise <weak spot>") → the weak spot's practice with
  `startPractice`; no weak spot → "Pick a topic" → the topics.

### 12. V15: the pawn under the nav bar

Commit `e477f29`.

**Diagnosis.** Measured in the app's font with the floating nav bar, at
the 6.7" ratio (428 × 926):
- The mountain window spans 480–830 pt and the bar starts at 802 pt.
- The pawn's bottom is at about 734–745 pt (days 0–28), 57–68 pt above
  the bar; the next-step ring is above it too.
- At 6.9" (440 × 956) the gap is about 98 pt.
- Fix round 1's capture (6.3", 402 × 874) had the two-line greeting
  (item 10), which pushed the card down about 30 pt and put the pawn under
  the bar.

**Fix.** No camera change. At 6.3" on day 0 the camera is clamped at the
art's bottom, and the pawn's feet reach the bar's top edge (749 vs 750 pt).
Lifting it further would need about 30 % more zoom or an empty band below
the art; neither the design nor FIX2's 6.7" target asks for that. Recorded
as a limit.

**Tests.** `home_screen_test` measures at 428 × 926, 402 × 874 and
440 × 956, days 0, 3, 15 and 28. It requires 8 pt of clearance (only "never
under the bar" at 6.3" on day 0).

### Captures (simulator)

Gallery commit `6f6c25a`.

The board gallery (`tool/ui_polish/capture.sh`) ran on the iPhone 18 Pro
Max (`UI_SIM=306F22C5-…`) into `build/ui-polish-captures/` (not committed).
It ran five times: run 1 covered every changed board, runs 2–5 the
follow-ups listed below. Every run finished with 0 failed boards. The gallery gained V24f,
V24s (a scripted tap on "Wake Fox up"), V13r and PW05r. V24 is now the
Premium users' rest scene. A `-t2` capture repeats a board 0.55–1.5 s
later.

**Item 1 evidence** (`-t2` pairs, compared crop by crop):
- V02 Welcome: the side companions float, Fox sways.
- V15 Home card: it hops.
- V13 paywall: Fox is lifted in one frame and grounded in the other; the
  side companions sit at different heights.
- V23 Profile: it breathes and floats.
- V24f rest scene: the dream bubble floats.

**What run 1 found, fixed before run 2:**
- V24f's scene kept V24's 470 pt height, which pushed "Wake Fox up" below
  the fold. The free scene is now 300 pt, so the button is on the first
  view, as on the board.
- In the shorter scene the centred camera put the sleeping companion behind
  the dream bubble. The camera now looks 0.13 image widths above the step
  (the camp stays at the step), which puts the companion under the bubble
  near the scene's bottom, as on the board. Run 3 recaptured V24f and
  V24s. The campfire sits lower than the step, so the scene's bottom edge
  cuts the base of the fire; the flame shows.
- While waking, the button turned grey (disabled). It now stays orange and
  ignores a second tap.
- V13r opened from Home named the stored profile's companion (Panda in the
  gallery) while the camp showed Fox. Home now passes its hero and name
  in `PaywallRest`.
- V13c's fixed scroll cut off the new heading (the page's end is now
  under that offset); the capture scrolls to 110 pt above the end.

### Verified

After the last code change:
- `flutter analyze`: **No issues found**.
- `flutter test`: **2482 passed, 0 failed** (`+2482: All tests passed!`).

The count is lower than fix round 1's 2493 because the old comparison
table's measurement and stacked-layout tests were replaced by the V13c
group. Item 6's change also updated `settings_screen_test`'s
empty-collection test.

The simulator runs above all finished with 0 failed boards. Nothing was
checked on a physical device: no haptics, no real keyboard, no real
purchase.

The hard limits were kept:
- no new package and no new analytics event (one new value each for
  `learning_goal` and `paywall_viewed`'s source);
- no deploy, no paid API, no version change, no merge;
- nothing deleted outside §0.

### Decisions (fix round 2)

Format: what · choice · why.

- **F2-1 Free checks (V13c).** The board draws the free column's checks as
  soft-green discs. · **Grey outlines**, as FIX2 says. · FIX2 is the
  owner's latest word on this table.
- **F2-2 Table fallback (V13c).** · **The stacked fallback is dropped.** ·
  The board's fixed 76 / 92 pt columns hold from 320 pt at ×1 to 428 pt at
  ×2: values scale down to fit and labels wrap (tested).
- **F2-3 Paywall trio (V13).** · **The board's 70 / 110 / 64 pt with a 4 pt
  gap.** · The middle companion sits 3 pt off centre, as on the board.
- **F2-4 PF04 counter.** · **n/40.** · Names are limited to 40 characters
  (O2); a "/20" counter would contradict the field.
- **F2-5 PF02 counters.** · **Finalized medals only; all four chips always
  shown; an unearned Welcome badge has no cell** (the old layer showed it
  faded at the bottom). · The board does not count the running month, and
  places the badge at the month it was earned.
- **F2-6 Getting ready timing.** · **1.2 s per stop, counted from the
  previous stop.** · A single 3.6 s ramp would let a fast task rush the
  next third after a slow one.
- **F2-7 Summit flag.** · **Every `MountainScene` flag at the trail's last
  point; the climb's last step unchanged.** · FIX2 names the summit; the
  step table (N32) is a separate rule.
- **F2-8 Greeting minimum.** · **70 %, then "…".** · Any smaller is hard to
  read; only a very long name on a 320 pt screen at Large text reaches it.
- **F2-9 V24f trial days.** · **From the store, only when eligible.** ·
  "Prices and trials come only from the store" (the paywall's rule).
- **F2-10 PW05r route.** · **The weak spot's own screen, starting the
  practice at once.** · This keeps V18's preparing view and a sensible way
  back.
- **F2-11 "See plans" arrow (V13).** · **The board's `gl-float` 1.8 s
  (8 pt, continuous)** instead of fix round 1's nudge. · The board, and it
  moves all the time.
- **F2-12 Welcome and Credits trios.** · **The parent floats the side
  companions; they have no loop of their own.** · Otherwise they would
  float twice.

## Fix round 1 (owner request, 2026-11-17)

Status: **done**.

The owner kept D5-1, D5-2, D5-3, D5-4, D6-3, D7-2, D8-1, D8-2 and D8-3 as
built and asked for nine fixes on the same branch, under TASK.md's rules (no
new package, no deploy, no paid API, no version change, no merge, nothing
destructive in git).

Commits: `b72def2` (strings), `e854cea` (V23 shelf, PF02 newest first, medal
Hero flights, PF03 count-up), `46c8ece` (D9-1 since), `946d485` (R02),
`1dfdf76` (V09), `fe8dfa4` (V07), `e51eb99` (Q04), `79fb3c1` (V15),
`f6b4d91` (R04), `63dec2f` (paywall), `20187e6` (R12), `f561357` (D9-4),
`b1cda2f` (product.yaml), `ec28e44` and `a62afce` (capture tool, V05,
V09, V15), `d03452b` (the medal preview test), and the docs commit that
records them.

### Done

1. **D9-2 medal shelf (V23).** Profile's strip is now the board's thick
   shelf (`assets/ui/medal_shelf_v2.webp`) inside one card with "Medal
   collection" and "See all": at most three medals stand on its top
   surface, newest first (the start of the line). The running month is a
   locked slot (dashed ring and lock, "N pts to Bronze") until it reaches a
   tier; then come past medals and the earned Welcome badge by month. Each
   slot has its month and a line under the shelf's front face (a past
   month's tier, the running month's way to its next medal). The medals
   settle 80 ms apart. "See all" opens the existing PF02 layer, which now
   lists newest first (B9 had it reversed) and carries the "N earned" count.
2. **D9-1 "since".** The ribbon reads "Climbing with <Hero> · since <Mon
   YYYY>", the month of the earliest completed Daily Test already stored
   (`climb_daily_entries.completed_at`, read by the new
   `StorageService.getFirstDailyTestCompletion`); without one, or if the
   read fails, "· since …" is left out. Nothing new is stored.
3. **R02 ring.** The board's 104 pt ring: a thick navy arc on a pale track
   around a white (card-colour) disc, the count 35 pt / 900. The ring fills
   in 250 ms; the count rolls like an odometer (up for a longer session,
   down for a shorter one) while the knob moves.
4. **V09 book flight.** Once "This goes to your weak spots" has popped in,
   its book icon flies to the Review tab's place in 500 ms (F1-4).
5. **Motion details** from the batches' "Not done / gaps":
   - V07: the resting hint knob nudges every 2.8 s (the board's keyframes).
   - Q04: the focused box's blank breathes once, 1 → 1.06 → 1 in 200 ms
     (F1-5).
   - V15: the step today's test will reach has a gold ring that pulses to
     1.45× every 1.8 s while the test waits.
   - R04: a medal line pops to 1.5×, turns gold and glows as the bar
     passes it.
   - Paywall: plans rise in 60 ms apart as they scroll in, the comparison
     rows fade in 40 ms apart, the See plans arrow nudges every 1.8 s.
   - R12: the focus card glints every 3.6 s.
   - PF02 / PF03: shelf medals fly into the layer and back (Hero, 350 ms);
     a medal flies from the shelf or the layer into its detail; the
     detail's steps and points count up.
   All loops are ambient (off under Reduce Motion, off screen and in
   tests); entrances become instant under Reduce Motion; no flight or
   count-up under Reduce Motion.
6. **D9-4 keyboard focus.** The language options take focus again in
   reading order (Tab), Enter or Space picks one; an orange ring shows only
   with keyboard focus, so the touch look is unchanged (F1-6).
7. **V05-Goal "hang".** Walked in the real app on the simulator (fresh
   install → Welcome → buddy → name → goal → Work → Continue → getting
   ready → mountain intro): no hang, no animation that never ends (the
   selected card's tilt is the designed ±2°, the star by the buddy is the
   cheer pose's prop, the confetti ends after 900 ms). The cause was the
   capture script: it tapped Continue right after typing, unsynchronized,
   while the button was still disabled, so the goal step never came and
   flutter_driver waited without a timeout. Fixed in the tool (a wait, and
   a 15 s timeout on every driver step so a board fails instead of hanging
   the run); V05 recaptured. No app change, so no app test.
8. **product.yaml**: only the planned UI polish line changed ("built on
   branch ui-polish, not merged, not checked on a device"); `updated_at`
   was already today.
9. **Mastery strips (D6-1 / D7-1)**: marked "deferred (owner)" under B6
   and B7; not built.

### Decisions

- **F1-1 The running month's slot.** SPEC and the owner: "a locked slot for
  the current month". Shown locked while the month has no tier; once it
  reaches Bronze it shows that medal (a tier reached in a month is never
  lost), with the way to the next one. The board's own sample has no tier.
- **F1-2 The Welcome badge on the shelf** stands by the month it was
  earned, after that month's own medal (a month's medal is finalized at
  its end); an unearned badge is only in PF02. The board's "Swipe for more
  · newest first" caption is not shown: the shelf does not swipe, "See all"
  opens the rest. "N earned" moved from Profile's header to PF02's.
- **F1-3 "since"** counts every completed Daily Test, an all-skipped one
  included (it is a completed test in the ledger). The month is short
  ("Sep 2026"), as on the shelf.
- **F1-4 V09's target.** The Daily Test is a full-screen route, so the nav
  bar is not on screen; the book flies to where the Review tab sits (the
  middle tab, bottom middle of the screen) and fades as it arrives.
- **F1-5 Q04's breathe** is drawn over the blank (a tint and its underline
  in the blank's colour): a span of text cannot be scaled in place.
- **F1-6 Focus** is opt-in on `PressableCard`; only the language options use
  it in this round. Their extra light haptic (the card's, on top of their
  own selection haptic) is gone.
- **F1-7 R02's disc** takes the card colour (white in light mode, the dark
  card in dark mode) instead of a fixed white; the board's "about 4
  minutes" line is not added (no measured duration, not asked).
- **F1-8 Paywall rows** fade only (no rise), so the comparison table's
  measured geometry never moves; the plans rise 24 pt. Semantics stay while
  they wait to enter.
- **F1-9 PF02's order** was oldest first in B9 against SPEC and the board
  ("newest first"); fixed with the shelf.

### Not done

- PF03 stays the existing medal detail (a centred dialog), not the board's
  bottom sheet (D9-3, not in this round's list); the medal now flies into
  it and its numbers count up.
- Motion details not in this round's list stay as listed under their
  batches (V08's measured star path, Q04's "—" fill, V14's capsule pop,
  V13c's Premium column fill, V19's Next slide-in, V22's midnight stub,
  H03's think pose).

### Verified

- `flutter analyze` after the last code change: **No issues found!**
- `flutter test` after the last code change: **2493 passed, 0 failed**
  (2477 before the round; new tests: the shelf's order, Welcome placement,
  locked slot and its line, geometry on the shelf image, settle stagger,
  Hero tags and the detail's count-up; the "since" line with and without a
  first test, and the storage read; R02's roll direction; V09's book with
  and without Reduce Motion and none for a right answer; V07's nudge (LTR,
  RTL, Reduce Motion); Q04's breathe; V15's ring and pulse, on Home before
  the test and not after it; R04's glowing lines; the paywall's entrances
  with semantics kept; R12's glint; the language options' Tab order, Enter
  and the keyboard-only ring). One test found after the first full run (the
  debug medal preview still expected the old strip) was updated and the
  suite re-run.
- Simulator (iPhone 18 Pro, iOS 27.2): the real app, fresh install, walked
  Welcome → buddy → name → goal → Work → Continue → getting ready →
  mountain intro (no hang). The board gallery recaptured the 15 boards
  listed in B11's table, every board without a failure; V09 also mid-flight
  and V15 scrolled to the ring.
- No proxy change in this round; nothing deployed, no paid API, no new
  package, no version change, no new data stored.

## B0 — Plan

Status: **done**.

Commits: `24baf18` (the handoff package), `12cdd9c` (this plan).

### Board → code

Every in-scope board (SPEC §2: all but W01, N01, N02, N03 and the reminder
switch on V24). "new" = file to create. All paths under `lib/` unless noted.
The hinted paths from TASK B0 were checked: all exist.

| Board | Code |
|---|---|
| V00-CompanionSystem | new `models/companion.dart` (`Companion` hero list, `CompanionMood`), new `widgets/companion_view.dart` (`CompanionView(hero, mood, size)`) |
| V00-MotionSystem | new `motion.dart` (`AppMotion`), new `utils/haptics.dart` (`HapticMap`), new `widgets/pressable_button.dart` |
| X01-ExpressionKit | `widgets/companion_view.dart` (props, per-mood motion) |
| X03-HeroSet | `models/avatar.dart` (9 heroes, picker order, retired ids), `services/storage_service.dart` (retired → Fox migration on profile read) |
| X04-Ticket | new `widgets/ticket.dart` (`Ticket(state: free, tearing, used)`) |
| X05-DailyCard | new `widgets/daily_test_card.dart` (`DailyTestCard(state)`), replaces `_DailyTestCard` in `screens/home_screen.dart` |
| V01-Splash | `widgets/launch_splash.dart` |
| V02-Welcome | `screens/welcome_screen.dart` |
| V03-Meet | new `widgets/companion_turntable.dart` (replaces `widgets/avatar_carousel.dart`), `screens/onboarding_screen.dart` |
| V03b-LuckyWheel | new `screens/lucky_wheel_screen.dart` |
| V04-Name | `screens/onboarding_screen.dart` (name step) |
| V05-Goal | V05-Goal.png | match | Three goal cards, the selected one navy. Recaptured in fix round 1 (the B11 "hang" was the capture script, fixed). |
| V05b-GettingReady | new `screens/getting_ready_screen.dart` + new `services/getting_ready.dart` (stop logic), `screens/first_launch_flow.dart` |
| V06-MountainIntro | new `screens/mountain_intro_screen.dart`, `screens/first_launch_flow.dart`, `widgets/monthly_climb/*` (flag v2) |
| V07-Question | V07-Question.png | match | Check footer, points chip; the hint knob nudges every 2.8 s (fix round 1). |
| V08-Correct / V09-Wrong | new `widgets/answer_feedback_sheet.dart`, new `services/daily_test_grading.dart` (on-device per-question grading over `utils/answer_matching.dart`), `screens/daily_test_screen.dart` |
| Q04-MultiBlank / Q05-ErrorCorrection | `widgets/question_view.dart`, `screens/daily_test_screen.dart`, `utils/answer_diff.dart` (reuse) |
| R10-Leave | new `widgets/companion_dialog.dart`; `screens/daily_test_screen.dart`, `screens/practice_screen.dart` (exit dialogs) |
| V10-Results | `screens/daily_test_result_screen.dart` |
| V11-Badge | `screens/daily_test_result_screen.dart` (day-0 Welcome badge) |
| R05-Medal | `widgets/medal_celebration.dart` |
| V12-Climb / V12b | `widgets/monthly_climb/climb_zoom.dart`, `climb_camera.dart`, `monthly_mountain.dart`; `screens/home_screen.dart` |
| V14-Home / V15 / H03 / H04 | `screens/home_screen.dart`, `widgets/daily_test_card.dart`, new `widgets/score_capsule.dart`, `widgets/ticket.dart`, `widgets/monthly_climb/climb_card.dart` |
| V24-DayComplete | new `widgets/rest_scene.dart`, `screens/home_screen.dart` (§1.8 rule) |
| R04-MonthCard | R04-MonthCard.png | match | Recap with medal swap, dots, stats, stepwise bar; passed medal lines glow (fix round 1). |
| R04b-NewMountain | `widgets/month_card_sheet.dart` / new `widgets/new_mountain_reveal.dart` |
| V16 / V16b / V22 / RV05 / RV06 / R12 | `screens/review_screen.dart`, `widgets/review_top_card.dart`, `widgets/weak_spot_card.dart`, `widgets/ticket.dart`, `widgets/app_sheet.dart` (new) |
| R03-WeakSpot | `screens/weak_spot_detail_screen.dart` |
| R01-Topics | `screens/topic_practice_screen.dart` |
| R02-Length | R02-Length.png | match | The board's ring (white disc, navy arc, big count); the count rolls while dragging (fix round 1). |
| V17-Consent | `screens/ai_consent_screen.dart` |
| V18-Preparing | `screens/practice_launch.dart`, new `widgets/preparing_view.dart` |
| V19-PracticeQuestion | `screens/practice_screen.dart`, `widgets/question_view.dart` |
| V20-Reviewing | `screens/practice_screen.dart` (submit wait), new `widgets/reviewing_view.dart` |
| V21-PracticeResults | `screens/results_screen.dart` |
| P08-DailyLimit | `screens/practice_launch.dart` (`_showDailyLimitReachedDialog` → sheet) |
| V13 / V13a / V13c / V13b / PW05 | `screens/premium_screen.dart`, new `widgets/paywall_exit_dialog.dart`, new `screens/premium_on_screen.dart` |
| V23-Profile | V23-Profile.png, V23-Profile-420.png | match | Stage, ribbon with "since Sep 2026", stat tiles, the thick shelf with three medals newest first and the running month locked (fix round 1). |
| PF02-Medals / PF03-MedalDetail | `widgets/monthly_medal_collection.dart` |
| PF04-EditName | `screens/settings_screen.dart` (name sheet) |
| R06-AvatarChange (+ R06s storyboards) | `screens/avatar_picker_screen.dart` (turntable + wheel) |
| R07-Language | R07-Language.png | match | Language cards, the selected one navy with a check; keyboard focus restored, look unchanged (fix round 1). |
| R08-Data | `screens/data_screen.dart` |
| R09-Credits | `screens/credits_screen.dart` |
| R11-Offline | new `widgets/error_state.dart`; used by Home, practice launch, getting ready |
| SY02-Snackbar | `utils/app_messenger.dart` |
| SY03-DarkHome | `theme.dart` (`AppColors` extension, dark values) |
| First-wave topics | `models/topic.dart`, `data/topics.dart`, `data/topic_hints.dart`, `proxy/src/topics.ts` (+ tests), flag default off |

### Components (built first, B1–B2)

`AppColors` (ThemeExtension, light + dark), `AppMotion`, `HapticMap`,
`PressableButton` (primary / secondary / text), `CompanionView`,
`DailyTestCard`, `Ticket`, `ScoreCapsule`, `StepBar`, `showAppSheet`,
`CompanionDialog`, the snackbar (`AppMessenger`), `ErrorState`, confetti
(`widgets/confetti_burst.dart`, extended) and `Rays`.

### Risks

- **Scope.** ~65 boards in one run. Mitigation: components first, every
  screen built from them; boards checked by capture; any gap recorded as a
  gap, not hidden.
- **Existing tests pin today's layout** (≈ 2400 tests, many with keys and
  copy). Where the design changes behaviour on purpose the test is updated
  and the commit says so.
- **Per-question grading** must equal the completion award and use the
  existing matching rules exactly; it reuses `DailyTestCompletion` and
  `answer_matching.dart` rather than a copy.
- **Retired avatars**: the stored id format stays `avatar_XX`; the asset
  files of retired avatars are deleted only once nothing references them.
- **Font weights**: raw `fontWeight:` fails `font_weight_guard_test.dart`;
  every weight goes through `withWeight`.
- **l10n guard**: hard-coded user-facing strings fail
  `l10n_guard_test.dart`; every string goes into the 8 ARB files.
- **Simulator time**: one `flutter drive` build captures every board.

### Reaching each screen in the simulator

- Real flow, by hand: fresh install → Splash → Welcome → onboarding
  (turntable, wheel, name, goal, getting ready, mountain intro) → Day-0
  Daily Test → results → Home.
- Everything else (states that need data or time: Home done / loading /
  Premium / rest scene, the ticket states, Review states, practice steps,
  paywall parts, Profile layers, errors, dark theme): the board gallery
  (`tool/ui_polish/`), which mounts the real widgets with sample data, one
  board per driver request.

## B1 — Foundations

Status: **done**.

Commits: `49302e1` (assets moved, registered), `a91ea97` (AppColors,
AppMotion, HapticMap, test config), `85e7160` (PressableButton,
PressableCard), `be7e333` (nine heroes, picker order, retired → Fox, file
and string removal), `0346fc4` (CompanionView). Gallery tooling for the
captures: see B2.

What was built:
- Assets: `assets/companions/` (54 poses), `assets/companions/props/` (6),
  `assets/ui/` (7 objects); registered in `pubspec.yaml`.
- `lib/app_colors.dart` (`AppColors` ThemeExtension, light/dark; wheel
  slice and hero stage colours; `lipCard`), `lib/motion.dart`
  (`AppMotion`), `lib/utils/haptics.dart` (`HapticMap`).
- `lib/widgets/pressable_button.dart`, `lib/widgets/companion_view.dart`.
- `lib/models/avatar.dart`: nine heroes in picker order; retired ids read
  as Fox; `StorageService.getUserProfile` rewrites a retired id to
  `avatar_14` once. Personality traits (SPEC §3.5) in all 8 languages.

Verified:
- `flutter analyze`: no issues. `flutter test`: 2432 passed + the new
  tests; one failure was a stale `build/unit_test_assets` cache (the
  deleted avatar files), passing after the cache was removed.
- New tests: `avatar_test` (9 heroes in order, ids, files on disk),
  `avatar_retired_migration_test` (each retired id → Fox, stored as
  `avatar_14`; current heroes and null untouched), `companion_view_test`,
  `pressable_button_test`, `haptics_test`.
- Simulator (iPhone 18 Pro, light): V00-CompanionSystem,
  V00-MotionSystem, X01-ExpressionKit, X03-HeroSet captured through the
  board gallery; poses, props and their placement match the boards.

## B2 — Shared components

Status: **done**.

Commits: `9186d21` (strings), `a1e08b9` (StepBar, ScoreRing,
SkeletonBar), `5cb8578` (DailyTestCard), `6cb7aa2` (Ticket), `1a7fca5`
(ScoreCapsule, showAppSheet, CompanionDialog, ErrorState, Rays, confetti
length/count), `53b8006` (SY02 snackbar), `db2e521` (gallery boards).

What was built (all colours from `AppColors`, durations from
`AppMotion`):
- `widgets/daily_test_card.dart` — X05 skeleton, loading / todo / done.
- `widgets/ticket.dart` — X04 free / tearing / used, notches cut out of
  the path, the tear (≈ 700 ms) with haptics medium + light, the used slot
  with the time left to local midnight.
- `widgets/score_capsule.dart` — V14 capsule; tier maths from
  `MonthlyMedalRules`.
- `widgets/step_bar.dart`, `widgets/score_ring.dart`,
  `widgets/skeleton.dart`, `widgets/app_sheet.dart`,
  `widgets/companion_dialog.dart` (R10 pattern), `widgets/error_state.dart`
  (R11), `widgets/rays.dart`; `utils/app_messenger.dart` now draws SY02.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: 2450 passed, 6
  failed — all six in `practice_submit_consent_test.dart`, whose helper
  cast the snackbar content to `Text`; fixed (reads the first `Text` in
  the capsule), the file passes.
- New tests: `daily_test_card_test` (350 × 256 in all three states, also
  at text scale 2.0 and 3.1 with the Large app text size, no overflow;
  slot contents per state), `ticket_test` (three states render; tear plays
  then `onTorn`, haptics medium + light; same size in all states, compact
  and full), `b2_components_test` (dialog results and haptics, error state
  retry dots + haptics + copy per kind, StepBar fills one by one, capsule
  tier maths and badge), messenger tests for SY02.
- Simulator (iPhone 18 Pro, light): X04-Ticket, X05-DailyCard, R10-Leave,
  R11-Offline, SY02-Snackbar captured. Match: card rows, colours and the
  ticket's notches, tear and used slot as on the boards; the dialog's
  scrim was darker than the board's and was lightened to 45 %.

Decisions:
- **D2-1 Ticket "20:41 NEXT".** The board's ARIA label reads "Next ticket
  in 20 hours 41 minutes" and SPEC says the slot "updates every minute":
  the slot shows the **time left** until local midnight (h:mm), not a
  clock time.
- **D2-2 Text scaling inside fixed components.** The Daily Test card's
  rows have fixed heights, so its text is clamped to 1.0× (the card never
  grows, X05); the title shrinks from 26 to 22 before it truncates. The
  ticket's text is clamped to 1.15×.
- **D2-3 Snackbar.** SY02's capsule replaces the Material bar's look; the
  slide uses `ScaffoldMessenger`'s own entrance (250 ms, easeOutCubic),
  which fades and slides rather than moving from exactly 120 %.

## B3 — Launch and onboarding

Status: **done**.

Commits: `7435559` (strings), `af5cbff` (BuddyPicker turntable, lucky
wheel, SpeechBubble), `e6807b1` (onboarding V04–V05, getting ready V05b,
mountain intro V06, R06 picker; the carousel removed), `fde5fe8`
(Welcome V02), `51d38d6` (splash V01, launch image regenerated),
`531a525` (dead strings removed), `3b70896` (gallery scripts), `de8bc02`
(MountainScene, V06 on the whole mountain).

What was built:
- V01 `widgets/launch_splash.dart`: the app icon drawn from its shapes
  (square pop, lens from the bottom right, lines, glint), wordmark rise
  and a small lens scanning it; first launch 1.4 s (no profile yet, read
  in `main.dart` before the first frame), later launches 600 ms; Reduce
  Motion = one 150 ms fade; light haptic when the square lands. The iOS
  static launch image (the first frame: the square at 50 %) regenerated
  with `scripts/generate_launch_image.sh` (a local render, no network).
- V02 `screens/welcome_screen.dart` (+ `data/welcome_demo.dart`, English
  content).
- V03 / R06 `widgets/buddy_picker.dart` (turntable), V03b
  `screens/lucky_wheel_screen.dart` (`pickLuckyHero`: never the current
  buddy, never the previous result), `screens/avatar_picker_screen.dart`.
- V04 / V05 `screens/onboarding_screen.dart` (buddy → name → goal).
- V05b `services/getting_ready.dart` (`GettingReadyModel`) +
  `screens/getting_ready_screen.dart`; `screens/first_launch_flow.dart`
  runs the three real tasks (save profile, today's set, resolve this
  month's mountain).
- V06 `screens/mountain_intro_screen.dart` on the new
  `widgets/monthly_climb/mountain_scene.dart`.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2443 passed**
  (before the V06 rework; the V06 commit adds `mountain_scene_test`,
  run on its own: pass).
- New tests: `lucky_wheel_test` (400 seeds × every current × every
  previous: never current, never previous; every other hero reachable),
  `getting_ready_test` (never past a stop while its task runs; 1.8 s
  minimum, done < 2.3 s for instant work; timeout at 8 s; retry keeps the
  bar), `onboarding_screen_test` (rewritten), `avatar_picker_screen_test`
  (rewritten), `mountain_scene_test` (cover: no empty band at any zoom).
- Tests changed on purpose (said in the commits): onboarding / first
  launch / climb / preview / widget tests walk the new steps; the profile
  is saved before today's set (SPEC §1.6 order); launch tests follow V01's
  timing; Welcome's wordmark test; Home's and Profile's picker tests use
  "Save <Hero>".
- Simulator (iPhone 18 Pro, light), through the gallery with real taps:
  V01 (mid-assembly and final), V02, V03, V03b (ready and landed), V04,
  V05 (Work chosen), V05b (mid-way and 100 %), V06, R06, R06s-B1
  (resting, mid-turn, Panda in front), R06s-D (ready, spinning, landed).
  Match: layout, colours, copy and states as on the boards. Gaps: V04 is
  captured without the iOS keyboard (flutter_driver's text entry); V01's
  wordmark scan lens is the brand loupe, not the board's navy outline
  lens.

Decisions:
- **D3-1 Onboarding order.** V03 buddy → V04 name → V05 goal; the step
  indicator counts 4 (buddy, name, goal, mountain) on every step; V05's
  bar reads "3 of 4" (the board's "2 of 3" is sample data that contradicts
  V03/V04's four dots).
- **D3-2 Goal subtitle.** The board's "You can change it later in
  Profile" is not true (Profile has no goal setting); the line is "Pick
  one. It helps us decide what to improve next." (SPEC §1.12: no promise
  of personalised content).
- **D3-3 Privacy line on V05 kept.** The board shows none; the goal is
  still reported as the `learning_goal` user property, so the existing
  disclosure and the "Your data & AI" sheet stay, small, under the cards.
- **D3-4 Getting ready's task order** follows its rows (profile, then the
  Day-0 set, then the mountain). The old code wrote the set first; if the
  app is killed between the two, the Daily Test fetches today's shared set
  instead of the bundled Day-0 set (the old fallback path).
- **D3-5 First launch for the splash** = no profile yet, read with one
  local query started before the first frame; if it has not answered when
  the lens would start (280 ms), the full assembly plays.
- **D3-6 Turntable starts with Fox** (the board's "1 / 9"), not a random
  buddy.
- **D3-7 R06 saves with the button.** The carousel's autosave is gone;
  "Save <Hero>" saves, Back leaves the buddy unchanged. The Hero flight
  from Home/Profile is dropped (the turntable has no single tile to fly).

## B4 — Daily Test and rewards

Status: **done**.

Commits: `a879129` (strings), `95d1520` (on-device grading), `ea04792`
(graded answer look, red button, highlighted step), `ead1918` (Daily
Test V07–V09 / Q04 / Q05 / R10, results V10, badge V11, medal R05),
`03dc9e6` (gallery).

What was built:
- `services/daily_test_grading.dart` (`QuestionCheck`): one answer graded
  with the completion's own rules (`DailyTestAnswerResult.from`), points
  by `MonthlyMedalRules` (display only; storing is unchanged, at the end
  as before); per-blank results for multi-blank questions by splitting the
  key at the template's fixed text.
- `screens/daily_test_screen.dart`: header (close, 5 segments, points
  chip with the clay star), the buddy and its bubble, Skip + Check
  ("Finish" on the last question), the feedback sheet (V08 / V09), the
  "+N" star flight, the R10 leave dialog.
- `screens/daily_test_result_screen.dart` (V10): "Day N complete!", the
  stepwise ring, strip, tiles, "Your answers" rows (open to the old card's
  explanation logic, unchanged), the button in the bottom slot.
- `widgets/medal_celebration.dart` (V11 / R05): navy page, turning rays,
  the medal popping and floating over the cheering companion, eyebrow,
  "N points in <month>!" and "<Next> is next at N. Keep climbing <mountain>."
  (thresholds from `MonthlyMedalRules`), a Continue button.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2454 passed**
  (after the test updates below).
- New tests: `daily_test_grading_test` (every check equals the
  completion's result for the day-0 set and many answers; the shown total
  equals `MonthlyMedalRules.score` of the completion; +2/+1/0; per-blank
  split), `daily_test_check_test` (right: "Nice, Ada!", +2, success; wrong:
  "Almost!", the key, +1, warning, read-only box; a whole test: the chip
  counts the award and the answers handed over are the checked ones).
- Simulator (gallery, real taps): V07, V08, V09, Q04 (typed and checked:
  blanks green / orange / green), Q05, R10, V10, V11, R05.

Decisions:
- **D4-1 Skip stays** (a quiet text button next to Check): the board has
  none, but skipping is an existing rule (a skipped question is not
  wrong, 0 points) that SPEC §1 does not change.
- **D4-2 No Back in the Daily Test.** With per-question feedback a
  checked answer is final; the board's header has only close, the
  segments and the points.
- **D4-3 The last question** reads "Finish" (Q05) and still checks; the
  sheet's button then reads "See results".
- **D4-4 "Saved to your weak spots" → "This goes to your weak spots".**
  Mistakes are written at the end of the test (unchanged); leaving the
  test saves nothing, so "saved" would not be true yet.
- **D4-5 The buddy's row under the question** sits above Check (not
  directly under the answer box: `QuestionView`'s keyboard-safe layout is
  unchanged) and is hidden with the keyboard up and on phones under 740 pt
  tall, so the open hint card stays whole (`topic_hint_card_test` fit
  checks).
- **D4-6 The results' button is navy** in every case (V10), replacing the
  1.2.0 orange/navy split for this screen; "Start my climb" reads "Climb
  my first step".

Not done / gaps:
- V08's "+2" star flies on a fixed path (sheet → chip), not measured from
  the chip's position; V09's book icon does not fly to the Review tab (the
  test screen is a pushed route with no nav bar visible).
- Q04's "breathe" of a tapped blank and the "—" fill animation keep the
  existing 1.4.0 look.
- V07's hint handle "nudge every 2.8 s" is not added (hint slider as in
  the app today, SPEC V07).

## B5 — Home and mountain

Status: **done**.

Commits: `592ef64` (strings), `e6bf38b` (Home, rest scene, first climb, month change, tests), `00130c7` (gallery).

What was built:
- Home (`screens/home_screen.dart`, V15 / V14 / H04): the wordmark with the
  score capsule (points, ring to the next medal, today's "+N"; a tap opens
  Profile), the greeting, the DailyTestCard (`todo` / `done` / `loading`),
  the mountain card with its bubble ("Step N is one test away!" / "Step N
  opens tomorrow"), then for a free user the compact ticket ("Use it on:
  <weak spot>", to Review) and the topic showcase (`widgets/home_practice.dart`:
  the weak spot's topic "Picked for you", locked floating tiles, "Unlock
  all N topics" to the paywall); for Premium the practice card ("Sessions
  today n/5" segments, unlocked tiles, "Practice your weak spot").
- H03: the mountain card's skeleton while the month loads.
- V24 rest scene (`widgets/rest_scene.dart`): replaces Home's content only
  when every daily right is used (§1.8: today's test done and the free
  ticket used, or every Premium session); camp at the companion's step,
  tent, campfire (logs image, two flame layers, sparks, ground light), the
  companion asleep with Zzz, "See you tomorrow, <name>", the done tiles and
  a countdown to local midnight updated every minute. No reminder switch.
- V12 first climb (`screens/first_climb_screen.dart`): one camera on the
  whole mountain (cover framing) wide → 2.2× → walk in 0.45 s hops with the
  trail painting → wide; "Step 1 of N" pops on arrival (light + success);
  bubble and Continue after the camera. Shown in the first-launch flow
  after "Climb my first step".
- R04 / R04b (`widgets/month_card_sheet.dart`): the month change as two
  full-screen pages instead of the bottom sheet: the recap (header medal
  that swaps bronze → silver, "<Tier> on <mountain>!", last month's
  mountain edge to edge with gold step dots, steps / points / "to <next>",
  the points bar filling stop by stop through `MonthlyMedalRules`'
  thresholds with a jiggle and light haptic at each stop and success at the
  month's medal, the near-miss line, "See my new mountain") and the new
  mountain (rises 40 px + fade, flag pops, the companion drops and hops,
  "A new mountain!", steps and medal lines, "Start climbing").
- The first tab is labelled "Climb" (every board's nav bar).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2438 passed**.
- New tests: `b5_home_mountain_test` (V12 camera timeline, cover framing at
  every 100 ms, arrival haptics, skip, Reduce Motion; V24 countdown to
  midnight, minute updates, no switch); Home's new group in
  `home_screen_test` (card lines and buttons, bubble, capsule → Profile,
  ticket → Review, showcase → paywall, Premium practice card, live
  entitlement change, order, rest scene for free and Premium and not with
  practice left); `month_card_test` rewritten for R04 / R04b (bar stops,
  haptics, medal, near-miss, fresh, closing, events); first-launch tests
  walk through V12.
- Simulator (gallery): V15, V14 (+ scrolled), H03, H04 (+ scrolled), V24,
  V12, V12b (three key frames), R04, R04b.

Decisions:
- **D5-1 Home's avatar, weak spot list, topic strip and Review call-out
  are gone** (V14 / V15 / H04 have none of them). The ticket takes the
  call-out's job (to Review, the same slide), the showcase the strip's
  (to the paywall, the same `source: home`), Premium's "Practice your weak
  spot" the weak spot list's (the most frequent weak spot). The avatar is
  still changed in Profile (R06).
- **D5-2 Tab label "Climb".** Every board's nav bar says "Climb" (the app
  said "Home"); the key `navHome` keeps its name, the 8 values change.
- **D5-3 V12 is the first run's zoom.** When the Day-0 test earns a step,
  the first-launch flow shows V12 full screen after "Climb my first step";
  it claims the same one-time flag (`first_run_zoom`) and sends the same
  `month_zoom_ended` (trigger `first_run`, outcome completed / skipped /
  reduce_motion) Home's in-card zoom sent, so no new event. Home then skips
  its in-card zoom but still walks the step on the card and opens the
  Day-0 paywall after it, as before. With no step (all skipped), Home's
  in-card zoom plays as before. The flow now takes the app's clock (tests
  pin the month).
- **D5-4 The month change is full screen** (R04 → R04b; R04b alone for
  the fresh variant). It closes with "Start climbing" (`method: button`)
  or the system back (`method: barrier`); a swipe down no longer exists
  (the `drag` value stays in the enum, unused). Home's month-change zoom
  after it is unchanged.
- **D5-5 V24's practice tile** reads "Ticket used" for free users and
  "n/5 sessions" for Premium; the countdown is `HH:MM` to local midnight
  (the Daily Test's day boundary).
- **D5-6 No trial promise on Home**: the showcase's button says "Unlock all
  N topics" (the paywall states the offer, §1.7).

Not done / gaps:
- V15's gold ring pulse on the next step and V14's capsule "+9" pop are
  the existing mountain and capsule visuals (the ring fill animates; no
  separate pulse ring on the step).
- H03's companion "think" pose and the 8 s R11 fallback come from the
  shared DailyTestCard / Home load paths (no new timeout added).
- R04's trail dots light in order (60 ms apart) but the bar's medal lines
  glow by scale only.

## B6 — Review

Status: **done**.

Commits: `20afb23` (strings), `4f4e250` (Review, weak spot, tests), `1bf37c4` (gallery).

What was built:
- Review (`screens/review_screen.dart`, V16 / V16b / V22 / RV05 / R12):
  the title (with the Premium chip for Premium) and "Your mistakes, turned
  into practice."; for a free user the shared Ticket on top — free ("Pick
  a weak spot below…"), tearing ("Ticket used!"), used ("Used today",
  "Nice work, <name>.", the next ticket's countdown to local midnight,
  updated every minute) or waiting for the first weak spot (RV05); for
  Premium the navy Suggested Focus. "Weak spots" with its count and the
  sort button; each weak spot as a card with its topic, a "new" chip
  (saved once), "N times · when", its title and its latest mistake inline
  (`widgets/review_parts.dart`, `InlineMistake`: wrong words struck through
  in red, the correction in green, from the stored answer and correction
  through `diffAnswer`). "Practice with my ticket" on the first card tears
  the ticket (medium haptic) and then starts the weak spot's practice
  through `launchPracticeSet` (AI permission, quota and generation as
  before; the free count changes only when a set is made). Used: "Want more
  practice today? Premium: up to 5 sessions a day" → the paywall
  (`review_quota`).
- RV05: the ticket waiting, the cheering companion (two hops), "No weak
  spots yet!", "Take today's Daily Test" (navy, as the board).
- RV06: the sort sheet (`showReviewSortSheet`): two big options, the
  selected one a navy card with a check; the list cross-fades to the new
  order.
- R03 (`screens/weak_spot_detail_screen.dart`): topic eyebrow, title,
  "N times · last seen …", the buddy saying the stored rule ("Remember:
  …"), "Your mistake" with the latest mistake inline and its explanation,
  and today's ticket ("Use today's ticket", tears, then practice) for a
  free user, "Practice this" for Premium; the used state keeps "Practice
  with Premium" and the used-today message.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2421 passed** (the
  free practice card's tests were replaced by ticket tests).
- Tests: `review_screen_test` rewritten (ticket states, the countdown at
  03:19 → 20 h 41 min, the tear then the AI permission, the inline line,
  the sort sheet, the empty state, Premium); `review_suggested_focus_test`,
  `weak_spot_detail_screen_test`, `button_rule_test`,
  `practice_launch_*_test` and `tab_switcher_test` follow the new controls.
- Simulator (gallery): V16, V16b (mid-tear and the AI permission that
  follows), V22, RV05, RV06, R03, R12.

Decisions:
- **D6-1 No mastery strips** (R03 "0/3", R12, V22). The app stores no
  per-weak-spot count of correct practice sessions and SPEC §1 defines no
  mastery rule; adding one would be a new business rule and new stored
  data. Left out; the layouts keep their spacing without them. Easy to add
  with a stored count later. **Deferred (owner, fix round 1):** mastery
  strips are not part of this run; they will be designed later as a
  separate feature.
- **D6-2 "new" chip** = a weak spot saved once (`frequency == 1`); the
  boards' "practiced today" chip is left out (no per-weak-spot practice
  record).
- **D6-3 The free practice card (1.2.0) is replaced by the Ticket** on
  Review and R03; its "See Premium" moves to V22's "Want more practice
  today?" card (same paywall source).
- **D6-4 RV05's button is navy** (the board), replacing the 1.2.0
  "forward actions are orange" rule for this one button.
- **D6-5 R03 shows the latest mistake only** (the board's "Your mistake");
  the older "Recent mistakes" list and the separate "Saved feedback" panel
  are folded into that one card.

Not done / gaps:
- V22's "new stub slides in at midnight" plays only if Review is open at
  midnight (the state is re-read when the tab is shown again).
- R12's focus card glint and the weak spot cards' mastery fill are not
  drawn (D6-1).

## B7 — Practice

Status: **done**.

Commits: `9ea926e` (strings), `9a8024d` (practice screens, first-wave topics in the app, tests), `1fc2a1c` (proxy, switched off), `d872413` (gallery).

What was built:
- R01 (`screens/topic_practice_screen.dart`): the header with the Premium
  chip, "Pick a topic. AI reviews every answer.", the most repeated weak
  spot's topic as a navy "Picked for you" card, then the topics two a row
  in their colours (floating, 2 pt press, light haptic) with the real
  status line. The list is `practiceTopics()`.
- R02 (`screens/practice_length_picker.dart`): the existing 3 / 5 / 10
  slider in the shared sheet, an orange knob and track, selection haptic at
  each stop, the pressable orange Start whose label cross-fades.
- V17 (`screens/ai_consent_screen.dart`): the same text, each section a
  card with its icon fading in 40 ms after the one above, the navy
  pressable "Agree and continue" (medium haptic), "Not now" unchanged.
- V18 (`widgets/practice_preparing.dart`, through `PageLoading(topic:)`):
  the thinking companion, three question skeletons and the topic's hint
  cards rotating every 3 s under "Did you know?" — on Topic Practice, the
  weak spot screen and Review.
- V19 (`screens/practice_screen.dart`): "AI reviews all your answers when
  you finish" above Skip / Next (hidden with the keyboard up and under
  740 pt, as the Daily Test's buddy row).
- V20 (`widgets/practice_reviewing.dart`): the inspecting companion, the
  answers with the clay lens sweeping over them (3.2 s), a checklist ticking
  0.8 s apart (light haptic each), an indeterminate bar; success haptic
  when the result arrives.
- V21 (`screens/results_screen.dart`): the cheering companion and "N/M
  correct", feedback cards entering from below 60 ms apart with a Correct /
  Needs work / Skipped pill and the existing breakdown; a free user out of
  practice gets "Want another round today? Premium: up to 5 sessions a
  day, every topic." with See Premium (same events and paywall source).
- P08 (`showDailyLimitSheet` in `practice_launch.dart`): a sheet with the
  sleeping companion, the full session counter and the existing text.
- Practice R10: the leave confirmation is the companion dialog ("Keep
  going" / "Leave").
- First-wave topics (§1.11): `TopicId` gets Conditionals, Passive Voice,
  Prepositions, Relative Clauses and Comparatives & Superlatives;
  `kFirstWaveTopics` with icons, titles (English, like every topic title),
  descriptions in 8 languages, hint cards, tile colours;
  `kFirstWaveTopicsEnabled = false`; `practiceTopics()` adds them only when
  on. The Daily Test keeps its five (`FallbackPool.problemWithSet` now
  checks `kTopics`). Proxy: `FIRST_WAVE_TOPICS` and
  `FIRST_WAVE_TOPICS_ENABLED = false` in `proxy/src/topics.ts`;
  `topicById` / `isKnownTopicId` know them only when the flag is on;
  `TOPICS` (the Daily Test's) is unchanged. Not deployed; no generation or
  measurement was run.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2426 passed**.
- New: `first_wave_topics_test` (flag off: Topic Practice shows the five
  and no first-wave card; flag on: ten, every first-wave topic with its
  title, description, hint card and colours, and a card on screen);
  `proxy/test/topics.test.ts` (flag off: unknown ids, the five unchanged;
  flag on: known). Proxy: `tsc --noEmit` clean; 8 test files touching
  topics, 312 tests, passed (local vitest, nothing sent anywhere).
- Updated: results, results footer, Topic Practice, length picker, exit
  dialog, button rule, question and hint-card tests.
- Simulator (gallery): R01, R02, V17, V18, V19, V20, V21, P08.

Decisions:
- **D7-1 No mastery strips** on R01 / V21 (D6-1). **Deferred (owner, fix
  round 1)**, as D6-1.
- **D7-2 P08 keeps the existing sentence** ("Come back tomorrow for more —
  your progress is saved"): the board's "Fresh sessions open tomorrow,
  right after your Daily Test" would tie sessions to the Daily Test, which
  is not a rule. A free user at the limit still goes to the paywall
  (existing flow), so "See Premium" is not on this sheet.
- **D7-3 "Back to topics" stays** the results' button label (the board
  says "Done"); same action.
- **D7-4 `topicByName` knows the first-wave ids** (they are real, switched-
  off topics); nothing stores them while the switch is off.
- **D7-5 V17 has no extra consent switch**: the board's two buttons are the
  consent (Agree / Not now); adding a toggle would change the 5.1.2(i) flow.

Not done / gaps:
- R02's ring and number keep the existing selection card's navy dial; the
  number does not roll.
- V18's skeleton bars are faint on the card colour.
- V19's "Next" slide-in and V21's mastery step are not animated.

## B8 — Paywall

Status: **done**.

Commits: `2981ab0` (paywall, PW05, strings, tests), `f303bad` (gallery).

What was built (`screens/premium_screen.dart`, one scrolling page, §1.7):
- V13: the companions, the headline with the user's name ("Turn today's
  mistake into progress, <name>."; the old line when no name is known),
  the weak spot line, the three benefit rows and "See plans" (scrolls to
  the plans). No price boxes on the first view; the pinned footer keeps the
  orange trial button, the full price / renewal line and Restore · Terms ·
  Privacy, as before.
- V13a: the plans (the existing vertical list, yearly preselected) after
  "See plans"; the pinned button's text follows the selected plan
  (existing).
- V13c: Free vs Premium is always on the page after the plans (the toggle
  is gone), then the trial timeline ("Today: everything in Premium
  unlocks. Nothing to pay." / "Day N: the trial ends and the plan starts.
  Cancel before then to pay nothing."), shown only with a trial counted in
  days or weeks. Once the plans have scrolled away, "<Plan> plan" sits
  above the pinned button.
- The comparison row counts the real topics ("Topic Practice, all N
  topics", `practiceTopics().length`), as the benefits row already did.
- V13b: the close button opens, once per app session, the companion dialog
  (sad): "Leaving already, <name>?", a line about the weak spots (no
  discount), the trial button (starts the purchase) and "Continue with
  free" (closes with `method: close_button`); light haptic. Without an
  offer, while purchasing or after a purchase, the close button closes as
  before.
- PW05 (`screens/premium_on_screen.dart`): after a purchase or a trial
  start, a navy celebration page — turning rays, the cheering companion,
  "Premium is on!", the three unlocked things (real counts) sliding in 120
  ms apart, "Your free trial ends on <date>." when a trial in days started,
  confetti once, success haptic; Continue closes the paywall with no
  dismissal event (as the footer's Continue). Pending and failed purchases
  keep the footer messages.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2428 passed**.
- `premium_screen_test`: the comparison on the page after the plans and
  "See plans"; V13b (first close asks, sad companion, no discount, "Continue
  with free" logs `close_button`, a second paywall closes at once; the
  primary starts the purchase); success opens PW05 (end date with a trial,
  none without) and its Continue fires onDone and returns, with no
  `paywall_dismissed`. `l10n_layout_test` reads the table without a toggle.
- Simulator (gallery, the debug fixture offering): V13, V13a, V13c, V13b,
  PW05.

Decisions:
- **D8-1 The comparison is always on the page** (§1.7 "13 → 13a → 13c");
  the 1.2.0 "Compare Free & Premium" toggle is removed.
- **D8-2 V13b once per app session** (a static flag; a new launch asks
  again), and only when the trial button would work (an offer loaded).
- **D8-3 The trial timeline names no reminder**: the app sends no
  notifications (N01–N03 are out of this run), so it says only what is
  true — today unlocks, day N the plan starts unless cancelled.
- **D8-4 The headline keeps the 1.2.0 line when no name is stored**; with a
  name it is the board's personal line.

Not done / gaps:
- The plans do not enter from below on scroll, the table rows do not
  appear 40 ms apart, and the "See plans" arrow does not nudge.

## B9 — Profile

Status: **done**.

Commits: `f98eac1` (Profile, name sheet, medals layer, language, data, credits, the dialog fix, tests), `5c39c65` (gallery). Strings in `2981ab0`.

What was built:
- V23 (`widgets/profile_stage.dart` in `screens/settings_screen.dart`): the
  companion on its coloured stage (it waves when tapped) with "Change"
  (→ R06); the navy ribbon settling from 12 pt below with the name,
  "Climbing with <Hero>" and the pencil (→ PF04); three stat tiles (this
  month's points, step, weak spots saved). The medal shelf, its progress
  card and every settings row stay as they were.
- PF02 (`widgets/medals_layer.dart`): "See all" opens every medal over the
  blurred profile (blur 0 → 10, panel 0.92 → 1), by year, newest first, the
  running month grey, the Welcome badge last; X or a tap outside closes it.
- PF03: a medal in the layer opens the existing medal detail (the medal
  large, month, theme, outcome, steps and points).
- PF04: the pencil opens a sheet above the keyboard where the companion
  asks "What should I call you?"; Save (light haptic) stores the trimmed
  name (40 characters at most, as in onboarding) and shows "Name saved"
  with Undo, which puts the previous name back.
- R07 (`screens/language_picker_screen.dart`): each language its own card
  in its own name, the selected one navy with a gold check; selection
  haptic; the note that questions stay in English (existing) on top.
- R08 (`screens/data_screen.dart`): the reset confirmation is the companion
  dialog (sad, heavy haptic as it opens), "Keep my progress" primary and
  "Reset progress data" the quiet red action; texts unchanged.
- R09 (`screens/credits_screen.dart`): three companions greet on top
  (floating, the middle one waving); the attribution text is unchanged.
- The companion dialog now closes once: a second tap while the card closes
  no longer pops the page under it (found by the Data screen's double-tap
  test).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2424 passed** (+ the
  medals layer test).
- Updated: `profile_layout_test` (V23, PF04 with Undo, PF02 and PF03, the
  40-character rule), `settings_screen_test`, `data_screen_test`,
  `data_screen_final_test`, `l10n_test`, `credits_screen_test`.
- Simulator (gallery): V23 (+ scrolled), PF02, PF03, PF04, R07, R08, R09.

Decisions:
- **D9-1 No "since <month year>"** on the ribbon: the app stores no date the
  profile was made. Shown: "Climbing with <Hero>". **Closed in fix round
  1:** "· since <month year>" from the first Daily Test on record.
- **D9-2 The medal shelf keeps the existing strip** (horizontal, every
  medal) rather than the thick 3-medal shelf image; "See all" adds the
  board's layer on top of it. **Closed in fix round 1:** the board's shelf
  is built.
- **D9-3 PF03 is the existing medal detail** (a dialog), opened from the
  layer; the Hero flight from shelf to sheet is not built.
- **D9-4 The language options lost keyboard focus traversal** (they are
  pressable cards, not InkWells); VoiceOver reads them as selected
  buttons as before. **Closed in fix round 1:** keyboard focus is back.

Not done / gaps:
- The ribbon's medal-settle and the numbers' count-up in PF03 are not
  animated; the layer opens with a fade and scale, not a Hero flight.

## B10 — System and themes

Status: **done**.

Commits: `5dabea0` (R11 on Home, the sweep and its fixes), `2aa88bd` (gallery).

What was done:
- R11 everywhere a load can fail: the Daily Test (B4), getting ready (B3)
  and Review (B6) already use `ErrorState`; Home's month progress error now
  does too (sad companion, "Try again" with dots, the same retry).
  Generation and scoring failures keep the one snackbar (SY02).
- SY02 everywhere: every message in `lib/` goes through `AppMessenger`
  (no direct `showSnackBar` left); "Name saved" carries Undo.
- SY03 dark theme: every new component takes its colours from `AppColors`
  (light and dark tokens); dark captures of Home (SY03), Review, Profile,
  the month recap, a question and the first climb.
- Arabic (RTL), the largest text size and Reduce Motion: a sweep test
  (`test/b10_system_pass_test.dart`) renders every new screen and component
  — the Daily Test card's three states, the ticket's states, the score
  capsule, the rest scene, the topic showcase and practice card, Review's
  card and empty state, practice preparing and reviewing, the profile
  stage, the error state, the first climb, the month recap and new
  mountain, Premium on — at 320 pt in dark, in Arabic, at Large text with a
  1.3 system scale and with Reduce Motion; nothing overflows or throws.
  Arrows flip under RTL in every new button.
- Found and fixed by the sweep: a ticket built already tearing read the
  Reduce Motion setting before it could (now in `didChangeDependencies`);
  the practice card's sessions row overflowed at 320 pt (the label wraps);
  Premium on overflowed a 640 pt screen (its content scrolls, the button
  stays).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2477 passed** (52 of
  them the sweep).
- Simulator (gallery, `:dark`): SY03-DarkHome, V16, V23, R04, V07, V12.

Not done / gaps:
- Arabic and the largest text are checked by tests, not by simulator
  captures (the gallery runs in English at the default size).

## B11 — Final sweep and docs

Status: **done**.

Commits: `a4228b3` (formatting), `cd3c33d` (docs and comparison), and the commit that records these hashes.

What was done:
- Every in-scope board captured again on the iPhone 18 Pro simulator (iOS
  27.2, light, English; SY03 in dark) with `tool/ui_polish/capture.sh`,
  into `build/ui-polish-captures/` (not committed), and compared with
  `handoff/screens/<ID>.webp` and the board HTML. The table below is the
  result; "gap" rows name what differs and why.
- Docs: `docs/build-log.md` (dated entry), `docs/roadmap.md` (status of
  "UI polish + 4th tab"), `product.yaml` (one `recent` entry, trimmed to
  five, `updated_at`), this file's final summary.
- Final checks after the last code change: `flutter analyze` — no issues found; `flutter test` — 2477 passed, 0 failed (run after the last code change, the formatting of `practice_launch.dart`).

### Board comparison

All 65 in-scope boards (SPEC §2: every board but W01, N01, N02, N03). After fix round 1: **65 match** (some name small motion gaps in their note). Fix round 1 recaptured V05, V07, V09, Q04, V15, R04, R12, R02, V13, V13a, V13c, V23, PF02, PF03 and R07 and closed B11's three gaps (V09, R02, V23).

**Fix round 2 (SPEC v10, iPhone 18 Pro Max simulator, 440 × 956):** 69 in-scope boards with the new V24f, V24s, V13r and PW05r; **69 match**. Recaptured: V02, V05, V05b, V06, V12, V13, V13a, V13b, V13c, V14, V15, V23, V24, PF02, PF04, PW05, R04, R04b, R09, and the four new boards. "-t2" captures are the same board 0.55–1.5 s later (item 1's evidence that the companions move). Rows not listed keep their earlier capture (18 Pro, 402 × 874).

| Board | Capture(s) in `build/ui-polish-captures/` | Match / gap | Note |
|---|---|---|---|
| V00-CompanionSystem | V00-CompanionSystem-500.png, V00-CompanionSystem.png | match | System sheet: nine heroes, moods, props (gallery board). |
| V00-MotionSystem | V00-MotionSystem.png | match | Motion tokens, buttons, colours. |
| X01-ExpressionKit | X01-ExpressionKit.png | match | Four heroes × five moods; sad/sleep filters per SPEC X01 (D1-2). |
| X03-HeroSet | X03-HeroSet-400.png, X03-HeroSet.png | match | 9 heroes × 6 poses. |
| X04-Ticket | X04-Ticket-420.png, X04-Ticket.png | match | Free, tearing, used; compact and full. |
| X05-DailyCard | X05-DailyCard-560.png, X05-DailyCard.png | match | One 256 pt skeleton for loading / waiting / done. |
| V01-Splash | V01-Splash-mid.png, V01-Splash.png | match | Logo build-up mid frame and end. |
| V02-Welcome | V02-Welcome.png, V02-Welcome-t2.png | match | Demo card, companions, Get started; fix round 2: the side companions float, Fox sways (two moments). |
| V03-Meet | V03-Meet.png | match | B1 turntable, Fox in front. |
| V03b-LuckyWheel | V03b-LuckyWheel-ready.png, V03b-LuckyWheel.png | match | Ready and landed frames; never the current buddy. |
| V04-Name | V04-Name.png | match | Typed name, the companion's reaction. |
| V05-Goal | V05-Goal.png | match | Fix round 2: four goal cards (School & university third, lilac), the board's v10 sizes; all four and Continue on the first view. |
| V05b-GettingReady | V05b-GettingReady-100.png, V05b-GettingReady.png | match | Stops at real work (⅓, ⅔, 1); fix round 2: at least 1.2 s per stop, at least 4 s on screen. |
| V06-MountainIntro | V06-MountainIntro.png, V06-flag-*.png (test renders) | match | Fix round 2: the flag's foot on the summit (the trail's last point) at every size. |
| R06-AvatarChange | R06-AvatarChange.png | match | Turntable from Profile, "Save <Hero>". |
| R06s-B1-Turntable | R06s-B1-Turntable-1-resting.png, R06s-B1-Turntable-2-turning.png, R06s-B1-Turntable-3-panda.png | match | Storyboard frames of the turntable. |
| R06s-D-Wheel | R06s-D-Wheel-1-ready.png, R06s-D-Wheel-2-spinning.png, R06s-D-Wheel-3-landed.png | match | Storyboard frames of the wheel: ready, spinning, landed. |
| V07-Question | V07-Question.png | match | Check footer, points chip; gap: the hint handle's nudge is not added (B4). |
| V08-Correct | V08-Correct.png | match | Green sheet, +2; gap: the star flies on a fixed path (B4). |
| V09-Wrong | V09-Wrong-book.png, V09-Wrong.png | match | Orange sheet, the key, +1; the book flies to the Review tab's place (fix round 1; the first capture is mid-flight). |
| Q04-MultiBlank | Q04-MultiBlank-typed.png, Q04-MultiBlank.png | match | Per-blank colours after Check; the focused blank breathes (fix round 1); gap: the "—" fill keeps the 1.4.0 look. |
| Q05-ErrorCorrection | Q05-ErrorCorrection.png | match | Last question reads Finish. |
| V10-Results | V10-Results.png | match | Stepwise ring, strip, tiles, answer rows. |
| V11-Badge | V11-Badge.png | match | Navy page, rays, the Welcome badge over the companion. |
| R05-Medal | R05-Medal.png | match | Tier medal, next threshold from MonthlyMedalRules. |
| R10-Leave | R10-Leave.png | match | Companion dialog over the question, Keep going / Leave. |
| R11-Offline | R11-Offline.png | match | Sad companion, calm line, Try again with dots. |
| SY02-Snackbar | SY02-Snackbar.png | match | One dark capsule with icon and Undo. |
| V15-HomeNextDay | V15-HomeNextDay.png, V15-HomeNextDay-t2.png, V15-HomeNextDay-360.png | match | Fix round 2 (Pro Max): the greeting on one line with the name bold; the pawn and its gold ring above the nav bar in the first frame; the card's companion hops (two moments). |
| V14-Home | V14-Home-520.png, V14-Home.png | match | Navy card, capsule +N, ticket, topic showcase; the greeting on one line (fix round 2). |
| H03-HomeLoading | H03-HomeLoading.png | match | Card loading state and the mountain skeleton; the inner skeleton is faint. |
| H04-HomePremium | H04-HomePremium-520.png, H04-HomePremium.png | match | Practice card with sessions n/5, unlocked tiles. |
| V12-Climb | V12-Climb.png | match | End frame: step chip, bubble, Continue; fix round 2: the summit flag on the peak. |
| V12b-ClimbStoryboard | V12b-ClimbStoryboard-1-wide.png, V12b-ClimbStoryboard-2-close.png, V12b-ClimbStoryboard-3-wide.png | match | Three key frames: wide, close (2.2×), wide. |
| V24-DayComplete | V24-DayComplete.png | match | Premium users' rest scene since SPEC v10: camp, campfire, sleeping companion with a rising Zzz, countdown; no reminder switch (OUT). |
| V24f-RestFree | V24f-RestFree.png, V24f-RestFree-t2.png | match | New (fix round 2): dream bubble with today's weak spot, "All done" header with two ticks and the countdown, Premium card (1 used + 4 locked tickets, the weak spot in gold, "Wake Fox up · 7 days free" from the store's trial); no reminder row (other branch). |
| V24s-RestToPremium | V24s-RestToPremium-1-rest.png, V24s-RestToPremium-2-awake.png, V24s-RestToPremium-3-paywall.png | match | New (fix round 2): the storyboard's frames: rest, the companion awake (wave, fire grown, card glowing), V13r risen over the scene. |
| R04-MonthCard | R04-MonthCard.png | match | Recap with medal swap, dots, stats, stepwise bar, lines glow (fix round 1); fix round 2: the summit flag on the peak. |
| R04b-NewMountain | R04b-NewMountain.png | match | Whole new mountain, the flag on the summit (fix round 2), companion at the start, thresholds. |
| V16-Review | V16-Review.png | match | Ticket, weak spot card with the mistake inline, Practice with my ticket; no mastery strip (D6-1). |
| V16b-TicketTear | V16b-TicketTear-2-practice-starts.png, V16b-TicketTear.png | match | Mid-tear: navy body, stub gone, USED stamp; then the AI permission. |
| V22-ReviewUsed | V22-ReviewUsed.png | match | Used ticket with the 20:41 slot, Premium card; no "practiced today" chip or mastery (D6-1, D6-2). |
| RV05-ReviewEmpty | RV05-ReviewEmpty.png | match | Waiting ticket, cheering companion, navy button. |
| RV06-ReviewSort | RV06-ReviewSort.png | match | Sheet with two options, the selected one navy. |
| R03-WeakSpot | R03-WeakSpot.png | match | Rule bubble, the mistake inline, today's ticket; no mastery strip (D6-1). |
| R12-ReviewPremium | R12-ReviewPremium.png | match | Premium chip, Suggested focus with its glint (fix round 1), cards; mastery strips deferred (D6-1). |
| R01-Topics | R01-Topics.png | match | Picked for you, coloured topic cards; no mastery strips (D7-1). |
| R02-Length | R02-Length.png | match | Orange knob and Start; the board's ring, the number rolls (fix round 1). |
| V17-Consent | V17-Consent.png | match | Same text in icon cards, navy Agree, Not now. |
| V18-Preparing | V18-Preparing.png | match | Thinking companion, skeletons, Did you know? card; skeleton bars faint. |
| V19-PracticeQuestion | V19-PracticeQuestion.png | match | Line: AI reviews all your answers when you finish. |
| V20-Reviewing | V20-Reviewing.png | match | Inspecting companion, lens over the answers, checklist, bar. |
| V21-PracticeResults | V21-PracticeResults.png | match | N/M correct, feedback cards, Premium card; no mastery step (D7-1). |
| P08-DailyLimit | P08-DailyLimit.png | match | Sleeping companion, full counter; the existing accurate sentence (D7-2). |
| V13-Paywall | V13-Paywall.png, V13-Paywall-t2.png | match | Fix round 2: the board's trio (70 / 110 / 64) floats and hops (two moments), the CTA shines and pulses, See plans floats. |
| V13a-PaywallPlans | V13a-PaywallPlans.png | match | Plans after See plans, yearly preselected; they rise in 60 ms apart (fix round 1). |
| V13c-PaywallCompare | V13c-PaywallCompare.png | match | Fix round 2: the board's table (heading with the hopping companion, one-piece Premium column, six rows, grey-outline free checks, green note), trial timeline, plan label above the CTA. |
| V13b-ExitReminder | V13b-ExitReminder.png | match | Sad companion, no discount, trial / Continue with free. |
| V13r-PaywallRest | V13r-PaywallRest.png | match | New (fix round 2): evening camp strip with the awake companion and fire, "Fox is wide awake, Ada.", PRACTISE IT NOW with the weak spot, benefits in V13r's order, V13's pinned CTA, price line and links. |
| PW05-PremiumOn | PW05-PremiumOn.png | match | Rays, cheering companion, three unlocked things, trial end date. |
| PW05r-PremiumOnRest | PW05r-PremiumOnRest.png | match | New (fix round 2): "Fox is ready. Let's go!", the three perks with "4 more sessions today, 5 every day", the trial's end, "Practise The With Superlatives". |
| V23-Profile | V23-Profile.png, V23-Profile-t2.png, V23-Profile-420.png | match | Fix round 2: the board's navy ribbon (286 × 62, V-cut tails, 40 pt overlap, pencil); the companion breathes and floats (two moments); shelf and "since" (fix round 1). |
| PF02-Medals | PF02-Medals.png | match | Fix round 2: tier counters, "All medals / Newest first", year header, 3-column grid, the running month "in progress" first, the Welcome badge at its month. |
| PF03-MedalDetail | PF03-MedalDetail.png | match | The existing medal detail from the layer (D9-3); the medal flies in, steps and points count up (fix round 1). |
| PF04-EditName | PF04-EditName.png | match | Fix round 2: the board's sheet (waving companion's question, navy-framed field with n/40 inside, Cancel / Save) sized to its content. |
| R07-Language | R07-Language.png | match | Language cards, the selected one navy with a check. |
| R08-Data | R08-Data.png | match | Three cards; the reset asks with the companion dialog. |
| R09-Credits | R09-Credits.png | match | Three companions on top (sides float, Fox sways), one card, two links. |
| SY03-DarkHome | SY03-DarkHome-dark.png | match | Dark Home from the theme tokens (captured with :dark). |

