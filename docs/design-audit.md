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

**S4 — The bottom nav bar overlaps scrollable content.** On Settings it covers
the profile save button and the "Data" heading. Scroll views have no bottom
padding for the nav's height. This is a usability defect, not a preference.

**S5 — Two back-button treatments.** A plain chevron on Topic Practice /
Premium / weak-spot detail; a chevron inside a filled circle on Results.

**S6 — Vertical rhythm varies per screen.** Title-to-content and
card-to-card spacing differ across screens; there is no spacing scale.

---

## 2. Screen-specific findings

**Welcome.** Logo, title and subtitle sit mid-screen with ~40% empty above and
a large gap below a bottom-pinned CTA. Separately: the sparkle brand mark is
reused as Topic Practice's feature icon on the paywall — a brand mark should
not double as a feature icon.

**Onboarding.** The disabled "Continue" button is dark orange on orange and is
close to invisible — the worst contrast failure in the app, and it is the state
a first-time user sees before typing anything. Large dead gap between the
privacy line and the button.

**Daily Test — question.** Two defects:
- *"Skip" is the large filled primary button.* The most visually dominant
  control on the screen invites abandoning the question. Observed in the audit
  screenshots themselves: two consecutive runs finished 0/5 correct, 5 skipped.
  Primary should be Submit/Next (disabled until input); Skip should be a quiet
  text action.
- The question card ends around 40% of screen height, followed by an orange
  void, with the answer field and button pinned at the bottom. The header also
  stacks three progress signals: "1/5", the screen title, and a progress bar.

**Daily Test — results.** Skipped questions show the right answer in a green
"CORRECTED" box. Green carries success semantics on a question that was never
attempted; skipped should read as neutral and the label should not say
"corrected". Also, an opaque orange app bar with a hard edge appears on scroll
but is absent at scroll-top.

**Paywall.**
- The app bar reads "Topic Practice" on what is the paywall.
- Privacy Policy / Terms of Service render dark-orange on orange and are
  effectively unreadable — and are dead links (`AppLinks` is empty).
- "Maybe later" has the same contrast problem and no container.
- The screen carries no price, plan or terms, because no product is connected.

**Home.** The Premium entry is a solid full-width blue bar while the other two
entries are light cards; it reads as a button and outranks Daily Test, which is
the free core loop. Its internal layout differs too (icon vertically centered,
title starting at a different x). Large empty area below the three items — the
2x2 grid became a 3-item list when Streak/Voice were removed and nothing filled
it. The avatar tile shows a generic person glyph although eight avatars exist.
In the locked state, the lock glyph is small; the real signal is carried by the
copy alone.

**Topic list.** The most internally consistent screen. Minor: on three-line
cards the vertically centered icon reads as misaligned.

**Session-length dialog.** The scrim turns the orange background muddy brown;
a plain black scrim over a saturated ground reads as dirt.

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

**D2 — One blue.** Deep navy only, consistent with PRD v2's stated
"orange primary / deep blue accent". The violet-blue is removed everywhere.

**D3 — Skip stops being the primary action** on Daily Test questions.

**D4 — The polish pass is split in two.** Structure first (B-structure:
premium screen merge, 7-day trial model, Home rework, S4, the Review duplicate
bug, Skip demotion), then finish (B-polish: hybrid theme applied across
screens, single blue, spacing scale, contrast). Reason: polishing screens whose
structure is about to change is wasted work.

Monetization and Home decisions that came out of this audit are recorded in
`docs/prd-v2.md` §13, not here.
