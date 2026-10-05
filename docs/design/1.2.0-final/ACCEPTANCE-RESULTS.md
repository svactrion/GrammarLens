# 1.2.0 final screens — acceptance results (2026-10-06)

`ACCEPTANCE-CHECKLIST.md`, item by item. **Test** = an automated test in
`test/` (named); **Sweep** = the real-font sweep in
`tool/design_measure/v120/final_screens_render_test.dart`; **Device** =
waiting for the owner's device check; **N/A** = does not apply.

| # | Item | Result |
|---|---|---|
| 1 | Free available and used kept; no Suggested Focus | Test (`review_suggested_focus_test`: visibility; `review_screen_test` unchanged) |
| 2 | Premium shows Suggested Focus, not tied to the free allowance | Test (visibility, "Premium: the suggestion, never tied…") |
| 3 | 1/2/1 → second; 1/2/3 → third | Test (`suggested_focus_test`) |
| 4 | Count tie → newest last seen; all equal → stable id | Test (`suggested_focus_test`) |
| 5 | The list's sort does not change the choice | Test (both files) |
| 6 | No stale suggestion after a reset, count change or deletion | Test (`suggested_focus_test`; Review re-reads on every reload: `review_suggested_focus_test`) |
| 7 | Missing/invalid count and date handled, no fake numbers | Test (count < 1 never chosen; dates before 2000 rank as unknown) |
| 8 | The CTA enters the existing flow with the chosen record | Test (opens that weak spot's own screen) |
| 9 | The AI permission and practice checks are not skipped | Test (its "Practice this" shows the permission screen) |
| 10 | Premium and Free top card bounds equal; the list does not move | Test for **Free available vs Premium** at 320/360/390/430 pt × three text sizes. **Free used is taller and differs** (owner's choice, 2026-10-06) |
| 11 | 320–430 pt and text scales 1.0/1.3/2.0: nothing cut | Sweep: no layout exception; the only ellipsis is the list card's intended two-line excerpt |
| 12 | Empty, loading and error are distinct | Test (states group) |
| 13 | The Data switch shows the stored consent; no false "on" after a failed save | Test (`data_screen_test`, `data_screen_final_test`) |
| 14 | Reset cancel/back deletes nothing; only the existing scope on confirm | Test (cancel, outside tap, back); scope unchanged (`resetProgressData`) |
| 15 | A failed reset never looks like success; a double tap is one operation | Test (`data_screen_final_test`) |
| 16 | Name, goal and theme kept after a reset | By scope: `resetProgressData` deletes `error_entries` and `topic_practice_stats` only (unchanged code); existing test "Reset progress leaves the permission alone" |
| 17 | Credits: no hero, illustration or badge | Test (no `Image`, one card) |
| 18 | Work, author, adaptation, source and licence kept; both URLs correct | Test (`credits_screen_test`); opening in a real browser: Device |
| 19 | Light/dark, VoiceOver/TalkBack, back gesture, dialog focus | Light/dark: Test + renders. Back: Test (Data's back tile). VoiceOver and dialog focus: Device. TalkBack: N/A (iOS only) |
| 20 | Tests and lint pass; limits reported | `flutter analyze` clean; full suite green (counts in the build log) |
