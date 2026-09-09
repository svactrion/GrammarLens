# Design Audit — v2.1, light mode (2026-09-05)

**What this is:** a screen-by-screen review of the app as it actually looked on
device on 2026-09-05, done before the visual polish pass rather than during it.
21 screenshots, light mode only (dark mode deliberately skipped — see "Gaps"
below). Findings are separated into system-level causes, screen-specific
defects, and taste, because only the first two justify code changes.

Written because the polish pass was scoped as "the app looks unfinished" —
too vague to act on. This turns that into a list with reasons.

---

## 1. System-level findings

These repeat on every screen, so they are decided once rather than per screen.

**S1 — Orange is the page background, not an accent.** Every screen is filled
with the brand orange. Three consequences: all content must sit on a card to be
legible; large orange voids open wherever content is short (Welcome, Home,
Review-with-one-item, loading); any secondary text placed directly on orange
loses contrast. This is the root cause of roughly half the individual defects
below.

**S2 — Two blues in the system.** Deep navy on primary buttons, but a
saturated violet-blue on the Settings theme selector, the Review frequency
pill, and the Premium screen's icon circles. Nothing distinguishes their
meanings.

**S3 — The same component carries two color languages.** Icon circles are
orange on Home and the topic list, blue on the Premium screen.

**Status (2026-09-10): closed, no code change needed.** Premium's two blue
icon circles were already gone by the time this was checked — they went away
as a side effect of the benefit-list-to-comparison-table change (D3-adjacent
polish work), confirmed by grepping for `primaryContainer`/`onPrimaryContainer`
usage across every icon-circle call site: all of them, everywhere in the app,
now read from that one pair. Nothing left carrying the old blue.

**S4 — The bottom nav bar overlaps scrollable content.** On Settings it covers
the profile save button and the "Data" heading. Scroll views have no bottom
padding for the nav's height. This is a usability defect, not a preference.

**S5 — Two back-button treatments.** A plain chevron on Topic Practice /
Premium / weak-spot detail; a chevron inside a filled circle on Results.

**Status (2026-09-10): closed.** The specific pairing above is stale — D1's
migration onto `BrandScaffold` already put Results on the same plain chevron
as everything else, leaving the real split as a *bordered* circle
(`HeaderCircleIconButton`) on the two question screens (Practice/Daily Test)
versus the plain chevron everywhere else. Two directions (spread the circle
everywhere vs. drop it everywhere) were mocked up on-device, both themes, on
a question screen and a normal screen, and reviewed before picking: plain
chevron everywhere, chosen over the circle because it matches the platform's
own back-gesture convention and reads fine on the orange band too. The
question screens' circle button is gone (`HeaderCircleIconButton` renamed to
`HeaderIconButton`, no border); every screen in the app now uses one
treatment.

**S6 — Vertical rhythm varies per screen.** Title-to-content and
card-to-card spacing differ across screens; there is no spacing scale.

---

## 2. Screen-specific findings

**Welcome.** Logo, title and subtitle sit mid-screen with ~40% empty above and
a large gap below a bottom-pinned CTA. Separately: the sparkle brand mark is
reused as Topic Practice's feature icon on the paywall — a brand mark should
not double as a feature icon.

**Status (2026-09-08): the brand-mark half is closed.** `Icons.auto_awesome_rounded`
is gone from the app entirely (confirmed by search — no remaining use anywhere
in `lib/`) — replaced by a hand-drawn `BrandMark` (a loupe/magnifying glass,
`lib/widgets/brand_mark.dart`), animated into Welcome's entrance. The ~40%
empty-space layout itself is unchanged (that commit's own message is explicit:
"text, layout, and the CTA itself are otherwise unchanged") — the space is now
filled with ambient motion (breathing mark, sonar rings, drifting glows,
twinkle dots) rather than restructured, so this half stays open.

**Onboarding.** The disabled "Continue" button is dark orange on orange and is
close to invisible — the worst contrast failure in the app, and it is the state
a first-time user sees before typing anything. Large dead gap between the
privacy line and the button.

**Status (2026-09-10): closed, no further code change.** D1 already fixed the
actual defect described here — label and background sharing one orange hue,
reading as blank — by moving this button onto `BrandScaffold`'s neutral body.
Checked again on-device in both themes for this closure: ~2.24:1 (light) /
~2.78:1 (dark), pixel-measured. Both are under WCAG AA's 4.5:1 body-text
threshold, but WCAG 1.4.3 exempts disabled controls from that requirement and
this is Material 3's own disabled-button convention, not a residual bug. The
label reads; nothing here is left "open" — whether a disabled control should
be held to the stricter standard anyway is a taste question, not a defect,
and isn't being pursued further.

**Daily Test — question.** Two defects:
- *"Skip" is the large filled primary button.* The most visually dominant
  control on the screen invites abandoning the question. Observed in the audit
  screenshots themselves: two consecutive runs finished 0/5 correct, 5 skipped.
  Primary should be Submit/Next (disabled until input); Skip should be a quiet
  text action.
- The question card ends around 40% of screen height, followed by an orange
  void, with the answer field and button pinned at the bottom. The header also
  stacks three progress signals: "1/5", the screen title, and a progress bar.

**Status (2026-09-10): the header-stacking half is closed.** The progress bar
was telling the same story as the "N / total" counter next to it — removed,
counter stays, since an exact count is more informative than an approximate
fill for the small fixed session lengths this app uses (3/5/10). This is also
what shortens the header. Skip-as-primary-button was already closed earlier
by D3. The 40%-card/orange-void layout itself is untouched — out of scope for
this round.

**Daily Test — results.** Skipped questions show the right answer in a green
"CORRECTED" box. Green carries success semantics on a question that was never
attempted; skipped should read as neutral and the label should not say
"corrected". Also, an opaque orange app bar with a hard edge appears on scroll
but is absent at scroll-top.

**Status (2026-09-10): the "CORRECTED" half is closed.** `MistakeBreakdown`
(shared by this screen and Topic Practice's own results screen) now derives
skippedness from the answer already being empty — the same fact its own
`hasAnswer` check computes — rather than trusting each caller to pass a
separate flag; a skipped item's correction box uses the neutral "YOU WROTE"
treatment and reads "CORRECT ANSWER", not "CORRECTED". Regression-tested
directly (`test/mistake_breakdown_test.dart`). The scroll-edge app-bar
finding is unrelated and untouched — see D1's own `scrolledUnderElevation: 0`
decision, already in effect app-wide.

**Paywall.**
- The app bar reads "Topic Practice" on what is the paywall.
- Privacy Policy / Terms of Service render dark-orange on orange and are
  effectively unreadable — and are dead links (`AppLinks` is empty).
- "Maybe later" has the same contrast problem and no container.
- The screen carries no price, plan or terms, because no product is connected.

**Status: superseded, effectively closed.** The standalone Paywall screen
this finding describes no longer exists — it was merged into `PremiumScreen`
on 2026-09-05 (fixing the "Topic Practice" app-bar title bug as a side
effect). `AppLinks` now holds real, permanent URLs (2026-09-07) and every
`TextButton` — including Privacy Policy/Terms and "Maybe later" — reads from
the centralized `textButtonTheme` fix below, closing the contrast complaint.
This round (2026-09-08) went further: the merged screen was reordered so the
price/plan area is reachable without scrolling, and gained explicit
loading/loaded/unavailable states for the no-product-connected case instead
of silently showing nothing — see `docs/build-log.md`, 2026-09-08.

**Home.** The Premium entry is a solid full-width blue bar while the other two
entries are light cards; it reads as a button and outranks Daily Test, which is
the free core loop. Its internal layout differs too (icon vertically centered,
title starting at a different x). Large empty area below the three items — the
2x2 grid became a 3-item list when Streak/Voice were removed and nothing filled
it. The avatar tile shows a generic person glyph although eight avatars exist.
In the locked state, the lock glyph is small; the real signal is carried by the
copy alone.

**Status (2026-09-10): the locked-state half is closed.** The 16px lock glyph
next to the title is gone; a `LockedPremiumPill` (lock icon + "Premium",
neutral color, its own trailing chevron) now sits in the trailing slot both
the Topic Practice card and a locked weak-spot row already had a plain
chevron in — same fix, same slot, both card types. Checked what tapping a
locked card does today before making this change: the whole card was already
one tap target opening `PremiumScreen`, so the new pill keeps a forward-going
chevron built into it rather than silently dropping that signal. The rest of
this paragraph (Premium's old full-width bar, the 3-item list, the generic
avatar glyph before one is picked) describes a Home layout that no longer
exists — superseded by the "today" screen rebuild, `docs/roadmap.md`'s
v2.2 B-structure entry.

**Topic list.** The most internally consistent screen. Minor: on three-line
cards the vertically centered icon reads as misaligned.

**Status (2026-09-10): closed.** The card's `Row` top-aligns the icon against
the title now instead of centering it against the full three-line block
(title/description/stats); the trailing chevron is re-centered within its
own icon-height band so it doesn't inherit the same low-against-three-lines
problem.

**Session-length dialog.** The scrim turns the orange background muddy brown;
a plain black scrim over a saturated ground reads as dirt.

**Status (2026-09-08): closed.** The `AlertDialog` was replaced with a modal
bottom sheet (`practice_length_picker.dart`) whose scrim is tinted off
`colorScheme.onSurface` at 42% instead of plain black.

**Results (Topic Practice).** Color coding works (green correct / red needs
work / neutral skipped). Only exit is "Back to topics" — no path to practice
the same topic again or to view weak spots.

**Review — populated.** Defect: the topic label is printed twice
("Gerund vs. Infinitive · Gerund vs. Infinitive"). The card also uses the
explanation text as its title and truncates it mid-sentence.

**Weak-spot detail.** The same explanation paragraph appears twice on one
screen — in the summary card and again at the end of the mistake card. The
topic name is restated three times (title, pill subtitle, card caption).

**Settings.** Nav bar covers the save button (S4). The avatar grid's eight
tiles use background colors belonging to no palette. The theme selector uses
the violet-blue of S2. The Developer section (debug-only entitlement override
and first-launch reset) is correct and clearly labeled.

**Status (2026-09-10): the avatar-palette half is closed; a further
consistency defect found and fixed alongside it.** S4 and the theme selector
were already closed separately (D1, D2). The avatar palette is now a named,
documented exception (see below) rather than unnamed hex — see item 2's own
note for why "no palette" is correct by design here, not a gap. Also fixed:
Profile and Data were wrapped in `Card`, reading identically to Home's
tappable cards while being a container for several independent controls, not
a single tap target — dropped, matching Appearance's already-cardless layout.
This was flagged but deliberately left open in `docs/build-log.md`'s D1
Batch 4 entry ("a third, not-yet-named justification... revisit once every
screen has migrated"); revisited now.

**Named exception: the avatar background palette
(`lib/theme.dart`'s `avatarFoxBackground` etc.).** Eight fixed,
theme-independent colors — like a chat app's per-user color, these are
decorative identity colors, not semantic UI colors, so they deliberately
don't come from `ColorScheme` and don't change with light/dark mode. They
also can't be derived from a semantic role: a green avatar would read as
"correct," a red one as "a mistake," the moment it sat next to this app's
actual correct/incorrect colors. Redesigned this round from a set with two
identical-hue pairs (fox/lion both orange, panda/koala both blue-grey — only
6 of 8 actually distinguishable by color alone) to eight hues spaced evenly
around the wheel at one fixed saturation/lightness, chosen to also sit clear
of this app's meaningful hues (`SemanticColors`' correct-green and
error/incorrect-red). Verified on-device in both themes, at actual tile
size, in the picker grid, including glyph contrast on the tile.

**Loading.** A single glyph on full orange with "Reviewing your answers…" and
no progress signal, on a wait that can run long — the same treatment covers
Daily Test generation.

---

## 3. Explicitly not defects

Recorded so they are not "fixed" later by accident: Welcome's empty space
(readable as calm), the icon drawing style (coherent, a choice), and the
saturation of the Results cards. No changes proposed.

---

## 4. Gaps in this audit

- Dark mode was not captured. Contrast fixes behave differently per theme, and
  this project has already shipped one light-mode-only regression (the
  onboarding option cards). Every batch must be verified on-device in dark.
- The practice question screen with the keyboard open was not captured; the
  keyboard-aware layout has a history of issues there.
- The Daily Test error state was not captured (hard to trigger on demand).

---

## 5. Decisions taken from this audit (2026-09-05)

**D1 — Hybrid theme.** Orange stays as identity but stops being the page
background. The rule: full orange on Welcome only; every other screen gets an
orange header band (carrying the title and, on results screens, the score) over
a neutral off-white body; orange remains an accent for icon circles, selected
states and progress. Side effect: most cards become unnecessary, since cards
exist mainly to make content legible on orange.

Considered and rejected: keeping orange everywhere (keeps identity but leaves
us patching contrast and voids screen by screen), and going fully neutral
(fixes everything but makes the app generic).

**Status (2026-09-09): closed.** Rolled out across four batches
(`docs/build-log.md`, 2026-09-09) via a shared `BrandScaffold` widget
(`lib/widgets/brand_scaffold.dart`): Home; Topic list, Review, Weak-spot
detail, Settings; Daily Test question, Topic Practice question, Onboarding,
Loading; Daily Test Results, Topic Practice Results, Premium. Welcome is the
one deliberate exception, staying full orange. Dark mode's band is neutral,
not deep orange — decided in Batch 1 (orange never becomes a surface color
in dark mode; only light mode keeps the orange band) and confirmed
on-device in every batch since.

The scoped `cardTheme` override this rollout needed mid-migration (so a
`BrandScaffold` card and a not-yet-migrated screen's card could legitimately
differ while both existed at once) was retired once Batch 4 left every
screen on `BrandScaffold`: `lib/theme.dart`'s app-wide `cardTheme` now owns
the card color/elevation/border directly, and every card-bearing screen
from all four batches was re-verified on-device in both themes against that
shared default. This closes the pattern this file's own S3 names ("the same
component carries two color languages") as it would otherwise have applied
permanently to cards, not just icon circles.

One item D1's work surfaced stays open, tracked separately rather than
folded into this closure: Onboarding's disabled "Continue" button.
Migrating it onto `BrandScaffold`'s neutral body fixed the actual defect
this audit described — a button that read as blank because its label and
background shared the same orange hue — measured at ~2.24:1 (light) /
~2.78:1 (dark), up from effectively invisible. Both numbers are still under
WCAG AA's 4.5:1 body-text threshold; WCAG 1.4.3 exempts disabled controls
from that requirement, and this matches Material 3's own disabled-button
convention, so it isn't a residual instance of the bug D1 fixed — but
whether that label should be more readable regardless is a distinct,
still-open question that this fix wasn't scoped to answer. See
`docs/roadmap.md`'s D1 entry.

**Status (2026-09-10): closed — no further action.** Re-checked on-device in
both themes as part of this round's contrast/states pass; the numbers above
are unchanged and are being accepted as-is (WCAG 1.4.3's disabled-control
exemption plus Material 3's own convention), not chased toward AA's normal-
text threshold. See the Onboarding entry in §2 above.

**D2 — One blue.** Deep navy only, consistent with PRD v2's stated
"orange primary / deep blue accent". The violet-blue is removed everywhere.

**Status (2026-09-08): closed.** `secondaryContainer`/`onSecondaryContainer`
(the violet-blue #3D5AFE pair) replaced with `#D7E1FA` on `#0A2E70` in the
light scheme (`lib/theme.dart`) — a light tint of the same navy `secondary`
already in use, not a new hue, ~9.8:1 contrast. Reasoning (from the
implementing commit): this makes `secondaryContainer` "part of the same navy
family" instead of a second, unrelated blue system, closing S2's actual
complaint. The dark scheme's existing `secondaryContainer` pair (~7.1:1) was
already fine and is untouched. `tertiaryContainer` continues aliasing
`secondaryContainer` in both themes, so nothing keyed off it needed a
separate change.

**D3 — Skip stops being the primary action** on Daily Test questions.

**D4 — The polish pass is split in two.** Structure first (B-structure:
premium screen merge, 7-day trial model, Home rework, S4, the Review duplicate
bug, Skip demotion), then finish (B-polish: hybrid theme applied across
screens, single blue, spacing scale, contrast). Reason: polishing screens whose
structure is about to change is wasted work.

Monetization and Home decisions that came out of this audit are recorded in
`docs/prd-v2.md` §13, not here.

**D5 — Batch 0 (2026-09-10): the remaining contrast/states and consistency
findings, closed in one round.** Nine items, decided together before any
code was written, four with a correction applied before implementing (see
each item's own status note above and in `docs/roadmap.md`'s B-polish list):
the skipped-answer "CORRECTED" box, the avatar palette's real hue
separation, the locked-card pill, Onboarding's disabled button (no code —
closing the "still open" tracking), single back-button treatment (S5,
direction chosen after an on-device two-way comparison), icon circles (S3,
no code — already closed by other work), Daily Test's redundant progress
bar, Settings' Profile/Data losing their `Card` wrap, and the topic list's
icon alignment. `docs/build-log.md` has the implementation detail and
verification for each.
