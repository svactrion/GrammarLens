# 1.2.0 additional screens — Batch 0 report

**Status: read and measured; nothing is built.** Branch `1.2.0`, package
committed as `5caf517`. No `lib/`, `test/`, asset or `pubspec` change.
Written 2026-10-05. Line numbers refer to `5caf517`.

Scope of the package: Paywall, a two-step Onboarding, Question V2. Question
V2 replaces the question design in `docs/design/1.2.0/` (that report's §5
"Question", Q11 and Q12). Home, Review, Profile and Topic Practice
(Batches 1–9) are unchanged.

Inputs read: every file in the package (`README.md`,
`CLAUDE-CODE-BRIEF.md`, `ACCEPTANCE-CHECKLIST.md`, `design-tokens.json`,
`CLAUDE-START-PROMPT.txt`, `index.html`, the three `source/` files: visible
text, CSS values and scripts, base64 images stripped); `lib/screens/`
`premium_screen.dart`, `onboarding_screen.dart`, `welcome_screen.dart`,
`first_launch_flow.dart`, `practice_screen.dart`, `daily_test_screen.dart`,
`ai_consent_screen.dart`; `lib/widgets/` `question_app_bar.dart`,
`practice_step_footer.dart`, `avatar_carousel.dart`, `brand_scaffold.dart`,
`home_greeting.dart`; `lib/services/` `subscription_service.dart`,
`storage_service.dart`, `analytics_service.dart`; `lib/models/`
`learning_goal.dart`, `user_profile.dart`, `practice_item.dart`,
`daily_test_question.dart`; `lib/theme.dart`; `docs/analytics-plan.md`;
the proxy's `src/anthropic.ts` and `src/validation.ts`; the
`purchases_flutter` 10.10.1 package source in the pub cache; the tests
named in §2f, §3 and §4.

How things were measured:

- **Contrast:** WCAG 2.x relative luminance from the hex values, the same
  script as `docs/design/1.2.0/batch0-report.md` Appendix A.
- **Tests:** test definitions (`test(` / `testWidgets(`) counted with
  `grep`, then classified by reading their names. Loops over devices or
  brightness make the run-time case count higher; both are given where it
  matters.
- **External facts:** the live privacy policy
  (`https://ahmettayfur.com/products/grammarlens/privacy/`, "Last updated
  22 September 2026") and Apple's "Set up offer codes" help page were
  fetched on 2026-10-05.
- Things not measured are marked **not measured**.

---

## Summary

1. **Behaviour changes, not only visuals.** The package changes behaviour in
   eleven places (listed in §0). Four of them need an owner decision before
   code: the goal's "skipped" value, whether the goal leaves the device,
   the optional name rule in Profile, and the redeem-code flow.
2. **The sideways answer field is one missing setting.** Both question
   screens build a `TextField` without `maxLines`, so it is the default
   single line (`practice_screen.dart:253-267`,
   `daily_test_screen.dart:362-373`). Drafts are already kept per question
   ID with one controller per question; the brief's "ID-based drafts" are
   mostly there already (§2b).
3. **The goal is never sent anywhere today.** It is stored in
   `user_profile.learning_goal` and read by nothing but onboarding itself.
   The package's new copy ("Your answer helps us decide what to improve
   next") would be untrue as things stand. Sending it would contradict
   four published or on-screen statements, the live privacy policy among
   them (§3d).
4. **The paywall already breaks one of its own rules.** With no
   introductory offer the disclosure still says "Free trial"
   (`premium_screen.dart:519-521`), the button always reads "Start free
   trial" (`:694`), and trial eligibility is never checked (no call to
   `checkTrialOrIntroductoryPriceEligibility` in `lib/`). A user who has
   already used a trial is still promised one (§4a).
5. **Redeem code: Apple's sheet is available.** `purchases_flutter` 10.10.1
   has `Purchases.presentCodeRedemptionSheet()` (iOS 14+; the app targets
   15.0). It returns at once with no result, so none of the mockup's
   modal states (invalid, expired, discount details…) can be shown by the
   app. Customers can only redeem once the app is **Ready for Sale**;
   sandbox codes can be tested before that (§5).
6. **A rule in the task prompt does not match the code:** premium is capped
   at **5** sessions a day (`StorageService.dailySessionLimit = 5`,
   `storage_service.dart:49`; roadmap line 653: "Session cap 10 → 5"), not
   10 (§6).

---

## 0. Visual vs behaviour changes

| # | Change | Screen | Kind |
|---|---|---|---|
| B1 | Answer field wraps and grows (multiline) | Question | Behaviour (input) |
| B2 | Return inserts a new line instead of closing the keyboard | Question | Behaviour |
| B3 | Back on question 1 is shown disabled instead of hidden | Question | Behaviour/visual |
| B4 | A "Review answer" / "Read full question" control closes the keyboard | Question | New behaviour |
| B5 | Draft restore includes selection and scroll position | Question | New behaviour |
| B6 | Onboarding splits into two steps with its own Back | Onboarding | Flow |
| B7 | Name becomes optional | Onboarding (+ Profile rule) | Validation rule |
| B8 | Goal becomes optional, stored as "skipped" | Onboarding | **Storage value** |
| B9 | "Your data & AI" information sheet | Onboarding | New UI, copy |
| B10 | Plans stacked, annual total shown big, plan-aware CTA and trial text | Paywall | Behaviour (pricing copy) |
| B11 | "Have a code?" entry | Paywall | **New store integration** |

Everything else in the package is visual: colours, sizes, radii, card
layout, the hero group, copy that only rephrases existing facts.

---

## 1. Token mapping

### 1.1 Base colours

The package's `colors` block equals the current theme value for value:
every light and dark entry (`background`, `card`, `tile`, `text`, `muted`,
`brand`, `onBrand`, `button`, `onButton`, `link`, `info`, `onInfo`,
`border`, `nav`, `navBorder`) matches `lib/theme.dart:41-124` and
`AppPalette` (`:442-486`). Nothing to add.

### 1.2 `screenOverrides` (Paywall, Onboarding, Question only)

| Token | Light: package / current | Dark: package / current | Status |
|---|---|---|---|
| `muted` | `#55535D` / `#46464F` (`onSurfaceVariant`, `theme.dart:76`) | `#C9C5D0` / `#C9C5D0` | **Conflict in light** |
| `info` | `#EAF0FC` / `#D7E1FA` (`secondaryContainer`, `:58`) | `#24314A` / `#243859` (`:103`) | **Conflict, both themes** |
| `warm` | `#FFE5CC` / none | `#442E21` / none | New |
| `onWarm` | `#713306` / none | `#FFBE88` / none | New |

Measured contrast:

| Pair | Light | Dark | Needs |
|---|---|---|---|
| `muted` override on page / card / tile | 6.58 / 7.32 / 6.66 | 10.75 / 9.01 / 7.75 | 4.5 |
| current `muted` on page / card / tile | 8.14 / 9.05 / 8.23 | same as above | 4.5 |
| `onInfo` on `info` override | 11.22 | 10.00 | 4.5 |
| `onInfo` on current `info` | 9.79 | 9.04 | 4.5 |
| `link` on `info` override | 9.01 | 7.84 | 4.5 |
| `muted` on `info` override | 6.60 | 7.67 | 4.5 |
| `onWarm` on `warm` | 7.96 | 7.82 | 4.5 |
| `info` override fill vs page | **1.00** | 1.40 | (fill) |
| `info` override fill vs card | 1.11 | 1.17 | (fill) |
| selected plan's 2 px `link` border vs card | 9.98 | 9.20 | 3 |
| `warm` fill vs card | 1.17 | 1.21 | (fill) |

Reading:

- All text pairs pass. The light `muted` override is lighter than today's
  (6.58 instead of 8.14 on the page) but still above 4.5.
- The light `info` override is the page colour to two decimals (1.00:1). A
  selected plan card would be told apart only by its 2 px border (9.98:1),
  which passes 3:1 on its own. That is acceptable, but the fill adds
  nothing in light mode.

**Proposal:** a screen-scoped `ThemeExtension` (for example
`AdditionalScreenTokens`: `muted`, `info`, `warm`, `onWarm`) read only by
the three screens. `ColorScheme` stays as it is, so no other screen
changes. Alternative: drop the `muted` and `info` overrides and use the
current tokens; the differences are small and that keeps one source of
truth (open question O1).

### 1.3 `screenMetrics` against the current theme

Text sizes follow owner decision Q5 (a brief size is what Medium renders;
`_briefSize` divides by 1.1, `theme.dart:190-191`).

| Package value | Current nearest | Note |
|---|---|---|
| Paywall title 28/900 | `headlineSmall` 24/900, `headlineMedium` 26/900 | New size; a local style through `_briefSize(28)` |
| Onboarding title 29 | none | New, as above |
| Question header title 17/900 | `QuestionAppBar` title `titleLarge` 20 at w600 (`question_app_bar.dart:123-125`) | Smaller and heavier |
| Question text 17/700, line height 1.45 | `bodyLarge` 16/400/1.55 with w700 for the instruction (`practice_screen.dart:232-236`) | New style |
| Instruction 13/1.5 | `bodySmall` 13/400/1.45 | Line height differs |
| Answer 16/1.5625 (25 pt) | input text today: theme default | New input style |
| Answer padding 13 × 12, radius 17 | input radius 18 (Batch 1) | Local `InputDecoration` |
| Question card radius 21, padding 15 × 14 | card radius 24 | Local |
| Icon target 44 | `HeaderIconButton.size = 40` (`question_app_bar.dart:22`) | Grows |
| Action height ≥ 48 | `PracticeStepFooter._height = 52` (`practice_step_footer.dart:34`) | Brief: 48 in production |
| Paywall CTA ≥ 52, radius 17 | `FilledButton` 48, radius 14 | Local override |
| Onboarding CTA ≥ 54 | 48 | Local override |
| Plan radius 19, min height 87, gap 10 | plan card radius 16, side by side, gap 12 (`premium_screen.dart:1476-1500`) | Layout change |
| Onboarding hero 150 × 165, side scale 0.72, opacity 0.48 | carousel radius 56 (112 pt), scale 0.8, opacity 0.5 (`avatar_carousel.dart:75, 90-91`) | Parameters (§3f) |
| Goal card radius 21, min height 91, gap 12, icon 40 | radius 16, gap 12, icon 26 (`onboarding_screen.dart:245-262`) | Local |

---

## 2. Question V2

### 2a. Why the answer field scrolls sideways

The `TextField` on both screens sets no `maxLines`, `minLines` or
`keyboardType`, so Flutter's default applies: `maxLines: 1`, a
single-line field that scrolls horizontally.

- `lib/screens/practice_screen.dart:253-267`
- `lib/screens/daily_test_screen.dart:362-373`

Roadmap line 113-119 records this (owner, 2026-10-05). How long answers
get: in the bundled fallback pool, `error_correction` answers are 52
characters (median) and up to 68; `fill_in_blank` answers at most 12.
**Estimate, not measured with the font:** at 16 pt about 8 pt per
character, a 52-character answer is ~416 pt against a ~330 pt field on a
390 pt phone, so the typical error-correction answer already needs two
lines.

### 2b. How drafts are kept today

Already by ID, not by index:

- `_answers` is a `Map<String, String>` keyed by `item.id`
  (`practice_screen.dart:43`, `daily_test_screen.dart:64`).
- One `TextEditingController` per item ID, created once
  (`practice_screen.dart:51-54` in `initState`;
  `daily_test_screen.dart:92-95` when the set loads) and disposed in
  `dispose` (`:57-63`, `:116-122`). They are not recreated on an index
  change.
- The field is keyed `ValueKey(item.id)` (`:254`, `:363`), so going back
  mounts a new `TextField` that is handed the same controller: the text
  and the controller's selection come back.

What the brief adds, and what has to change:

| Brief | Today | Change needed |
|---|---|---|
| Text kept across Next → Back → Next | Yes | None |
| Selection kept | Kept in the controller | Verify by test; no code |
| Answer field's scroll position kept | Not applicable (single line); a new `TextField` would start at offset 0 | One `ScrollController` per item ID beside the text controller, passed as `scrollController` |
| Question area scroll position | One `SingleChildScrollView` without a controller; position is lost per question | Reset to top per question (the mockup does `q.scrollTop = 0`); no change needed |
| `FocusNode` not rebuilt in `build` | No `FocusNode` today | One `FocusNode` created in `initState` (needed for "Review answer") |
| Unique IDs | Proxy rejects duplicate IDs only for shared Daily Test sets (`proxy/src/shared_daily_test.ts:528, 587`); Topic Practice IDs are model-generated "short unique slug" (`proxy/src/anthropic.ts:378`), unchecked | Already a latent risk today: two items with one ID share a draft. Optional: a client check when the set is parsed. Not in the brief |

### 2c. Back, exit, Skip, Next/Submit, empty answers

| Rule | Today | Brief | Difference |
|---|---|---|---|
| Back (top left) | Previous question; hidden on question 1 but keeps its 40 × 40 slot (`question_app_bar.dart:41-43, 110-118`) | Previous question; on question 1 **disabled**, layout kept | Visible-disabled instead of invisible. Needs a disabled semantic label |
| System back gesture | Opens the exit dialog (`PopScope`, `practice_screen.dart:168-175`, `daily_test_screen.dart:212-219`) | Not covered | Keep |
| Exit × | Confirmation dialog "Leave practice? / Your progress will be lost." (`practice_screen.dart:89-109`), "Leave Daily Test?" (`daily_test_screen.dart:162-182`) | "Existing rule and confirmation kept" | Mockup copy "You can keep editing your answers before finishing. / Keep practising / Leave practice" is different and no longer says progress is lost. **Proposal: keep today's copy** |
| Skip | `onSkip: _advance` (`practice_screen.dart:277`, `daily_test_screen.dart:383`): moves on **without clearing** a typed answer | "Skip applies the existing rule" | Same. Note: text typed and then skipped is still graded, because `_answers` keeps it. Unchanged by the brief; recorded so nobody "fixes" it by accident |
| Next / last | Next, then **Submit** (Practice, `:157`) or **Finish** (Daily Test, `:202`) | Next, then Submit | Daily Test label differs. Proposal: keep "Finish" (open question O5) |
| Empty answer | Primary disabled when `trim()` is empty (`:68-74`, `:127-130`) | Same | None |
| Return key | Single line: closes the keyboard, no submit (no `onSubmitted`) | New line | Changes (B2) |
| Tap outside | Unfocuses (`GestureDetector`, `:197-201`, `:311-313`) | Not mentioned | Keep; must not swallow taps meant for the answer's own scrolling |
| Double submit | Practice: `_submitting` swaps the body for `LoadingView` (`:111-112, 195-196`), so the button disappears; no early-return guard in `_advance`. Daily Test: `_finish` calls `pushReplacement` (`:150-159`); the button stays tappable during the ~300 ms transition | "Block double submission" | **Not measured.** Add an `if (_submitting) return` / `_finishing` guard. `completeDailyTest` is already a no-op for an already-completed set (`storage_service.dart:978-980`) |
| Scoring failure | SnackBar, answers kept in controllers (`:134-136`) | Keep text | None |
| Autocorrect | **Off on purpose**, with tests: "the keyboard must not fix the learner's mistake" (`:258-264`, `:366-371`) | "Automatic correction keeps normal platform behaviour" | **Conflict.** Proposal: keep it off (open question O4) |

### 2d. Question types per flow, and fill-in-the-blank

- **Daily Test:** `fill_in_blank` and `error_correction` only
  (`daily_test_question.dart` doc; proxy schema `anthropic.ts:398`). The
  fallback pool has 18 and 17 of each; day 0 has 3 and 2
  (`day_zero_daily_test.dart:25-127`). Answers: up to 12 characters (blank)
  and up to 68 (correction).
- **Topic Practice:** all three types, mixed 2 : 2 : 1
  sentence_writing : error_correction : fill_in_blank (`anthropic.ts:44-50`):
  3 questions → 1/1/1, 5 → 2/2/1, 10 → 4/4/2. Sentence and correction
  answers are full sentences.
- There is **no "Rewrite" type**. The mockup's "Rewrite" label sits on a
  question shaped like `sentence_writing`; production labels stay "Fill in
  the blank" / "Find and correct the error" / "Write a sentence"
  (`practice_screen.dart:142-151`).

**Recommendation:** one multiline field for every type (wraps, never
scrolls sideways), satisfying "no answer type is forced into a horizontal
single line". `minLines`: 2 for `sentenceWriting` and `errorCorrection`
(the brief), **1 for `fillInBlank`** so a one-word answer does not sit in
an empty two-line box; it still wraps and grows if a long answer is typed.
This replaces 1.2.0's Q12 ("single line for fillInBlank"). Answers with
line breaks grade correctly: `normalizeAnswer` collapses `\s+` to one
space (`lib/utils/answer_matching.dart:21`).

### 2e. Keyboard layout

Today:

- `BrandScaffold` builds a `Scaffold` with the default
  `resizeToAvoidBottomInset: true` (`brand_scaffold.dart:169-183`), so the
  body already shrinks by the keyboard. Only `FloatingNavShell` turns it
  off (`floating_nav_shell.dart:151`), and the question screens are pushed
  above the shell.
- Body: `Column[Expanded(SingleChildScrollView(question)), TextField,
  SafeArea(footer)]`. The answer and footer are pinned above the keyboard
  by the resize; the question scrolls by itself.

Proposed structure (keeps that split):

```
Scaffold(resizeToAvoidBottomInset: true)      // as today, no extra inset
  QuestionHeader (title wraps, back, ×, counter)
  LayoutBuilder → available height H
    Column
      ConstrainedBox(maxHeight: qMax) → Scrollbar + SingleChildScrollView(question card)
      answer head ("Your answer" + Review answer / Read full question)
      ConstrainedBox(maxHeight: aMax) → TextField(multiline, minLines, maxLines: null,
                                              scrollController per ID)
      footer (Skip, Next/Submit) inside SafeArea(top: false)
```

- `qMax`: the question's measured height (`TextPainter` with the real
  width and `MediaQuery.textScalerOf`), capped so the answer keeps its
  minimum (2 lines + padding ≈ 76 pt, as in the mockup's `fit()`).
- `aMax = H − question − answer head − footer − gaps`, at least the
  minimum. With `maxLines: null` inside that box the field grows and then
  scrolls inside itself; caret-into-view only scrolls the field.
- When `H` cannot hold the minimums (small phone, long question, large
  text): the question box takes what is left and scrolls, the "Read full
  question" control replaces "Review answer" (it unfocuses so the keyboard
  closes), and a visible scroll hint is shown. No text is shrunk.
- `SafeArea(bottom)` only applies when the keyboard is closed: with the
  keyboard up, `MediaQuery.padding.bottom` is already zero, so no double
  inset.

Risks:

1. **Multiline `TextField` contains its own `Scrollable`.** The existing
   test "answer field has no scrollable ancestor"
   (`practice_screen_keyboard_test.dart:187-209`) checks ancestors, so it
   still holds as long as the page itself does not scroll. A
   whole-page scroll fallback for tiny heights would break it (and bring
   back the header-dragging bug it guards). Keep the fallback inside the
   question box.
2. **Measuring every keystroke.** Growing the field must not rebuild the
   question measurement per character; measure the question once per
   question/width/text scale.
3. **`GestureDetector(onTap: unfocus)` around everything** can compete
   with drag-scrolling inside the answer. Exclude the answer box.
4. **Real keyboard heights and the suggestion bar** differ per keyboard;
   the layout must read `MediaQuery` only. **Not measured on a device.**
5. Portrait only (`app_orientation.dart:12-13`, `Info.plist:60-63`), so
   "rotation" in the checklist does not apply.

Existing keyboard tests: `test/practice_screen_keyboard_test.dart`, 7
definitions, 13 cases (6 run on two devices, 375 × 667 and 430 × 932),
using `FakeViewPadding` for the keyboard. `DailyTestScreen` has **no**
keyboard test.

### 2f. Affected tests

36 test definitions in 5 files, by reading their names:

| File | Defs | Behaviour | Look | What breaks |
|---|---|---|---|---|
| `practice_screen_keyboard_test.dart` | 7 (13 cases) | 7 | 0 | Probably none if the structure above is kept; the autocorrect test breaks only if O4 changes |
| `daily_test_screen_test.dart` | 14 | 13 | 1 (dialog colours ×2) | None expected (load/error/Skip rules kept) |
| `question_app_bar_test.dart` | 5 | 1 (callbacks) | 4 (40 × 40, title centre, counter-only) | 40 → 44, the disabled Back, a new header |
| `practice_step_footer_test.dart` | 8 | 4 | 4 (52 tall, outlined Skip, widths, disabled colours) | 52 → 48 and Skip styling |
| `practice_screen_exit_dialog_test.dart` | 2 (4 cases) | 1 | 1 | None if the dialog copy is kept |

So about **26 behaviour** and **10 look** definitions. New tests needed
(none exist): wrapping/growth, Return inserts a newline, drafts with
selection across Next/Back/Next, disabled Back on question 1, "Review
answer" closes the keyboard and keeps text, double-submit guard, a
`DailyTestScreen` keyboard test, small-screen + long-question fallback.

---

## 3. Onboarding

### 3a. Today's flow and what two steps change

`FirstLaunchFlow` (`first_launch_flow.dart:63-180`) swaps plain widgets,
no routes: `welcome → onboarding → dailyTest → dailyTestResult`.

- `_completeOnboarding` (`:82-106`): seeds the bundled Day-0 set
  (`seedDayZeroSet`, skipped if a set already exists for the day,
  `daily_test_service.dart:113-121`), then saves the profile, then fires
  `onboarding_completed`, then goes to the Daily Test.
- Onboarding being complete **is** the profile row; there is no flag
  (`user_profile.dart:4-6`, `storage_service.dart:189-198`).
- Day-0 paywall: Home opens it once after the climb
  (`home_screen.dart:860-864`, `day0PaywallFlag`), only when
  `dayZeroCompleted` is true (`first_launch_flow.dart:138-144`).
- The climb animation is handed over as `pendingClimb` (`:117-130`).

**Recommendation: keep `_Step.onboarding` as one step and do the two
steps inside `OnboardingScreen`** (a local `_page` with an
`AnimatedSwitcher`, or a `PageView` without swipe). Then
`FirstLaunchFlow`, its 17 tests, the Day-0 seed, the climb, the Day-0
paywall and the time of `onboarding_completed` (end of step 2, after the
profile is saved) stay as they are. Back on step 2 returns to step 1 with
name, avatar and goal kept in the same `State`.

Gaps that two steps make visible:

- The system back gesture on step 2 must go to step 1, not leave the flow
  (today onboarding is not a pushed route, so a back gesture does nothing
  on iOS; on step 2 a `PopScope` is needed only if a route is involved —
  with the in-screen approach, an explicit Back button suffices).
- Leaving the app between steps: nothing is saved before the end (the
  brief allows "the existing persistence model"). Reopening shows Welcome
  again. Proposal: accept, as today.
- "First test already done today → no new free right": only reachable
  through the debug reset (`storage_service.dart:1531-1539` keeps the day's
  set). The existing set is reused and `completeDailyTest` is a no-op for
  a completed set, so no new step or right is created. Release builds
  cannot reach this (no profile ⇒ fresh install ⇒ empty database).
- Welcome (`welcome_screen.dart`) is not in the package. The mockup's step
  1 has its own brand line ("A little practice. Every day."); proposal:
  keep Welcome as it is and use the brand line only if the owner wants
  Welcome removed (open question O7).

### 3b. Optional name: where an empty name is assumed

| Place | Empty name today |
|---|---|
| `OnboardingScreen._canContinue` (`onboarding_screen.dart:49-50`) | Blocks Continue |
| `UserProfile.name` (`user_profile.dart:9`), column `name TEXT NOT NULL` (`storage_service.dart:194`) | Empty string allowed; null is not |
| Home greeting (`home_greeting.dart:35, 45, 69`) | Already handled: "Good evening" alone, VoiceOver reads the same |
| Profile identity card (`settings_screen.dart:991-998`) | Shows "Your name" over an **empty line** |
| Profile `_canSaveProfile` (`settings_screen.dart:313`) | **Blocks saving an empty name** |
| Mockup step 2 ("One more thing, {name}." / "One more thing, then we're off.") | New, handle both |

Other uses of the name: none (no analytics, no network; the AI consent
screen says it is never sent, `ai_consent_screen.dart:79-81`).

**Proposed rule:** a name is optional everywhere. Stored as `''` (trimmed;
no schema change), never shown as "null" or a placeholder name. Profile:
allow saving an empty name (clearing it), show "Add your name" as the
empty value. Length: today there is **no** limit anywhere; the mockup's 40
is "representative". Proposal: `maxLength: 40` in both places, with
`MaxLengthEnforcement.enforced` and no visible counter (open question O2).
Unicode is kept as typed (`textCapitalization.words` only affects the
keyboard).

### 3c. The goal

- Enum `LearningGoal { examPrep, work, general }`
  (`learning_goal.dart:4`), stored as `exam_prep` / `work` / `general` in
  `user_profile.learning_goal TEXT NOT NULL`.
- **Required today:** Continue is disabled without one (`:49-50`).
- Read by **nothing** after onboarding: `grep` finds `LearningGoal` only in
  `onboarding_screen.dart`, the model and the profile class. Its doc says
  "Feeds topic suggestions later" — never built. So the brief's statement
  is right: it personalises nothing.
- The mockup renames "General fluency" to "Everyday confidence" (map to
  `general`; the descriptions also change).

Storing "skipped":

- **No schema change needed.** Add a fourth stored value `skipped` (enum
  value `LearningGoal.skipped` or a nullable `LearningGoal?` mapped to
  `'skipped'`). The column stays `NOT NULL`.
- A real `NULL` would need a table rebuild (SQLite cannot drop `NOT NULL`
  with `ALTER TABLE`), at DB version 24 (today 23,
  `storage_service.dart:32`). Not worth it.
- Old builds: `LearningGoalInfo.fromJson` maps any unknown value to
  `general` (`learning_goal.dart:29-38`), so a downgrade reads `skipped`
  as `general` without crashing.
- Existing users: their `general` cannot be told apart from a deliberate
  choice; no migration can recover that. Leave as is.

### 3d. Does the goal reach analytics?

**No.** Evidence:

- `onboarding_completed` has no parameters
  (`analytics_service.dart:149-150`).
- The only user properties are `text_size` and `first_step_dom`
  (`:501-510`).
- `docs/analytics-plan.md` §4 lists the learning goal under "Never sent,
  in any event or user property".

And four places promise it stays local:

1. The live privacy policy: "Your name, your learning goal, your avatar
   and your entire practice history … stay on your phone" (fetched
   2026-10-05, last updated 22 September 2026).
2. The onboarding note: "Your name and goal stay on this device."
   (`onboarding_screen.dart:14-17`, pinned by `onboarding_screen_test`).
3. The AI consent screen, "What is never sent: Your name, your learning
   goal or your avatar." (`ai_consent_screen.dart:79-81`).
4. `analytics-plan.md` §4.

So the package's copy "Your answer helps us decide what to improve next"
and the sheet's "Your answer helps guide future improvements" describe a
data flow that does not exist.

Options (not implemented):

| Option | Change | Consequences |
|---|---|---|
| **A. Keep it local** | Copy only: e.g. "Choose what matters most to you." with no claim about improvement; the sheet says the goal stays on this device | No privacy, App Privacy or plan change. The audience question is not answered |
| **B. One user property** | `learning_goal` = `exam_prep` / `work` / `general` / `skipped` (closed enum, 13-char name, ≤ 9-char values; within the limits in `analytics-plan.md` §4) set once at onboarding completion, through a typed method plus a param-key test like the others | Must change, before release: the privacy policy's sentence; the onboarding note and its test; the AI consent screen's "never sent" line; `analytics-plan.md` §3 and §4; register a user-scoped custom dimension (not retroactive). **App Privacy:** a new kind of data collected through Firebase; the 1.0.0 answers are not in the repository (build log 2026-10-04 step 3), so the category (likely "Other User Content" or "Other Data", linked or not depending on the existing Firebase answers) has to be decided by the owner against the form. Existing installs do not report it unless set again at startup |
| C. One event parameter | `goal` on `onboarding_completed` | Same privacy work as B; only covers new installs; less useful for breakdowns than B |

Recommendation: A for this batch; B only as a separate, owner-approved
privacy change (open question O3).

### 3e. "Your data & AI"

Today's facts on screen:

- Onboarding note (`onboarding_screen.dart:14-17`): name and goal stay on
  the device; Topic Practice answers go to Anthropic (Claude), asked
  first; usage and crash data is collected.
- The AI consent screen (`ai_consent_screen.dart`) is shown by
  `ensureAiConsent` when Topic Practice launches
  (`practice_launch.dart:118`; push at `ai_consent_screen.dart:268-270`). It
  records `granted`/`declined` with `ai_consent_result`, and Profile → Data
  can change it.

The mockup sheet repeats those facts in four rows (On this device / Your
learning goal / AI feedback / App diagnostics) with "Got it". It is an
information sheet: "Got it" must not call `setAiConsent` or log
`ai_consent_result`, and the consent screen stays the only place where
consent is given. The goal row's text depends on §3d.

### 3f. The companion picker

`AvatarCarousel` can be reused:

- All 16 avatars by their IDs (`Avatar.count = 16`, `avatar.dart:37`;
  `Avatar.values`), looping both ways (`avatar_carousel.dart:14-20, 100,
  128`), haptic on settle, `onSettled` only on a change, selected state in
  semantics. The mockup's 3 heroes and "2 / 3" caption are samples; the
  caption would read "N / 16".
- Size: `centerRadius` and `viewportFraction` are already parameters
  (`:75-76`). `_neighborScale` (0.8) and `_neighborOpacity` (0.5) are
  `static const` (`:90-91`); the mockup's 0.72 / 0.48 need two new
  optional parameters (defaults unchanged, so Profile's picker does not
  move).
- The mockup's tile is 150 × 165 (a portrait image box); `AvatarTile` is
  round, by `radius`. Proposal: radius 75 and keep the round tile, unless
  the owner wants the taller frame.
- Selection animation: the brief's 220 ms ease-out vs the carousel's
  settle; reduce motion is not checked by the carousel today (**not
  measured**).

---

## 4. Paywall

### 4a. Mockup vs `PremiumScreen`, section by section

| Section | Today | Mockup |
|---|---|---|
| Top | App bar "Premium" + close `IconButton` (`premium_screen.dart:287-298`) | Small "GrammarLens" brand + 44 × 44 close |
| Hero | 5 avatars (3 under 340 pt), user's in the middle, radius 38 / 26 / 21, height 90; hidden under 700 pt tall (`:428-509, 534`) | 3 avatars, middle 124 wide, sides ~66 |
| Title | "Unlock personalized feedback" (`:317`), `titleLarge` | "PREMIUM" label, "Turn your mistakes into progress." 28/900, support line |
| Support | "Practice the mistakes you actually make." or "Practice {weak spot}." (`:240-244`) | "Focused practice. Personal feedback. A little more confidence, every day." The `sourceContext` line has no place in the mockup (keep it as the support line) |
| Benefits | None (the table carries them) | Three benefits in one card |
| Comparison | Always-visible table, 4 rows, table or stacked by measurement (`:770-795, 842-1115`) | "Compare Free & Premium" expandable table, 4 rows |
| Plans | Side by side; annual shows **per month** big, total small (`:1650-1689`) | Stacked radios; annual **total** big |
| Code | None | "Have a code?" |
| Footer | Status banner, CTA "Start free trial" / "Continue", one-sentence disclosure, legal links (moved into the body when height ÷ text scale < 400, `:538`), "Maybe later"; fixed, top border (`:594-730`) | CTA, two-line disclosure, Restore, Terms, Privacy, Maybe later |
| Restore | In the scrolling body (`:367-376`) | In the footer |

Rules that must survive (where they live today):

- **Price and trial only from the store:** `Package.storeProduct` via
  RevenueCat (`_loadOffer`, `:134-142`); the debug fixture is debug-only
  (`subscription_service.dart:334, 345`). Mockup prices ($49.99, $5.99,
  "SAVE 30%", "7-day") are samples.
- **Per-plan trial (annual 1 week, monthly 3 days)** comes from the store
  (build log 2026-09-17). The mockup's "Continue with Monthly" with no
  trial contradicts the real monthly 3-day trial; follow the store.
- **Existing defect, to fix in the paywall batch:**
  - `_disclosureText` says "Free trial" when the product has no
    introductory price (`:519-521`), and the CTA is always "Start free
    trial" (`:694`).
  - Eligibility is never checked: `introductoryPrice` is the product's
    offer, not this user's eligibility. RevenueCat's own doc on
    `checkTrialOrIntroductoryPriceEligibility`
    (`purchases_flutter.dart:825-838`): on unknown eligibility, show the
    non-intro price. The build log (2026-09-17) records that a user who
    used the monthly trial gets no annual trial.
  - Proposal: check eligibility per product on load; show trial wording
    only when `eligible`; otherwise "Subscribe", "{price} / {period},
    auto-renews unless cancelled".
- **Renewal text** with the selected plan; **Terms and Privacy** always
  visible; the small-screen footer rule (`:534-538`) and its 9 tests
  (`premium_screen_test`, the 375 × 667 / 320 × 568 / 3x cases).
- **No "unlimited":** the table's premium column is a check mark; keep it
  so. Premium has a cap of **5** sessions a day (§6).
- **Restore** always reachable (test "Restore Purchases is always
  reachable").
- **Sources:** `home`, `weak_spot_quota`, `review_quota`,
  `practice_launch`, `practice_result`, `day0_after_climb`
  (`analytics_service.dart:266-278`); dismiss methods `close_button`,
  `maybe_later`, `system_back` (`:287-289`). Five call sites
  (`review_screen.dart:200`, `practice_launch.dart:78`,
  `results_screen.dart:84`, `home_screen.dart:1079`,
  `weak_spot_detail_screen.dart:132`). The expandable table and the code
  link add no event in this plan.
- **Day-0:** unchanged (Home pushes the same screen with
  `day0_after_climb`).
- Already premium: the screen does not check entitlement on open; entry
  points only reach it as free users. After a purchase, "Continue"
  replaces the CTA (`:686-695`). Keep.

### 4b. The companion group

Today: centre = the profile's avatar (`_loadAvatar`, `:144-154`), or a
random fallback for a legacy null avatar; sides from fixed offsets 2, 4,
6, 8 around `Avatar.values` (`_otherAvatarsFor`, `:428-434`), so the same
user sees the same group. For the mockup: centre = the user's avatar at
124 wide, sides = offsets 2 and 4 (or the carousel neighbours ±1), 66
wide. No new data. Five tests pin today's five-avatar group and will be
rewritten.

### 4c. Benefit copy against real entitlements

Real rights:

- Free: Daily Test; one weak-spot practice a day
  (`freeDailyPracticeLimit = 1`, `storage_service.dart:62`), forced to the
  shortest length (`practice_launch.dart:136-145`); that practice is
  scored by the AI, so **free users do get AI feedback**.
- Premium: Topic Practice on all 5 topics (`topic.dart:3-9`), 3/5/10
  questions, up to 5 sessions a day.

| Mockup line | Verdict |
|---|---|
| "Understand your mistakes — AI feedback explains what to improve." (as a Premium benefit) | **Misleading:** implies AI feedback is premium-only. The brief itself forbids that. Proposal: "More AI feedback — on every topic, not just one practice a day" |
| "Practice your weak spots — Go beyond your one free daily practice." | Correct |
| "Every topic, your own pace — All 5 topics · 3, 5 or 10 questions." | Correct (5 topics; lengths from `PracticeLength`) |
| Table: Daily Test Yes/Yes; Topic Practice —/All topics; Weak spot 1 a day/Included; 3, 5 or 10 —/Yes | Correct. Keep the free value read from the constant, as today (`:775-790`) |
| "Personal feedback" (support line) | Acceptable (free has it too, but the line does not say it is premium-only) |
| `_PurchaseStatusBanner`: "Trial started — Topic Practice is unlocked." (`:1864`) | Correct today; wrong for a non-trial purchase once eligibility is handled |

### 4d. "Maybe later" and close

`_dismiss` (`:227-238`): marks the exit handled, logs `paywall_dismissed`
with the method, calls `onDone` (null at every call site today), then
`Navigator.pop()`. System back is logged by `PopScope` (`:280-286`). The
mockup's "Maybe later" and × map to the same two methods; nothing new.

---

## 5. Redeem code (research only)

Owner decision restated: no client-side code check and no code list in the
app (App Review 3.1.1). The only candidate is Apple subscription offer
codes.

### 5a. Does `purchases_flutter` open Apple's sheet?

Yes.

- Version: `purchases_flutter` **10.10.1** (`pubspec.lock:437-444`;
  `pubspec.yaml:20` `^10.10.1`).
- API: `static Future<void> Purchases.presentCodeRedemptionSheet()`,
  "iOS only. Presents a code redemption sheet, useful for redeeming offer
  codes" (`purchases_flutter.dart:869-873`).
- Native: `PurchasesFlutterPlugin.m:505-515` calls
  `[RCCommonFunctionality presentCodeRedemptionSheet]` on iOS 14+ and
  then `result(nil)` at once. The app's deployment target is 15.0
  (`project.pbxproj:386, 516`).
- It must go through `SubscriptionService` behind the `_configured` check:
  any `Purchases.*` call before `configure` is a native `fatalError`
  (`subscription_service.dart:23-33`).

### 5b. The App Store redeem URL

`https://apps.apple.com/redeem?ctx=offercodes&id={apple_app_id}&code={code}`

- For: works for one-time and custom codes; can carry a code (from an
  email or a link); no SDK dependency.
- Against: leaves the app for the App Store; the Apple app ID is not in
  the repository (no match in `lib/` or `config/`), so it must be added;
  the user comes back by hand; we still learn nothing about the result.
- Apple's page says one-time-use code URLs are built by copying the
  example link from the offer page and appending the code.

### 5c. How the entitlement reaches the app

- A redeemed code is a StoreKit transaction for the subscription. The
  RevenueCat SDK observes transactions and updates `CustomerInfo`;
  `addCustomerInfoUpdateListener` fires.
- Today Home (`home_screen.dart:335`) and Review (`review_screen.dart:79`)
  listen via `SubscriptionService.addAccessListener`; Settings and weak
  spot detail read once. **`PremiumScreen` does not listen**, so after a
  redemption it would still show the purchase button. It needs a listener
  that switches to the success state.
- A code redeemed outside the app (URL) arrives when the app next syncs
  (foreground/launch). **Not measured**; to verify with a sandbox code.

### 5d. Which modal states can be shown

| Mockup state | With Apple's sheet |
|---|---|
| Empty code → button disabled | Apple's UI |
| Checking / loading | Apple's UI |
| Invalid, expired, used, not eligible | Apple's UI; the app gets no result |
| Network error | Apple's UI |
| Discount valid: plan, price, length, renewal shown before confirming | Apple's UI (Apple's confirmation sheet) |
| Free access valid | Apple's UI |
| Cancel/close keeps the plan selection | **App** (the sheet is over the paywall; selection is in `State`) |
| "Premium is active" after success | **App**, via the entitlement listener (5c) |

The app can show none of the error or offer-detail states: the call
returns `void` immediately (`result(nil)`), with no success or failure.

### 5e. Proposed UI

| | Option 1: link → Apple's sheet | Option 2: our small sheet → App Store URL |
|---|---|---|
| "Have a code?" opens | `presentCodeRedemptionSheet()` directly (optionally a one-line note first: "Codes are redeemed with Apple") | A sheet with "Your code" and "Redeem in the App Store", which opens the URL with the code |
| App Review risk | Low: Apple's documented mechanism | Higher: an in-app code field can read as an own unlock mechanism even though Apple validates; needs the copy to say the App Store checks it |
| Reliability | Depends on Apple's sheet; no result | Leaves the app; needs the app ID; no result |
| Mockup states | Only the entry and the "active" result | Only empty/disabled; everything else in the App Store |

**Recommendation: Option 1.** The mockup's code field, "Check code" and
error states are not built; the brief's own rule ("do not present an
unconnected code flow as working") then holds.

### 5f. What the owner does in App Store Connect

From Apple's "Set up offer codes" page (fetched 2026-10-05):

1. Apps → GrammarLens → Subscriptions → the group → a subscription →
   "Create Offer Codes" (role: Account Holder, Admin, App Manager or
   Marketing).
2. Reference name; **auto-renewal choice**: renew to the standard price
   at the end, or "prevent auto-renewal" for a commitment-free period (then
   only a free offer is possible). This answers the brief's "do not turn
   free access into a paid renewal": choose "prevent auto-renewal" for
   free-access codes.
3. Eligibility: new, existing, and/or expired subscribers of the group;
   whether a code can be combined with the introductory offer.
4. Countries; offer type (free, pay as you go, pay up front); duration.
5. Codes: one-time use (500–25,000 per batch, expire within six months) or
   custom (named, e.g. a campaign word). Up to 10 active offers per
   subscription; an offer cannot be edited after creation.

Testability while 1.0.0 is in review:

- Customers can redeem only when the app is **"Ready for Sale"**. Both
  subscriptions are "Waiting for Review" (roadmap line 10), so no real
  redemption is possible yet.
- **Sandbox offer codes** (10–10,000, up to six months) can be redeemed
  through the Sandbox Account settings on iOS 16.3+. So the flow can be
  tested on a device with a sandbox account before approval. Whether the
  offer codes themselves can be created while the subscriptions are still
  in review is **not verified**.

---

## 6. Where the brief or prompt conflicts with existing decisions

| # | Brief / prompt | Fact | Proposal |
|---|---|---|---|
| C1 | Android items (Android keyboard, TalkBack, Android checks) | iOS only, no Android release track (roadmap line 1906) | Out of scope; mark N/A |
| C2 | Device rotation | Portrait only (`app_orientation.dart:12-13`, `Info.plist:60-63`) | N/A |
| C3 | Mockup prices, "SAVE 30%", 7-day trial | From the store; the savings badge is computed (`premium_screen.dart:1674-1680`) | Samples only |
| C4 | Monthly plan without a trial | Monthly has a 3-day trial in ASC (build log 2026-09-17) | Follow the store |
| C5 | Prompt: "premium 10 sessions a day" | `dailySessionLimit = 5` (`storage_service.dart:49`; roadmap line 653) | Keep 5; correct the prompt's figure. The paywall states no number either way |
| C6 | "Topic Practice premium" | True for the Topic Practice entry (Home locks it); a free user's one weak-spot practice uses the same generator and the AI | Consistent, as long as AI feedback is not called premium-only (§4c) |
| C7 | Goal copy "helps us decide what to improve" | The goal is never sent (§3d) | Option A copy unless B is approved |
| C8 | Autocorrect: "normal platform behaviour" | Off on purpose, two tests | Keep off (O4) |
| C9 | Exit dialog copy in the mockup | Today's says progress is lost | Keep today's |
| C10 | "Rewrite" type label | No such type | Keep the three real labels |
| C11 | Name `maxlength` 40 "representative" | No limit today | O2 |
| C12 | Daily Test last button "Submit" | "Finish" today | O5 |
| C13 | Code modal states | Not possible with Apple's sheet (§5d) | Option 1 |
| C14 | Question V2 replaces 1.2.0 Q11/Q12 | Q11/Q12 were left open (build log 2026-10-05) | Superseded by §2c/§2d |
| C15 | Very long answers "supported" | The proxy rejects a `userAnswer` over 2,000 characters with 400 (`proxy/src/validation.ts:6, 122`): Topic Practice would show "Could not score answers" | `maxLength: 2000` on Topic Practice only, counter shown near the limit (O6). Daily Test is graded locally, no limit |

---

## 7. ACCEPTANCE-CHECKLIST classification

T = testable with widget/unit tests; D = device only; N/A = cannot apply
(with why); T+D = both.

**Question V2**

| Item | Class |
|---|---|
| Real system keyboard; no mock keyboard | T (no custom keyboard widget) + D |
| Rewrite answer wraps, no horizontal scroll | T |
| Starts at 2 lines, grows, shrinks | T |
| Long answer scrolls inside after the limit; question and actions stay | T (`FakeViewPadding`) + D |
| Select/correct the first word, copy/paste, edit in the middle | D (selection handles, context menu) |
| Return adds a line, does not submit; IME composing intact | T for Return; D for IME (Turkish/Japanese keyboards) |
| Short/medium question fully visible with a standard keyboard | T at fixed insets + D |
| Small screen + long question: readable, scrollable, "Read full question", no overflow | T |
| Done/Review answer closes the keyboard, keeps the answer | T |
| Next → Back → Next keeps all answers by ID | T |
| Back disabled on question 1, never leaves the session | T |
| × separate, keeps the confirmation | T (existing) |
| Empty, whitespace, very long, line breaks, emoji | T (and C15) |
| Skip, Submit on the last, session lengths | T (existing) |
| No extra AI request, points or quota from navigation | T (fake `ClaudeService`) |
| Loading/failure: no double submit, text kept | T |
| Suggestion bar, keyboard heights, rotation, large text | Large text and heights: T + D; suggestion bar: D; rotation: **N/A** (portrait only) |
| Android parts of "iOS and Android" | **N/A** (iOS only) |

**Onboarding**

| Item | Class |
|---|---|
| All heroes swipeable, centre grows, ID saved | T (existing carousel tests) |
| Empty name → Continue works; nameless greeting; Unicode kept | T |
| Name keyboard: field and Continue reachable | T + D |
| Back between steps keeps name/hero/goal | T |
| No default goal; skipping stored separately | T |
| No personalisation promise | T (copy test) |
| Research data flow checked; privacy text matches | Reviewed here (§3d); copy: T |
| No new telemetry provider, no name/answer sent | T (recording sink) |
| AI sheet does not replace consent | T |
| Completion and reopen records correct | T (existing `first_launch_flow_test`) |
| Test already done: no new right or session | T |

**Paywall**

| Item | Class |
|---|---|
| User's hero always centred | T |
| Free weak-spot right and real premium benefits | T (copy) |
| Plan change updates price, period, CTA, renewal together | T |
| Price, currency, eligibility from the store; nothing hardcoded | T with fixtures + D (sandbox) |
| Success/cancel/error/pending and restore with the real service | T with fakes; real: D (sandbox). "Pending" (Ask to Buy) has no state today: `PurchaseOutcome` has `success/failure/cancelled` only (`subscription_service.dart:10`) |
| Terms/Privacy open real pages; close and Maybe later return | T (existing) + D for the pages |
| Code modal usable with keyboard; background blocked | **N/A with Option 1** (Apple's sheet) |
| Empty/loading/invalid/expired/used/ineligible/network states | **N/A** (§5d) |
| Real validation source decided; no fake client validation | Decided by the owner (§5) |
| Offer terms and free period shown before confirming | Apple's sheet: D (sandbox) |
| Closing the code modal keeps the plan | T |

**Shared**

| Item | Class |
|---|---|
| Light/dark, system theme change, real Nunito Sans weights | T for colours; weights: D (the iOS weight bug, roadmap line 120-131, was only visible on a device) |
| 320/360/390/430 widths, large text, long strings | T |
| 44 / 48 targets | T |
| VoiceOver order, labels, disabled/loading | T (semantics) + D |
| Modal focus trap, escape, focus return | T; on iOS there is no Escape key: N/A for that part |
| Reduce motion, slow network, missing assets/products | T |
| Preview selectors, fake status bar, sample messages absent | T (nothing to port) |

---

## 8. Proposed batch plan

Order from the brief: Question V2 → Onboarding → Paywall. Each batch ends
with `flutter analyze` and the full suite green, a build-log entry and a
device check by the owner.

### Batch 10 — Question V2 (both screens)

- **Files:** `practice_screen.dart`, `daily_test_screen.dart`,
  `question_app_bar.dart`, `practice_step_footer.dart`; a new shared
  `question_layout.dart` widget (the two screens' bodies are already
  identical apart from load/error states, so one widget instead of two
  copies); the `AdditionalScreenTokens` extension in `theme.dart` (§1.2).
- **Behaviour:** B1–B5, the double-submit guards, `maxLength` on Topic
  Practice (if O6). Drafts: add a `ScrollController` and one `FocusNode`
  per screen.
- **Schema / analytics:** none.
- **Tests:** ~10 look definitions updated (§2f); new: wrap/grow, Return,
  draft round trip with selection, disabled Back, Review answer, double
  submit, Daily Test keyboard, small screen + long question.
- **Device:** a real keyboard on the owner's iPhone 14 Plus and a small
  phone (SE simulator): a 3-line correction answer, selecting the first
  word, paste, the Turkish keyboard, the suggestion bar, Large text.

### Batch 11 — Onboarding, two steps

- **Files:** `onboarding_screen.dart` (two in-screen steps),
  `learning_goal.dart` (`skipped`, new label/description),
  `avatar_carousel.dart` (two optional parameters),
  `settings_screen.dart` (empty name allowed, empty display),
  `user_profile.dart` (no change if `skipped` is an enum value).
  `first_launch_flow.dart`: none.
- **Schema:** no version bump (a new stored string value).
- **Analytics:** none under option A. Option B is its own batch with the
  privacy changes listed in §3d.
- **Tests:** `onboarding_screen_test` (5; the privacy-note test rewritten
  to the new copy), the form helpers in `first_launch_flow_test`,
  `first_launch_climb_test` and `widget_test` (they type a name and tap
  "Exam prep" then "Continue": add the step-2 tap); new: empty name,
  skipped goal stored as `skipped`, Back keeps values, the info sheet does
  not touch consent; Profile empty name.
- **Device:** name keyboard with Continue visible on an SE-size phone,
  carousel feel at the new size, VoiceOver through both steps.

### Batch 12 — Paywall

- **Files:** `premium_screen.dart` (layout: hero, title, benefit card,
  expandable comparison, stacked plans, footer), `subscription_service.dart`
  (eligibility check, `presentCodeRedemptionSheet` behind `_configured`,
  optional `pending`), `analytics_service.dart` none.
- **Behaviour:** B10, B11, the eligibility fix (§4a), the access listener
  on the paywall (§5c).
- **Schema / analytics:** none (no new event; sources unchanged).
- **Tests:** of 67 definitions, about 32 are look/geometry (the five-avatar
  hero, the side-by-side cards, the always-visible table, the footer
  geometry) and get rewritten; about 35 behaviour tests should pass
  unchanged or with new finders. New: eligibility (eligible, ineligible,
  unknown → no trial wording), plan switch updates CTA + disclosure, code
  link calls the service once, the listener closes into success.
- **Device:** sandbox purchase per plan with an eligible and an ineligible
  sandbox account, restore, a sandbox offer code (iOS 16.3+), 375 × 667 at
  Large text with the footer rule. Flags App Store screenshots that show
  the paywall for a pre-release check.

---

## 9. Open questions

Each with one recommendation.

- **O1. Screen-scoped `muted`/`info` overrides.** Recommendation: drop
  them and use the current tokens. Why: the light `info` fill is 1.00:1
  against the page, so it does nothing visible, and `muted` differs by a
  shade; one source of truth beats two near-identical greys.
  (`warm`/`onWarm` are new and are added.)
- **O2. Name length.** Recommendation: 40 characters in onboarding and
  Profile, no counter. Why: there is no limit today, the greeting already
  wraps long names, and 40 matches the mockup.
- **O3. Goal data.** Recommendation: option A (stays on the device, copy
  without the "helps us improve" claim) for 1.2.0. Why: option B
  contradicts the live privacy policy and three on-screen texts, and
  changes the App Privacy answers; that is a separate decision, not a
  side effect of a redesign.
- **O4. Autocorrect on the answer.** Recommendation: keep it off. Why:
  grading measures what the learner typed; turning it on lets the keyboard
  fix the very mistake being tested. The brief's "normal behaviour" still
  holds for Return, composing and selection.
- **O5. Daily Test's last button.** Recommendation: keep "Finish". Why:
  Daily Test has no submit-time request (local grading), and "Finish"
  is pinned by `daily_test_screen_test`; Topic Practice keeps "Submit".
- **O6. Very long Topic Practice answers.** Recommendation: `maxLength:
  2000` with the counter shown only past 1,800. Why: the proxy rejects
  longer ones and the user would lose the session to an error; no answer
  in practice approaches it.
- **O7. Welcome.** Recommendation: keep Welcome as it is and start the
  two steps after it. Why: it is outside the package, carries the launch
  hand-off (`welcome_after_splash_test`), and the mockup's brand line fits
  as step 1's eyebrow.
- **O8. Redeem code.** Recommendation: Option 1, "Have a code?" opens
  Apple's sheet; no code field of our own; the paywall listens for the
  entitlement. Why: lowest review risk, and the app cannot show the
  mockup's states either way.
- **O9. Free-access codes.** Recommendation: create them with "prevent
  auto-renewal". Why: it is the only way to honour the brief's "do not turn
  free access into a paid renewal".
- **O10. Pending purchases (Ask to Buy).** Recommendation: add a
  `pending` outcome with its own message in the paywall batch. Why: the
  checklist asks for it and today a deferred purchase reads as "failed".
- **O11. Paywall hero.** Recommendation: 3 avatars (user's centre,
  offsets 2 and 4). Why: the mockup's layout, deterministic as today.
- **O12. Fill-in-the-blank minimum lines.** Recommendation: 1 line,
  growing, wrapping. Why: answers are at most 12 characters in the pool;
  an empty two-line box invites a sentence where a word is wanted.
