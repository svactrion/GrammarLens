# Build Log

Chronological record of what happened after [`prd.md`](prd.md), during MVP
build-out. Two records merged into one timeline: engineering work done in
this Claude Code session, and product decisions made in a separate advisory
Claude session Ahmet uses for product calls — each entry is tagged
`[Engineering]` or `[Product]`.

## 2026-07-20

- **[Product]** Model choice: Opus → Sonnet, decided right after the initial
  scaffold proposal, before the first commit. Practice-item generation and
  scoring don't need Opus-level capability; Sonnet is materially cheaper and
  faster, and per-session cost matters for an LLM-native product.
- **[Engineering]** Scaffolded the app and integrated the Claude API
  (Sonnet) for practice-set generation and answer scoring — first running
  build.

## 2026-07-21

- **[Engineering]** Fixed CORS: browser calls to the Anthropic API were
  blocked. Added the `anthropic-dangerous-direct-browser-access` header —
  web-prototype-only, not needed for mobile builds.
- **[Engineering]** Fixed a 401 "invalid API key" error right after the CORS
  fix — `flutter run` had been restarted without `--dart-define`, so the key
  never reached the build. Fixed by exporting the key in the shell and
  passing it explicitly.
- **[Engineering]** Fixed the Review tab hanging on a loading spinner
  forever: `sqflite` has no web driver, so every DB read/write threw
  silently on web, and the `FutureBuilder` only checked `snapshot.hasData` —
  never `hasError` — so it never left the spinner. Added
  `sqflite_common_ffi_web` with a `kIsWeb` factory switch, and gave Review
  proper empty / error / retry states.
- **[Engineering]** That fix introduced a follow-on crash:
  `setState(() => _weakSpots = future)`'s arrow body returns the value of
  its expression — the assignment's value, i.e. the `Future` itself — which
  Flutter's `setState` rejects at runtime ("callback argument returned a
  Future"). Fixed with a block body. Also noticed Home and Review each had
  their own copy of "generate → navigate → handle errors"; unified both into
  one shared helper so this class of bug can't diverge between the two
  paths again.
- **[Product]** UX finding from testing: tapping a weak spot jumps straight
  into freshly generated practice questions, but the expected flow was to
  first see a summary of the past mistakes being targeted. Decision: add an
  error-summary screen before targeted practice — **P0 for Iteration 1**.

## 2026-07-24

- **[Engineering]** Iteration 2 shipped, driven by the four interview
  findings in [`prd.md`](prd.md) §2.1: question mix rebalanced toward
  production (2 sentence-writing, 2 error-correction, 1 fill-in-blank per
  set); feedback and Review now lead with a plain-language explanation and
  demote the rule name to a secondary caption; Review shows prominent
  count/recency stats ("N times · last seen ...") with a Recent/Most
  frequent sort persisted locally; Results shows the user's own answer next
  to the correction; and practice items render `context` and `instruction`
  as two distinct blocks instead of one paragraph.
- **[Product]** Skipped ≠ wrong. Found during my own testing of the app: an
  unanswered item was being scored red/incorrect and counted against the
  score, and the model's `errorType` for a blank answer varies every run
  ("You left this one blank", "Nothing was written here", ...), so matching
  against it to detect skips was unreliable. Decision: detect "skipped"
  deterministically in our own code from the raw answer text
  (empty/whitespace), never from the model's output — skipped items get a
  neutral color, are excluded from the correct/incorrect count, and are
  never written to the error profile.
- **[Product]** Error-correction items are graded on the grammar fix, not
  on format. Found during my own testing: writing just the corrected
  word/phrase instead of rewriting the full sentence was marked wrong even
  when the grammar fix itself was right. Decision: mark it correct if the
  target mistake is genuinely fixed, regardless of whether the full
  sentence was rewritten, with a short explanation note encouraging the
  full-sentence habit — only mark it "Needs work" when the grammatical
  correction itself is wrong, incomplete, or introduces a new mistake.
- **[Product]** Context and instruction are separate fields, not one
  string. Found during my own testing: the scenario setup and the actual
  task ran together as one long paragraph, making items look longer and
  more intimidating than they are. Decision: have generation return
  `context` and `instruction` as separate JSON fields so the UI can render
  them as two visually distinct blocks (plain-text context, then a bold
  instruction line).
