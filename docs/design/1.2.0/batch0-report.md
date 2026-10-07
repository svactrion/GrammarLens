# 1.2.0 redesign — Batch 0 report

**Status: read and measured; nothing is built.** Branch `1.2.0` (from
`fec9b75`). No `lib/`, `test/`, asset or `pubspec` change. Written
2026-10-05.

Inputs read: `CLAUDE-CODE-BRIEF.md` (binding), `design-tokens.json`,
`index.html` and `source/grammarlens-five-screens.html` (visual reference),
`lib/theme.dart`, `lib/widgets/brand_scaffold.dart`,
`lib/widgets/floating_nav_shell.dart`, and the Home, Review, Profile
(`settings_screen.dart`), Daily Test, Practice, Topic Practice and practice
length picker screens with the widgets they use.

Scope: Home, Review, Profile, the question screen (Practice and Daily Test
share it) and Topic Practice. The brief marks Topic Practice as a draft;
the owner approved it on 2026-10-05, so it has the same status as the other
four.

Invariant for every later batch: visual only. State, routing, premium
checks, quota, AI/proxy calls, the storage schema, analytics events and
gamification math stay as they are.

How things were measured:

- **Contrast:** WCAG 2.x relative luminance, computed in Python from the
  hex values (the same formula as `theme_test.dart`'s `_contrast`). The
  script is in [Appendix A](#appendix-a-contrast-script).
- **Font:** the `fvar` table of `assets/fonts/NunitoSans-Variable.ttf` was
  parsed directly, and Flutter 3.44.6 rendered the font in a test (outside
  the repo, nothing committed) at each weight. See §4 and
  [Appendix B](#appendix-b-font-probe).
- **Tests:** each `test(` / `testWidgets(` block in `test/` was scanned
  with regexes (the script is in [Appendix C](#appendix-c-test-scan)). The
  counts are a heuristic. The per-test lists in §8 were checked by reading
  the tests.
- Things I could not measure are marked **not measured**. Line numbers
  refer to `fec9b75`.

---

## Summary

1. **The dark primary button has no visible edge.** `primaryButton`
   `#0D3B8F` measures **1.48:1** on the dark `cardSurface` `#252528`,
   **1.77:1** on the dark `pageBackground` `#151517` and **1.28:1** on the
   dark `subtleSurface`. The white label is 10.30:1, so the text is fine;
   only the fill's edge disappears. Light mode is 8.97–9.98:1. §3.
2. **Card borders, the input border and the nav bar edge are all under
   3:1 in both themes.** The card `border` is 1.41:1 (light, on the card)
   and 1.61:1 (dark). In 1.0 the D1 decision rejected `outlineVariant` at
   1.34:1 after a device check found it "genuinely hard to see". The input
   border is 1.63:1 (light) and 2.59:1 (dark). A text field's edge is
   covered by WCAG 1.4.11. §3.
3. **The font is fine.** The variable font's `wght` axis runs 200–1000,
   and Flutter maps `FontWeight.w400…w900` onto it. Each weight gives a
   different advance width (574.4 → 619.6 pt for the same string), which
   faux bold does not do. Each weight also renders pixel-identically to an
   explicit `FontVariation('wght', n)`. One catch: the file's default
   instance is **ExtraLight (200)**. §4.
4. **`colorScheme.secondary` has to split in dark mode.** Today one role
   covers both buttons and links/active states. The brief keeps the button
   `#0D3B8F` in dark but makes links/active `#B4C8FF`. Proposal: put
   `linkAndActive` on `secondary` and add a `ThemeExtension` for the
   button. In light mode nothing changes, because both are `#0D3B8F`
   today. §1.
5. **Welcome silently loses its orange.** It is the D1 exception that
   stays full orange, but it gets that colour by inheriting
   `scaffoldBackgroundColor` (`welcome_screen.dart:127`, no
   `backgroundColor`). Once the band is gone, Welcome becomes the page
   colour unless it is pinned explicitly. §7.
6. **Several brief items need data, copy or behaviour that does not exist
   yet** (§6). Examples: the Review allowance card (the data exists but
   Review does not read it), the Profile next-medal line (the data exists
   in `MonthlyMedalRules.nextTier`, the copy does not), and the question
   card's heading and two-step instructions (no field in the data). Three
   items conflict with existing decisions: newest-first medal order
   (N34), Home topic cards that start a topic directly (a routing change),
   and the frosted-glass nav bar.
7. **Tests:** 1,126 test cases in 118 files. 111 contain a look-related
   assertion (colour, size, geometry, style or styled-widget type); 1,015
   contain none. **About 30 tests will need updating** for the five
   screens. Another 8 tests and 2 shared helpers find "Skip" as an
   `OutlinedButton` and need only that finder changed. §8.

---

## 1. Token mapping

"Current" means what the app paints today for that use, read from code.
Proposed roles keep the existing role names wherever the current usage
already matches, to keep the blast radius small.

### 1.1 Colours

| Brief token | Light: current → new | Dark: current → new | Current role / where it comes from | Proposed role |
|---|---|---|---|---|
| pageBackground | `#FAF3EC` → `#F3EFE6`; light band `#FF7A1A` goes away | `#1C1B1F` → `#151517`; band `#121212` goes away | `surfaceContainerLow` (`BrandScaffold` body, `brand_scaffold.dart:180`); `scaffoldBackgroundColor` and app bar = `bandBackground` (`theme.dart:476-486`) | `surfaceContainerLow` **and** `scaffoldBackgroundColor`, app bar background |
| cardSurface | `#EDE4D8` → `#FFFBF4` | `#2B2A2F` → `#252528` | `surfaceContainerHigh` (`cardTheme.color`, `theme.dart:514`; climb plaque) | `surfaceContainerHigh` |
| subtleSurface | `#E7DCCD` → `#F6F0E5` | `#36353A` → `#303034` | closest is `surfaceContainerHighest` (input fill, locked icon fill, 14 uses) | `surfaceContainerHighest` |
| textPrimary | `#1B1B1F` (same) | `#E4E2E6` → `#F0ECE7` | `onSurface` | `onSurface` |
| textSecondary | `#46464F` (same) | `#C9C5D0` (same) | `onSurfaceVariant` | `onSurfaceVariant` (no change) |
| brandOrange | `#FF7A1A` (same) | `#FF8A3D` (same) | `primary` | `primary` (no change) |
| onOrange | `#241200` (same) | `#3D1300` → `#241200` | `onPrimary` | `onPrimary` |
| primaryButton | `#0D3B8F` (same, via `secondary`) | `#5C7CFA` → `#0D3B8F` | `secondary` (`filledButtonTheme`, `theme.dart:544`; `PracticeStepFooter:60`) | **New `ThemeExtension`** (`button`), read by `filledButtonTheme` |
| onPrimaryButton | `#FFFFFF` (same) | `#04123A` → `#FFFFFF` | `onSecondary` | **Same extension** (`onButton`) |
| linkAndActive | `#0D3B8F` (same) | `#5C7CFA` → `#B4C8FF` | `secondary` (text buttons, nav active, section labels, focus border) | `secondary` |
| (new, implied) on linkAndActive as a fill | `#FFFFFF` | `#04123A` → `#0A2E70` (7.72:1 on `#B4C8FF`) | `onSecondary` (slider chevron, dial) | `onSecondary` |
| infoSurface | `#D7E1FA` (same) | `#1A3FA0` → `#243859` | `secondaryContainer` | `secondaryContainer` |
| onInfo | `#0A2E70` (same) | `#D8E1FF` (same) | `onSecondaryContainer` | `onSecondaryContainer` (no change) |
| border | `#DED3C2` → `#DED5C6` | `#444349` → `#45454D` | `outlineVariant`. **The card border today is `outline`** (`#8A8A93` / `#8D8A93`, `theme.dart:533`) | `outlineVariant`; `cardTheme` switches to it (see §2.4) |
| navigationSurface | `#FAF3EC` at 68 % over blur → `#FFFCF7` solid | `#1C1B1F` at 55 % → `#2D2D32` solid | `surfaceContainerLow.withValues(alpha:)` (`floating_nav_shell.dart:159`) | **`ThemeExtension`** (no M3 role) |
| navigationBorder | `#DED3C2` at 50 % → `#D2C6B4` | `#444349` at 50 % → `#595961` | `outlineVariant.withValues(alpha: .5)` (`:164`) | **`ThemeExtension`** |

Colours the mockup uses but the brief's table does not list. A decision is
needed for each (§10):

| Mockup value | Light | Dark | Where |
|---|---|---|---|
| "ink" (titles, unselected nav labels) | `#241200` | `#F0ECE7` (= textPrimary) | Home brand, page titles, nav |
| Input border | `#D2C6B4` (= navBorder) | `#66636B` | question textarea, Profile name input |
| Path/plaque outline | `#A59F98` | `#777581` | Mountain plaque and frame, 1.5 px |
| Disabled button fill / label | `#E4DDD2` / `#6D6860` | `#36363B` / `#ACA8B2` | question Next |
| Medal tier dots | `#BA7B4F` / `#8E9BAA` / `#C99526` | same | Profile thresholds. Today: `medal_tier_color.dart:9-11` `#B56A3B` / `#8A95A3` / `#D39B21`; keep the app's |
| Overlay scrim | `#10121B80` | same | sheets and dialogs |

Unchanged and out of the brief: `error*`, `DestructiveColors`
(`#DC3232`), `SemanticColors` (results), the climb palettes in
`models/climb_theme.dart`, and `brandMarkGlass` / `brandMarkGlint`.

**Proposed extension.** One `ThemeExtension` (working name
`AppPalette`), next to `SemanticColors` in `theme.dart`: `button`,
`onButton`, `navSurface`, `navBorder`, `inputBorder`, `pathOutline`,
`disabledFill`, `disabledLabel`, `cardShadow` (`List<BoxShadow>`) and
`navShadow` (`List<BoxShadow>`). Shadows go here because `Card.elevation`
cannot express the brief's colour, blur and offset.

Why `primary` is not remapped to the navy button (the textbook M3 move):
`primary` is the brand orange in 11 places outside the theme. These are
the medal shelf, the climb score bar, the celebration, and
`appLightPrimary` / `appDarkPrimary`, which feed the climb palettes. The
orange values do not change, so leaving `primary` alone means none of
those files change.

### 1.2 Sizes and spacing

| Brief | Current (code) | New |
|---|---|---|
| Horizontal page padding 18; 14 on narrow screens | `ContentWidth.basePadding = (w × 0.045).clamp(16, 28)` (`content_width.dart:28`): 16.0 at 320, 17.55 at 390, 19.35 at 430 | 14 at < 360 pt (proposed cut-off), else 18; the iPad column (P1) unchanged |
| Card inner padding 17–20 | 18 (Home cards), 16 (weak spot), 16 × 18 (topic) | 18 (cards), 17 (list cards), 17 × 15 (topic) |
| Section gap 23–24 | 24 (Home), 32 (Profile) | 24 |
| List card gap 12 | 10 (Home weak spots), 14 (Review, Topic) | 12 |
| Icon/text gap 10–12 | 16 | 12 |
| Large card radius 22–24 | `appCardRadius = 20` (`theme.dart:137`) | 24 (card), 22 (list card) |
| Input radius 18 | 16 (`theme.dart:581-589`) | 18 |
| Primary button radius 14–15 | 16 (`theme.dart:548,558`) | 14 |
| Navbar radius 29 | 32 (`floating_nav_shell.dart:150,161`) | 29 |
| Card border 1 | 1 (`outline`) | 1 (`border`) |
| Path title / frame line 1.5 | 1 (`climb_card.dart:157,225`) | 1.5 |
| Button height ≥ 48 | 52 (`minimumSize`, `theme.dart:546`; `PracticeStepFooter._height`) | 48 minimum (the mockup's question footer uses 50) |
| Icon button ≥ 44 × 44 | 40 × 40 (`HeaderIconButton.size`, `question_app_bar.dart`) | 44 |
| Light card shadow (0,5) blur 18 `#483018` ~.10 | `elevation: 1`, black (`theme.dart:524`) | `cardShadow` |
| Dark card shadow (0,5) blur 18 black ~.17 | `elevation: 1` | `cardShadow` |
| Light nav shadow (0,6) blur 22 `#483018` ~.15 | (0,8) blur 20 `shadow` at .18 | `navShadow` |
| Dark nav shadow (0,6) blur 22 black ~.33 | same as light | `navShadow` |

### 1.3 Typography

The app's text sizes come from `buildAppTheme`: a Material scale × the
`AppTextSize` factor. **Small = 1.0, Medium = 1.1 (the default), Large =
1.2** (`models/app_text_size.dart`), multiplied again by the system text
scale. The mockup's scale is .92 / 1 / 1.16 with Medium = 1. See Q5 for
which of these the brief's sizes refer to.

| Use (brief) | Size / weight / line height / letter spacing | Current (style, base size, weight) | Proposed carrier |
|---|---|---|---|
| Home brand | 34 / 900 / 1.10 / −1.4 | `headlineLarge` 32, w800, no height or spacing (`home_screen.dart:1072`) | `displaySmall` (36 → 34) |
| Review/Profile page title | 34 / 900 / 1.10 / −1.1 | `PageTitle`: `headlineMedium` 28, w700, 1 line, ellipsis (`utils/page_title.dart`) | `displaySmall`, via `PageTitle` |
| Topic page title | 32 / 900 / 1.10 / −1.0 | same `PageTitle` 28 | `headlineLarge` (32) |
| Question topic title | 26 / 900 / 1.12 / −0.65 | `QuestionAppBar` `titleLarge` 22, w600, `maxLines: 1` | `headlineMedium` (28 → 26), wraps |
| Main card title | 23–25 / 900 / 1.15–1.20 / −0.45…−0.65 | Today card `titleMedium` 16, w700 | `headlineSmall` (24) |
| Section title | 20–21 / 800 / 1.20 / −0.4 | `_SectionLabel` `labelLarge` 14, w700, in `secondary` (Home `:1272`, Profile `:673`) | `titleLarge` (22 → 20), `onSurface` |
| Topic / weak spot card title | 17–18 / 800 / 1.23 / −0.25 | weak spot `bodyLarge` 16 w400; topic `titleMedium` 16 | `titleMedium` (16 → 17) |
| Question scenario | 16 / 400 / 1.55 / 0 | `bodyLarge` 16, height 1.5 | `bodyLarge`, height 1.55 |
| Body | 13–14 / 400 / 1.45–1.50 / 0 | `bodyMedium` 14 / 1.5; `bodySmall` 12 / 1.45 | `bodyMedium` 14 / 1.45; `bodySmall` 13 |
| Small meta | 11–12 / 600–800 / 1.40 / 0 | `labelSmall` 11 (M3 w500), `labelMedium` 12 (w500) | `labelSmall` / `labelMedium`, w600–800, height 1.4 |
| Button | 14–15 / 800 / 1.30 / 0 | 16, w600 (`theme.dart:550,561`) | 14, w800 |

The weights 800 and 900 are already used in the app (`w800` in seven
places), so this adds no new font asset.

---

## 2. Earlier decisions this replaces

### 2.1 The orange band (`bandBackground`)

- **Today:** D1 (`docs/design-audit.md` §5). An orange header band in
  light mode and a neutral one in dark, over a neutral body. The rule
  lives in `extension BandColors` (`theme.dart:187-199`), which also
  supplies the theme's `scaffoldBackgroundColor` and app bar colours
  (`:476-498`).
- **The brief:** "Turuncu artık büyük, tüm ekranı kaplayan app bar
  değildir" — orange is no longer a big app bar. Orange stays only on
  meaningful elements: the Home daily card, the Review allowance card, the
  Profile points label, the question counter and the Topic access label.
  Page titles sit on the page colour.
- **Affected:** `theme.dart`, `brand_scaffold.dart` (the band, `title:`,
  the iPad band inset `:159-173`) and every reader of the band foreground
  (`appBarTheme.foregroundColor` / `bandBackground` / `bandForeground`):
  `utils/page_title.dart`, `utils/loading_view.dart:51`,
  `widgets/result_score_band.dart:24`, `widgets/question_app_bar.dart`,
  `widgets/floating_nav_shell.dart:128`, `screens/home_screen.dart:1066,1499`,
  `screens/daily_test_screen.dart` and `screens/welcome_screen.dart:100`.
  Every pushed screen on `BrandScaffold` loses the band too, including
  Premium, results and onboarding (§7).

### 2.2 The orange primary button

- **Today:** there is no orange primary button. Light mode stopped using
  the band orange for buttons in v2.2 (`filledButtonTheme` →
  `secondary`, `theme.dart:540-552`). The last orange fill, the dialog
  "Cancel", became a neutral text button (`DestructiveDialogActions`,
  noted at `theme.dart:183-186`).
- **The brief:** the CTA is navy `#0D3B8F` with white text in **both**
  themes, including inside the orange daily card. The one orange-filled
  control left is the counter / access / points label, which is not a
  button.
- **What actually changes:** the **dark** button goes from `#5C7CFA` with
  dark `#04123A` text to `#0D3B8F` with white. That is a different look
  and the source of the 1.48:1 edge problem (§3). Affected: `theme.dart`
  (filled and outlined button themes), `widgets/practice_step_footer.dart:60`,
  which sets `secondary` itself, `practice_length_picker.dart`
  (`:141-148, 408`), `onboarding_screen.dart:236` and
  `premium_screen.dart:336,1537,1604`.

### 2.3 "In dark mode, orange is never a surface"

- **Today:** D1's dark-mode rule. `bandBackground` is `surface` in dark
  (`theme.dart:188-191`: "Dark mode never uses orange as a surface").
- **The brief:** in dark, orange **is** a surface again. The Home daily
  card, the Review allowance card, the question counter, the Topic access
  label and the Profile points label are `#FF8A3D` fills, always with dark
  text (`#241200`, 7.71:1). "Dark modda turuncu yüzeyin yazısını beyaza
  çevirmeyin" — do not switch to white text on orange in dark mode.
  Measured: `#F0ECE7` on `#FF8A3D` is 1.99:1 and white is 2.35:1, so the
  brief's rule is the only legible one.
- **Affected:** the `BandColors` doc comment and the decision text. In
  code, the new orange surfaces must take their text colour from
  `onPrimary` (now `#241200` in dark too), never from `onSurface`. Files:
  `home_screen.dart` (`_TodayCard`), `review_screen.dart` (new card),
  `settings_screen.dart` / `monthly_medal_collection.dart` (points label),
  `question_app_bar.dart` (counter), `topic_practice_screen.dart` (label).

### 2.4 The card border + elevation rule

- **Today:** `cardTheme` (`theme.dart:500-539`): `surfaceContainerHigh`
  fill, `elevation: 1` in black, a 1 px border in **`outline`**, radius
  20. It was chosen after measuring: `outlineVariant` was ~1.34:1 against
  the body and "genuinely hard to see" on the device, while `outline` is
  ~3.11 (light) and ~5.05 (dark) against the body.
- **The brief:** a 1 px border in `border` (`#DED5C6` / `#45454D`) plus a
  soft, coloured, larger shadow, radius 22–24.
- **Measured:** the new border is 1.41:1 (light) and 1.61:1 (dark)
  against the card, which is the same territory the D1 device check
  rejected. The shadow now carries part of the separation, and the
  card-to-page step is 1.11:1 (light) and 1.19:1 (dark). Q2 covers the
  decision.
- **Affected:** `theme.dart`, plus every hand-drawn card frame that copies
  the rule: `climb_card.dart:157` (`Border.all(color: scheme.outline)`),
  `:225` (plaque), `locked_premium_pill.dart` (`outlineVariant`), and any
  `Card(` user (Home ×3, weak spot card, topic card, Premium ×5, results
  ×2, Daily result ×3, weak spot detail ×3, length picker ×2).

---

## 3. Measured contrast

Light uses the light tokens, dark the dark tokens. ✗ marks a pair under
the threshold: 4.5:1 for text, 3:1 for UI component edges. Large text
(≥ 18.66 px bold) only needs 3:1, but no failing text pair is large.

### 3.1 Text on surfaces (needs 4.5)

| Pair | Light | Dark |
|---|---:|---:|
| textPrimary on pageBackground | 14.96 | 15.51 |
| textPrimary on cardSurface | 16.64 | 13.00 |
| textPrimary on subtleSurface | 15.14 | 11.17 |
| textPrimary on navigationSurface | 16.78 | 11.65 |
| textSecondary on pageBackground | 8.14 | 10.75 |
| textSecondary on cardSurface | 9.05 | 9.01 |
| textSecondary on subtleSurface | 8.23 | 7.75 |
| textSecondary on navigationSurface | 9.12 | 8.08 |
| onOrange on brandOrange | 6.93 | 7.71 |
| onPrimaryButton on primaryButton | 10.30 | 10.30 |
| linkAndActive on pageBackground | 8.97 | 10.98 |
| linkAndActive on cardSurface | 9.98 | 9.20 |
| linkAndActive on subtleSurface | 9.08 | 7.91 |
| linkAndActive on navigationSurface | 10.06 | 8.25 |
| linkAndActive on infoSurface | 7.87 | 7.09 |
| onInfo on infoSurface | 9.79 | 9.04 |
| mockup "ink" on pageBackground | 15.76 | 15.51 |
| textPrimary on brandOrange (what **not** to do in dark) | 6.58 | **1.99 ✗** |
| white on brandOrange (not used) | 2.61 ✗ | 2.35 ✗ |
| mockup disabled label on disabled fill | **4.10 ✗** | 5.15 |

**Every text pair in the brief's table passes in both themes.** The only
failing text pair is the mockup's light disabled label, and WCAG 1.4.3
exempts inactive controls (Q4).

### 3.2 Component edges (needs 3)

| Pair | Light | Dark |
|---|---:|---:|
| primaryButton on pageBackground | 8.97 | **1.77 ✗** |
| primaryButton on cardSurface | 9.98 | **1.48 ✗** |
| primaryButton on subtleSurface | 9.08 | **1.28 ✗** |
| primaryButton on brandOrange (daily card CTA) | 3.95 | 4.39 |
| brandOrange card on pageBackground | **2.27 ✗** | 7.78 |
| brandOrange label on cardSurface | **2.53 ✗** | 6.52 |
| border on cardSurface | **1.41 ✗** | **1.61 ✗** |
| border on pageBackground | **1.27 ✗** | **1.92 ✗** |
| navigationBorder on pageBackground | **1.47 ✗** | **2.63 ✗** |
| navigationSurface on pageBackground | **1.12 ✗** | **1.33 ✗** |
| mockup input border on cardSurface | **1.63 ✗** | **2.59 ✗** |
| mockup path outline on pageBackground | **2.28 ✗** | 4.03 |
| infoSurface (selected segment) on subtleSurface | **1.15 ✗** | **1.12 ✗** |
| cardSurface on pageBackground | 1.11 | 1.19 |
| linkAndActive (focus ring) on cardSurface | 9.98 | 9.20 |
| destructive `#DC3232` on cardSurface / pageBackground | 4.48 / 4.03 | 3.31 / 3.95 |

For comparison, today's values: dark FilledButton `#5C7CFA` on the body
`#1C1B1F` is 4.66; the light card border (`outline`) on the body is 3.11;
the dark one is 5.05. The destructive colour still clears 3:1 on every new
surface, so the `theme_test.dart` contrast test stays green.

### 3.3 Proposals for each failure

1. **Dark primary button (1.28–1.77).** The label already identifies the
   button (10.30:1), so this is an edge problem, not a legibility one.
   Proposal: keep the brief's `#0D3B8F` fill and add a 1 px border **in
   dark mode only** in `#5C7CFA` (today's dark `secondary`). That measures
   4.16 on the card, 4.97 on the page and 3.58 on the subtle surface.
   Considered and not proposed: a lighter navy fill. The same hue reaches
   3:1 on the card only at `#1F67EB` (white text 5.00, card 3.06, page
   3.65, subtle still 2.63). It no longer reads as the brand navy, and it
   still fails on the subtle surface.
2. **Orange surfaces in light (2.27 / 2.53).** These are cards and labels,
   not controls: the CTA on top is the control (3.95:1 on the orange). No
   change. The text on them is 6.93:1.
3. **Card border (1.41 / 1.61).** Non-interactive cards are decorative
   (1.4.11 does not apply). Interactive cards (weak spot, topic, Review
   items) each carry a chevron or link in `linkAndActive`, which is ≥ 7.9:1
   on the card, so the affordance does not depend on the edge. Proposal:
   use the brief's values with the shadow, then **check on a device in
   Batch 1**, because the D1 device check rejected 1.34:1 (Q2).
4. **Input border (1.63 / 2.59).** A text field's edge is required to
   reach 3:1. Proposal: `inputBorder` `#8E8577` in light (3.53 on the
   card, 3.17 on the page, 3.21 on the subtle surface) and `#85818B` in
   dark (4.01 on the card, 3.45 on the subtle surface). The focused border
   stays `linkAndActive` (9.98 / 9.20).
5. **Nav bar edge (1.47 / 2.63) and nav surface (1.12 / 1.33).** The nav
   items are labelled icons, and the active tab is shown by colour **and**
   weight **and** a filled icon, not by the bar's edge. Proposal: use the
   brief's values (the shadow separates the bar).
6. **Selected segment (1.15 / 1.12).** Colour alone would mark the state,
   which the brief forbids ("Renk tek başına durum belirtmesin" — colour
   must not be the only signal). The mockup also sets the label to 800
   weight. Proposal: keep that weight change and turn the selected check
   icon back on (`AppSegmentedButton` sets `showSelectedIcon: false`).
7. **Path outline in light (2.28).** It is decorative; the plaque has text.
   No change.

---

## 4. Font: do 400/600/700/800/900 resolve without faux bold?

**Yes.** Measured two ways.

1. **The file.** `assets/fonts/NunitoSans-Variable.ttf` (571,240 bytes,
   SHA-256 `f934d714…a2491d`). I parsed its `fvar` table:

   | Axis | Min | Default | Max |
   |---|---:|---:|---:|
   | `wght` | 200 | **200** | 1000 |
   | `wdth` | 75 | 100 | 125 |
   | `opsz` | 6 | 12 | 12 |
   | `YTLC` | 440 | 500 | 540 |

   It has named instances ExtraLight 200 … Black 900. Its OS/2
   `usWeightClass` is 200 and its family name is "Nunito Sans 12pt
   ExtraLight". `pubspec.yaml:61-64` registers it once, with no `weight:`.

2. **Flutter's renderer.** Flutter 3.44.6 (`flutter test`, the same
   engine as the app's widget tests) loaded the file and laid out
   "Hamburgefonstiv GrammarLens" at 40 px three ways: `fontWeight` only,
   `fontVariations: [FontVariation('wght', n)]` only, and both. I measured
   the advance width and the "ink" (total darkness of the rendered
   pixels):

   | Weight | Width (pt) | Ink | `wght` variation alone gives |
   |---|---:|---:|---|
   | 200 | 556.40 | 3,057 | identical |
   | 400 | 574.44 | 4,813 | identical |
   | 600 | 583.70 | 5,674 | identical |
   | 700 | 594.80 | 6,679 | identical |
   | 800 | 606.97 | 7,734 | identical |
   | 900 | 619.60 | 8,794 | identical |

   Faux bold thickens the outlines and leaves the advance widths alone.
   Here the width grows at every step, and `FontWeight` matches the
   explicit `wght` instance to the pixel. So Flutter is selecting real
   instances on the weight axis; there is no synthetic emboldening.

**Caveats.**

- Not measured on an iOS device. `flutter test` uses the host's Skia
  text stack, and the brief itself warns that rasterisation can differ.
  The Batch 1 device check should compare 400 / 800 / 900 by eye.
- Because the default instance is ExtraLight, any path that ignores
  `FontWeight` would render thin, not bold. If that ever shows up on a
  device, the fix is adding `fontVariations` to the theme's text styles.
  Nothing suggests it today: no `FontVariation` appears in `lib/`, and the
  app's w700/w800 text has looked bold in every device check so far.
- `opsz` maxes out at 12, so large titles (26–34 pt) use the 12 pt optical
  size. The browser mockup does the same with the Google Fonts static
  files, which are `opsz` 12 as well, so no difference there.

The probe code is in Appendix B.

---

## 5. What changes, screen by screen

(a) arrives through the theme alone; (b) arrives through a shared
component change; (c) is a screen-specific layout change.

### Home (`home_screen.dart`, 1,533 lines; UI at `:1063-1533`)

- **(a)** Page, card and text colours; the button look; the card radius
  and shadow; the dark link colour; nav colours.
- **(b)** `BrandScaffold` without the band, with the title in the body
  (`GrammarLens` 34/900). The nav bar becomes solid with a border and
  shadow. A section title component replaces `_SectionLabel` (20/800,
  `onSurface`). `WeakSpotCard` restyled (17/800 title, info count badge,
  link row). The climb plaque becomes a stadium shape with a 1.5 px
  outline, and the frame goes to 1.5 px (`climb_card.dart`).
- **(c)**
  - The greeting row: the hero grows from 60 to the mockup's 108, and
    "Good evening," / the name split into a 14 pt line and a 25/800 line.
  - `_TodayCard` becomes an orange card: a label row, a title and
    description, a score box ("5 questions" / "2/5 correct") and a navy
    CTA. Today the whole card is the tap target and there is no button.
  - `_PracticeModeCard` becomes a "Topic practice" section: a heading, a
    PREMIUM tag, a card with a horizontal strip of topic tiles (146 ×
    ≥ 118) and an "Explore all topics" link.
  - The weak spots section gets a count badge.
  - `_PremiumRow` is replaced by a Review call-out on the info surface.

### Review (`review_screen.dart`, 233 lines)

- **(a)** Colours, card look.
- **(b)** Page title in the body (34/900 plus the subtitle "Turn your
  mistakes into progress."). `WeakSpotCard` restyled: category eyebrow,
  18/800 title, excerpt, meta row with the count badge and a "Last seen"
  date.
- **(c)** The allowance card on top (orange when available, subtle with a
  border once used). The list heading "Saved weak spots N" moves the sort
  control from the app bar (`PopupMenuButton` in `actions`) into that
  heading row. The empty state is restyled.

### Profile (`settings_screen.dart`, 740 lines; build at `:366`)

- **(a)** Colours, segmented control colours (info surface for the
  selected segment), input look.
- **(b)** Page title in the body ("Profile" plus "Your journey, your
  way."). Section title component. Card for each group. `_NavRow` becomes
  a link row with a 34 × 34 icon tile. `MonthlyMedalCollection` restyled:
  no background, horizontal scroll, 86 pt discs.
- **(c)**
  - The identity card: "Your companion", the hero at 158 × 158, "Change
    your avatar", then a "Your name / name / Edit" row that expands into
    an inline form. Today it is an always-visible `TextField` plus a
    full-width Save (`:406-422`).
  - The monthly progress card: title, theme and active days, the orange
    points label, next medal, the bar, "N points to …", the threshold row
    and the monthly total.
  - Data and Credits move into a card. The debug-only Developer section
    stays.

### Question (`practice_screen.dart`, `daily_test_screen.dart`, `question_app_bar.dart`, `practice_step_footer.dart`)

- **(a)** Colours, input fill and radius.
- **(b)**
  - `QuestionAppBar` is rebuilt: an eyebrow (TOPIC PRACTICE / DAILY TEST),
    a 26/900 title that wraps, a bordered 44 × 44 close button, and
    previous-question placement (Q11). The counter moves from under the
    app bar into the card as an orange pill.
  - `PracticeStepFooter`: Skip becomes a text button (today an
    `OutlinedButton` 100 wide), the primary button 50 high with radius 15,
    and the disabled colours change (Q4).
  - `HeaderIconButton` grows from 40 to 44.
- **(c)**
  - The question content moves into one card: type label with an icon,
    counter, scenario at 16/1.55, and the instruction plus hint under a
    divider.
  - The "Your answer" label goes above the input. The input is multiline
    with a minimum height of 145 for `sentenceWriting` and
    `errorCorrection` (Q12), and stays single-line for `fillInBlank`.
  - Both screens share the change. `daily_test_screen.dart` has its own
    copy of the build (`diff` against `practice_screen.dart` differs only
    in its loading, error and close-only app bar states).

### Topic Practice (`topic_practice_screen.dart`, 251 lines)

- **(a)** Colours, card look.
- **(b)** Page header with a bordered 44 × 44 back button and the orange
  "Premium access" label; page title 32/900 plus the subtitle.
- **(c)** The list heading "Grammar topics · 5 topics". `_TopicCard`: the
  38 × 38 icon tile on the subtle surface (today a `CircleAvatar` 44 on
  `primaryContainer`), 17/800 title, 13/400 description, an 11/600 status
  line, a link-coloured chevron, padding 17 × 15, radius 22, gap 12. The
  activity bar is Q8. The `_generating` state (`:78-83`) is a plain
  `Scaffold` with an `AppBar`, so it picks up whatever the theme's scaffold
  colour becomes.

---

## 6. Items that are not purely visual

Each of these needs new data, state, copy or behaviour. Listed, not
built.

| # | Brief item | In the code today? | What is missing |
|---|---|---|---|
| N1 | Review: free allowance available / used | The data exists: `StorageService.getFreePracticeCountForToday()` and `freeDailyPracticeLimit` (`storage_service.dart:844`); read by `WeakSpotDetailScreen` (`:79`) | Review does not read it or `hasFullAccess`. A read on load and on tab return (no new storage), plus new copy ("1 free practice available today", "Next free practice tomorrow", the titles and descriptions). Premium users: Q13 |
| N2 | Review: "free practice" on **any** chosen weak spot | Yes: the quota is per day, not per topic (`launchPracticeSet` → `recordFreePracticeStarted`) | Nothing in logic. The quota is used up only on successful generation, which already matches "not by the UI tap" |
| N3 | Weak spot detail: "Start free practice" / "Practise with Premium" | The detail screen has "Practice this" plus a quota caption and the exhausted row with `freePracticeUsedMessage` | New button copy. The mockup shows a bottom sheet; today it is a pushed route (Q14) |
| N4 | Home: daily card copy (“Your next step.”, "Take today’s test…", "Free every day", "5 questions" / "2/5 correct", "Start daily test" / "Review results", "New test tomorrow. Review today’s answers.") | Score and completion exist (`computeDailyTestScore`, `isCompleted`); the copy is different (`:1336-1343`) | New copy, and a CTA button replaces the whole-card tap (same two handlers, `onStart` / `onViewResult`) |
| N5 | Home: horizontal topic tiles | Topics exist (`kTopics`, 5). The mockup's tiles (Tenses, Prepositions…) are not the app's topics | What a tile tap does for a premium user: today Home only opens the topic **list**. Starting a topic directly would be a routing change (Q9). Strip arrows are new behaviour (Q10) |
| N6 | Home: Review call-out instead of the Premium row | No | New copy. It removes a paywall entry point (`paywallSourceHome` via `_openPremium`); the analytics event itself is unchanged (Q15) |
| N7 | Home: weak spots count badge ("1 topic") | Derived from `_weakSpots.length` | New copy |
| N8 | Profile: inline name edit with Save / Cancel | Empty or whitespace-only names are already blocked (`_canSaveProfile`, `:286`). No length limit exists in code, so the mockup's 32 is not introduced | New local UI state (editing flag, cancel restores the text); no storage change |
| N9 | Profile: next medal, "N points to go", completion after Gold, "Monthly total" | The data exists: `MonthlyMedalRules.nextTier()` (`monthly_medal_rules.dart:58`), `threshold()`, `maxScore()`, `MonthlyMedalProgress.score` / `activeDays` | New copy per state (before Bronze, before Silver/Gold, after Gold). No new rule |
| N10 | Profile: medal detail on tap | **Exists:** `showMedalDetail` (`monthly_medal_collection.dart:~315`), 200 ms, scale .8 → 1 `easeOut`, honours `disableAnimations` | Only the timing (240 ms) and content layout |
| N11 | Profile: medals newest first, the running month faded to ~.38 | The order today is Welcome first, then oldest → newest (decision N34) | An order change that contradicts N34 (Q7). The fade exists for a running month without a tier |
| N12 | Profile: "1 earned" count, "Your journey, your way.", "Your companion" | No | New copy (the count is derived) |
| N13 | Question: previous-question arrow | **Exists:** `QuestionAppBar.showBack` / `onBack` ("Previous question"), hidden on question 1 | Placement only (Q11) |
| N14 | Question: heading ("Share your hobbies."), two-step instructions, "2 connected sentences" | No. `PracticeItem` has `type`, `context`, `instruction`, `hint` | The data contract does not carry them; the brief says keep the existing text. Not built (Q12) |
| N15 | Question: eyebrow (TOPIC PRACTICE / DAILY TEST) | No | New copy, known from the screen |
| N16 | Question: exit confirmation | **Exists** (`_confirmExit`, `PopScope`) | Restyle only |
| N17 | Question: Next disabled when empty | **Exists** (`_currentHasAnswer`) | — |
| N18 | Topic: status line | **Exists:** "Not started yet" or `formatTopicStatsLine(practiced, weakSpotCount)` plus the activity bar (`_activityCap = 20`) | Whether the bar stays (Q8) |
| N19 | Topic: "Premium access" label, "Choose a topic to work on.", "Grammar topics", "5 topics" | No | New copy. The access label is shown on a screen only reachable with access (Home's guard, `:965`) |
| N20 | Medal / climb plaque: "neutral surface, not tied to the map theme" | Already neutral (`surfaceContainerHigh`, `climb_card.dart:224`); the month and step chips use Green Slope's `sky` and `ink` regardless of the theme | Plaque shape (trail sign → stadium) is a reversal of the 2026-10-02 owner decision on corner radius (Q16) |
| N21 | Navbar: solid surface + border + shadow | Frosted glass (`BackdropFilter` blur 24, translucent) from the nav bar revision rounds | Visual only, but it reverses a recorded decision (Q17) |

No item needs a storage schema change, a new analytics event or a new
service call. The ones closest to logic are N1 (a new **read** on
Review), N5 (Q9) and N6 (Q15).

---

## 7. Screens not in the mockup

What the new tokens alone would do to each, and the risk.

| Screen | How it is built | What changes | Risk |
|---|---|---|---|
| **welcome** (685 lines) | Plain `Scaffold`, **no `backgroundColor`** (`:127`); inherits `scaffoldBackgroundColor` = band = orange in light. `appBarFg` (`:100`), `_kWarmAccent` | When the scaffold colour becomes the page colour, Welcome **stops being orange** in light, against D1's "the one deliberate exception" | **High**, silent. Pin `backgroundColor: colorScheme.primary` (light) and its foreground in Batch 1 |
| **premium** (1,959 lines) | `BrandScaffold` with the band; 5 cards; plan selection uses `secondary`; LockedPremiumPill | Band gone; dark plan selection and CTA from `#5C7CFA` to `#0D3B8F` / `#B4C8FF`; card radius and border | **Medium-high:** largest file, 21 look-marker tests, a known footer issue at 375 × 667 (since 1.0.0); App Store screenshots |
| onboarding | `BrandScaffold`; selected option `secondary` fill (`:236`) | Dark selected fill becomes `#B4C8FF`, which needs a dark label (`onSecondary` `#0A2E70`, 7.72:1) | Medium: check that the label colour follows |
| ai_consent | `BrandScaffold`, text buttons | Band gone, colours | Low |
| results | `BrandScaffold` with `ResultScoreBand` in `bandBottom` (`:149`); `OutlinedButton` "Back to topics" | The score loses its orange band and sits on the page colour in `appBarTheme.foregroundColor` | Medium: the emphasis changes; `SemanticColors` cards unchanged |
| daily_test_result | Same `ResultScoreBand` (`:284`); 4 FilledButtons; "Also correct" line | Same as results | Medium (protected Daily Test result logic: look only) |
| weak_spot_detail | `BrandScaffold`; loading uses a plain `Scaffold` (`:156`) | The loading flash changes from orange to the page colour (an improvement). Quota row and LockedPremiumPill restyle | Low–medium: entry point of N3 |
| data | `BrandScaffold`, 2 FilledButtons, `OutlinedButton` Cancel in a dialog | Colours | Low |
| credits | `BrandScaffold`, text | Colours | Low |
| avatar_picker | `BrandScaffold`, carousel, FilledButton; Hero from Home (`homeAvatarHeroTag`) and Profile | Colours. The Hero source grows (Home 60 → 108, Profile 52 → 158), so the flight changes size | Low–medium: look at the Hero flight |
| practice_length_picker (bottom sheet) | Sheet `surfaceContainerLowest` (`#FFFFFF`); selection card `secondaryContainer`; slider and dial use `secondary` / `onSecondary` (`:141-148, 408`) | Dark: the slider and dial fill become `#B4C8FF`. The thumb chevron uses `onSecondary` and so becomes `#0A2E70` (7.72:1). The light sheet stays white | Medium: dark dial and track colours, see `practice_length_picker_test` |
| LoadingView (7 callers) | Reads `appBarTheme.foregroundColor` and `secondary` (`utils/loading_view.dart:51,74`) | Follows the theme | Low |

---

## 8. Test impact

Totals over `test/` (Appendix C): **1,126** test cases in 118 files.
**111** contain a look marker (colour, `getSize` / `getRect` / position,
font size or weight, radius, border, contrast, or the type of a styled
widget). **1,015** contain none. Not every marked test will break: many
check positions that the redesign keeps.

**Expected to need updating (look or structure), in scope. Read one by one:**

| File | Tests | Why |
|---|---:|---|
| `home_screen_test.dart` | 16 | The "Topic Practice" card: text, taps, scroll target and the full-width check (`:282, :386, :1012-1114`); Premium row; order "Today → Topic Practice → Premium row" (`:1040`); Today card copy; band-foreground colour (`:1205`). Tests at `:282, 386, 767, 983, 1012, 1023, 1040, 1065, 1077, 1090, 1108, 1114, 1146, 1183, 1196, 1205` |
| `home_climb_card_test.dart` | 1 | Plaque geometry ("plaque on the line", `:54`) if the plaque changes shape or line width |
| `climb_card_test.dart` | 2 | The plaque radius derivation (`:107`) and the sign shape (`:164`) if Q16 goes the brief's way |
| `practice_step_footer_test.dart` | 4 | `widgetWithText(OutlinedButton, 'Skip')`, 52 high, 12 apart, disabled colours |
| `question_app_bar_test.dart` | 2 | "Back and Close are both 40x40" (`:74`); title centring (`:39`) |
| `settings_screen_test.dart` | 4 | Always-visible `TextField` (tests at `:182, :199, :365`); section order (`:471`) |
| `monthly_medal_collection_test.dart` | 1 | N34 order "Welcome first, then oldest → newest" (`:123`) if Q7 goes the brief's way; the threshold layout tests (`:289, :319`) only if the bar layout changes |
| `theme_test.dart` | 0 | Font family, ordered type scale and destructive contrast stay valid (destructive measured ≥ 3.31 on the new surfaces) |

That is **30 tests** that will need updating in scope.

**Collateral: they find Skip by its widget type.** 8 more tests
(`first_launch_flow_test` 3, `first_launch_climb_test` 2,
`daily_test_screen_test` 2, `practice_screen_keyboard_test` 1) and one
shared helper each in `first_launch_flow_test.dart:240` and
`first_launch_climb_test.dart:176` use
`find.widgetWithText(OutlinedButton, 'Skip')`. Their behaviour stays the
same, but the finder must become `TextButton`. `results_screen_test` (4),
`data_screen_test` (2) and the exit dialog tests use `OutlinedButton` for
other buttons that are out of scope; they do not change.

**Behaviour that must stay green unchanged.** All the rest. In
particular: `daily_test_*`, `home_daily_test_service_test`,
`practice_launch_*` (free tier, daily cap, consent), `storage_service_*`,
`claude_service_test`, `analytics_*`, `monthly_medal_rules_test`,
`medal_finalization_test`, the climb and month-transition tests,
`practice_screen_exit_dialog_test` and `weak_spot_detail_screen_test`
(quota). These cover the invariant. A batch that turns one of them red
has changed logic.

**Keyboard layout tests** (`practice_screen_keyboard_test.dart:163, :211`:
"the button returns to the bottom once the keyboard closes", "the question
header position is unaffected by the keyboard opening") lock in the
current pinned-input design. The brief's input near the card with a
minimum height of 145 has to keep both properties, or the tests change.
That is a decision in Batch 6, not a mechanical update.

There are no golden tests (`matchesGoldenFile`: 0).

---

## 9. Proposed batch plan

Each batch: `flutter analyze`, the full suite green (expected test updates
only, listed per batch), light and dark on a device at 320 / 390 / 430 pt,
Large text, then commit. App Store screenshots and case-study images are
flagged at each step (memory rule from 1.1.0).

**Batch 1 — theme and typography**

- Files: `lib/theme.dart`, `lib/widgets/brand_scaffold.dart` (drop the
  band: title in the body or a neutral app bar), `lib/utils/page_title.dart`,
  `lib/screens/welcome_screen.dart` (pin the orange), and the doc comments
  that state D1.
- Contents: the token values from §1.1; the `AppPalette` extension;
  `secondary` / `onSecondary` remapped in dark; the button themes (radius
  14, minimum height 48, 14/800, dark 1 px border per Q1); the input
  theme (radius 18, border per Q3); `cardTheme` (radius 24, border,
  shadow per Q2); the text theme per §1.3 and Q5.
- Tests: `home_screen_test:1205` (band foreground).
- On the device: Welcome is still orange; the font weights 400 / 800 /
  900 look right (§4); card edges are visible in both themes (Q2); dark
  buttons on the card and page; Premium and results without the band; the
  launch splash to Home transition (the splash follows the system
  appearance, a known 1.1.0 flaw).

**Batch 2 — shared components**

- Files: `floating_nav_shell.dart` (solid, border, shadow, radius 29,
  unselected colour), a new section title widget (replaces the two
  `_SectionLabel`s), `weak_spot_card.dart`, `question_app_bar.dart`
  (`HeaderIconButton` 44), `practice_step_footer.dart`,
  `app_segmented_button.dart` (selected icon, §3.3 item 6),
  `locked_premium_pill.dart`, `climb_card.dart` (plaque per Q16, 1.5 px).
- Tests: `practice_step_footer_test` (4), the `OutlinedButton` Skip
  finders (8 tests, 2 helpers), `question_app_bar_test` (2), and `climb_card_test` /
  `home_climb_card_test` (3) if Q16 is accepted.
- On the device: nav clearance (`NavBarClearance` re-measures), the iPad
  column (P1 / P2), the plaque at 320 pt with Large text.

**Batch 3 — Home**

- Files: `home_screen.dart` (UI only, `:1063-1533`),
  `widgets/home_greeting.dart`, possibly a new `topic_tile.dart`.
- Tests: `home_screen_test` (16, minus `:1205` if Batch 1 already
  updated it).
- On the device: daily card ready and done (real score), the strip
  scrolls and does not scroll the page, free taps go to the paywall,
  premium taps per Q9, 320 pt Large text (the greeting with the 108 pt
  hero: the 1.1.0 320 pt name fix must hold), the month card and zoom
  still work (Batch 6 / M21 peek: `HomeScreen.monthCardTodayPeek = 56`
  assumes the old Today card's height).

**Batch 4 — Review**

- Files: `review_screen.dart` (+ the allowance read, N1),
  `weak_spot_card.dart` (if Review needs a variant),
  `weak_spot_detail_screen.dart` (restyle, N3 copy).
- Tests: none expected beyond Batch 2. New tests for available / used /
  premium.
- On the device: use the free practice and come back (the card turns to
  "used"); premium user; empty state; sort persists.

**Batch 5 — Profile**

- Files: `settings_screen.dart`, `monthly_medal_collection.dart`,
  `avatar_tile.dart` (158 box).
- Tests: `settings_screen_test` (4), `monthly_medal_collection_test` (1
  or more per Q7).
- On the device: name edit (Save, Cancel, empty), the next-medal line
  before Bronze, between tiers and after Gold (debug panel samples), medal
  detail with Reduce Motion, the Hero flight to the picker.

**Batch 6 — question screen**

- Files: `practice_screen.dart`, `daily_test_screen.dart` (presentation
  only; Daily Test logic is protected), `question_app_bar.dart`.
- Tests: the keyboard tests (2, decision first).
- On the device: keyboard open on 320 × 568 with a multiline input
  (**not measured** how much room is left), the previous arrow from
  question 2, exit confirmation, the Daily Test with 5 questions, an
  error state, fill-in-blank as a single line.

**Batch 7 — Topic Practice**

- Files: `topic_practice_screen.dart`.
- Tests: none expected.
- On the device: five topics, long titles at Large text, the generating
  state, return refreshes the stats.

---

## 10. Open questions

Each has one recommendation.

- **Q1. Dark primary button edge (1.48:1 on the card).** Recommendation:
  keep `#0D3B8F` and add a 1 px `#5C7CFA` border in dark only (4.16 /
  4.97 / 3.58). Why: it keeps the approved navy, fixes the edge on every
  dark surface, and the border colour is already the app's dark accent.
- **Q2. Card border 1.41 / 1.61.** Recommendation: use the brief's
  `border` plus the shadow, and judge it on the device in Batch 1. If it
  is too faint, go back to `outline` for interactive cards only. Why: the
  1.34:1 rejection in D1 was for a card **without** the new shadow; this
  is a different combination and only a device can tell.
- **Q3. Input border.** Recommendation: `#8E8577` in light and `#85818B`
  in dark instead of the mockup's `#D2C6B4` / `#66636B`. Why: a text
  field's edge is the one place 1.4.11 clearly applies, and these keep
  the warm tone while reaching 3:1 against both the card and the page.
- **Q4. Disabled button colours.** Recommendation: use the mockup's
  values (`#E4DDD2` / `#6D6860`, `#36363B` / `#ACA8B2`) as `disabledFill`
  / `disabledLabel`. Why: inactive controls are exempt, and 4.10 is
  close; the state is also given by the label ("Next" is unchanged, the
  button just doesn't respond).
- **Q5. Which text size are the brief's numbers for?** Recommendation:
  the brief's sizes are what the **default (Medium)** setting renders, so
  the base sizes are the brief's ÷ 1.1 (34 → 30.9 at Small, 34 at Medium,
  37.1 at Large). Why: the owner approved the mockup at its Medium, and
  Medium is the app's default. Taking them as base sizes would make every
  default screen 10 % larger than approved ("GrammarLens" 238 pt wide
  instead of 215 at 34 pt). Measured widths at 320 pt with 14 pt padding
  (292 available): "GrammarLens" fits at Large (261.5); "Gerund vs.
  Infinitive" at 26 needs two lines next to the 44 pt close button at any
  size, which is why the title must wrap.
- **Q6. The mockup's "ink" `#241200` for light titles and nav labels.**
  Recommendation: drop it and use `textPrimary` `#1B1B1F`. Why: it is not
  in the brief's table, the difference is 15.76 vs 14.96:1, and one text
  colour is simpler.
- **Q7. Medal order.** Recommendation: follow the brief (newest left, the
  running month first, Welcome last) and update the N34 test. Why: the
  brief is the later owner decision, and newest-first keeps the current
  month visible without scrolling once the shelf is long.
- **Q8. Topic activity bar.** Recommendation: remove the bar and keep the
  text line ("Not started yet" / "N practiced · M weak spots"). Why: the
  brief forbids "yüzde ilerleme" (percentage progress), and the bar is a
  fraction of an arbitrary cap of 20; the text is real data.
- **Q9. What a Home topic tile does for a premium user.** Recommendation:
  in 1.2.0 every tile and "Explore all topics" opens the existing Topic
  Practice screen; free users get the paywall as today. Why: starting a
  topic straight from Home is a new route, and the invariant forbids
  routing changes. It can be a separate decision.
- **Q10. Arrows under the topic strip.** Recommendation: leave them out.
  Why: swipe already works, and the arrows add state (disabled at either
  end) and two more 44 pt targets for five tiles.
- **Q11. Where the previous-question arrow goes.** Recommendation: a
  bordered 44 × 44 button at the left of the title row, the same style as
  the close button, hidden on question 1 as now. Why: the brief keeps the
  behaviour; the mockup only shows question 1.
- **Q12. Question card content.** Recommendation:
  - Scenario = `context`, then `instruction` as one paragraph, then `hint`
    muted. No heading, no numbered steps, no "2 connected sentences".
  - Multiline (minimum 145) for `sentenceWriting` and `errorCorrection`;
    single line for `fillInBlank`.
  - Why: the data has no heading or steps, and the brief says not to
    invent them. Error correction answers are full sentences.
- **Q13. The Review allowance card for premium users.** Recommendation:
  hide it. Why: premium has no quota to describe, and the brief only
  defines the free states.
- **Q14. Review detail as a sheet or a screen.** Recommendation: keep the
  pushed screen and restyle it. Why: routing invariant, and the detail
  screen carries the practice launch and the error states.
- **Q15. Removing Home's Premium row.** Recommendation: follow the brief.
  Free users still reach the paywall from the PREMIUM topic strip and
  "Practice with Premium" on weak spots. Why: owner-approved, and it
  matches the free practice the Review call-out points to. Note: one
  fewer paywall source on Home; the event and source name stay.
- **Q16. The plaque shape.** Recommendation: the brief's stadium with a
  1.5 px outline. Why: the brief describes it as "oval, çerçeveli plaka"
  (an oval, outlined plate) and is the newer decision; the trail-sign
  radius (0.7, owner 2026-10-02) is replaced. Two tests change.
- **Q17. Frosted nav bar.** Recommendation: solid per the brief. Why: the
  brief specifies a solid colour, a border and a shadow, and a solid
  surface keeps the label contrast measurable (8.08–16.78:1). The blur
  makes it depend on what scrolls behind it.
- **Q18. Narrow-screen cut-off for 14 pt padding.** Recommendation: under
  360 pt width. Why: covers 320 pt (iPhone SE 1st gen) and leaves 375 and
  above at 18. The brief gives no number.
- **Q19. The staged design package.** Recommendation: commit
  `docs/design/1.2.0/` (brief, tokens, HTML) in its own commit before
  Batch 1 (`docs: 1.2.0 design package`). Why: the report and later
  batches refer to it, and it is still only staged. This report's commit
  contains only the report.

---

## Appendix A: contrast script

```python
def lum(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def cr(a, b):
    la, lb = lum(a), lum(b); hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

# e.g. cr('#0D3B8F', '#252528') -> 1.48
```

## Appendix B: font probe

A `flutter test` file run from outside the repo (`flutter test <path>`
from the project root). It loads the font with `FontLoader('NunitoSans')`,
lays out the string with `TextPainter`, paints it on white to a 1200 × 80
image, and sums `(255 − R) / 255` over the pixels as "ink". It does this
for `FontWeight.wN`, for `FontVariation('wght', N)`, and for both
together. `width` is `TextPainter.width`. Results in §4. The same harness
measured the title widths in Q5.

## Appendix C: test scan

A test case is the span from a line matching `^\s*(testWidgets|test)\(`
to the next one. A case counts as "look" if its span matches:

```
colorScheme\.|Color\(0x|\.color\b|backgroundColor|foregroundColor|fontSize|
fontWeight|letterSpacing|BorderRadius|borderRadius|BorderSide|elevation|
getSize\(|getRect\(|getTop(Left|Right)\(|getBottom(Left|Right)\(|getCenter\(|
\.size\.(width|height)|contrast|luminance|byType\((Card|FilledButton|
OutlinedButton|TextButton|CircleAvatar|AppBar|Divider|ElevatedButton|
SegmentedButton|ColoredBox|DecoratedBox|Container)\)|bandBackground|
bandForeground|surfaceContainer|outlineVariant|textScaler|TextStyle
```

The structure and copy hits in §8 come from a second pass with the old
strings ("Topic Practice", "Unlock targeted practice", `OutlinedButton`
"Skip", `TextField`, `HeaderIconButton`, the N34 order). Each hit was then
read.
