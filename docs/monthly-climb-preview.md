# Monthly Climb — local preview workflow

Run all commands from the current checkout on branch `monthly-climb-v2`:

```bash
cd /Users/ahmet/GrammarLens
```

The separate simulator `GrammarLens Monthly Climb` uses iPhone 17 / iOS 26.5:
`3DAEEF38-6DCF-4C75-836C-E6242AE26DF6`. Keeping it separate avoids sharing
app data with the main checkout's iPhone 17 simulator. If it is shut down:

```bash
xcrun simctl boot 3DAEEF38-6DCF-4C75-836C-E6242AE26DF6
open -a Simulator
```

Select this device in Simulator's Window menu if another device is foreground.
Do not boot it again if it is already running. `flutter devices` lists IDs.

## Stage 1 visual preview

```bash
flutter run -d 3DAEEF38-6DCF-4C75-836C-E6242AE26DF6 \
  -t lib/preview/monthly_climb_preview.dart
```

No prod config, Firebase initialization, RevenueCat calls, Daily Test generation,
profile reads or progress writes are made by this entry point. Sample progress
starts at 8/30 with Koala. Controls switch light/dark, 28–31 days, all twelve
avatars, progress and reduced motion. The mountain scrolls independently;
the outer page scrolls to reveal controls on smaller screens. System reduced
motion is respected even when the preview toggle is off.

To start directly in dark mode, add `--dart-define=CLIMB_PREVIEW_DARK=true`.
The on-screen theme toggle works in either case.

The standalone entry point refuses release/profile mode. It is not connected
to production Home and does not imply that the Monthly Climb feature is shipped.

## Current application from this checkout

The branch now connects Home to persisted Monthly Climb progress. The standalone
preview above still uses sample data. Home reads the current calendar month and
selected avatar, refreshes after completion and resume, and offers a retry when
the progress read fails. Medal scoring and Profile collection remain pending.
In Home, drags over the mountain scroll the page; the mountain automatically
follows the pawn but does not accept separate manual scrolling. The compact
monthly counter is above the mountain. The standalone fixture retains manual
trail scrolling for visual inspection.

Quit the preview's Flutter process with `q`, then:

```bash
flutter run -d 3DAEEF38-6DCF-4C75-836C-E6242AE26DF6 \
  --dart-define-from-file=/Users/ahmet/GrammarLens/config/prod.json
```

The real prod config is gitignored. This command reads the existing config
from this checkout without copying, printing or editing its contents. It runs
the current branch's `lib/main.dart`. Unlike the fixture, the full application uses real configured
services. The dedicated simulator starts with its own app data.

Terminal keys: `r` hot reload; `R` hot restart; `q` quit. After Codex changes
code in this checkout, press `r` (or `R` for initialization changes). Native
changes or switching entry points require stopping and running again.

Both entry points use the same bundle ID. On one simulator they replace the
same app executable; they are not side-by-side app installations. Worktree
isolation protects source files, not simulator app data. Use the dedicated
Monthly Climb device and avoid simultaneous Flutter sessions targeting it.

## Known generic build failure

Stage 0's `flutter build ios --simulator --debug` requested arm64 and x86_64
together and failed in framework thinning on Flutter 3.44.6 / Xcode 27.0.
That result alone does not establish whether `flutter run -d <specific ID>`
works. The device-specific preview run succeeded on 2026-09-17, including a second
dark run, with light/dark screenshots inspected. This is the verified workflow.
The full production entry point was not launched in that Stage 1 batch.
On 2026-09-18, the current branch's production entry point built and launched
successfully on the dedicated simulator. Its data was at onboarding, so this
does not constitute an on-device Home/completion review. Home light/dark layout
was inspected separately using widget renders with controlled progress data.
No SDK patch, global toolchain upgrade or project architecture override is
part of this preview batch.
