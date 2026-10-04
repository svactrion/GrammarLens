# GrammarLens — development

How to run, configure and check the app locally. Moved here from the
README on 2026-10-04; the text is unchanged.

## Local setup

The Anthropic API key is not in the client at all — the app talks to a
small Cloudflare Workers proxy (`proxy/`) that holds it as a secret; see
`docs/build-log.md` for why (short version: a key compiled into a shipped
binary via `--dart-define` is extractable, so it moved behind a backend
that owns the model/prompt/schema for every call and enforces its own
quota). The app only needs two build-time values (`AppConfig` in
`lib/config/app_config.dart`): where the proxy is, and an app token: without
them, Daily Test and Topic Practice fail with a `ClaudeApiException`
telling you to do the below.

1. Copy `config/dev.example.json` to `config/dev.json`:
   ```json
   { "PROXY_BASE_URL": "http://localhost:8787", "APP_TOKEN": "..." }
   ```
   `APP_TOKEN` here just has to match whatever you put in the proxy's own
   `proxy/.dev.vars` (see `proxy/README.md`) — pick any string for local
   dev. `config/dev.json` is gitignored — it never gets committed.
2. Run it: `./scripts/dev.sh` — starts the proxy locally (`wrangler dev`,
   in the background, only if nothing's already listening on its port)
   and then runs `flutter run --dart-define-from-file=config/dev.json`, so
   one command brings up both halves. Any extra arguments (e.g.
   `-d chrome`) pass straight through to `flutter run`. First time only:
   copy `proxy/.dev.vars.example` to `proxy/.dev.vars` and fill in a real
   Anthropic API key (see `proxy/README.md`) — that's the only place a
   real key needs to exist on a dev machine.
   - **Testing against the live proxy instead of `wrangler dev`**: the
     proxy also lives at the permanent `https://api.ahmettayfur.com`
     (Cloudflare Workers custom domain — see `proxy/wrangler.jsonc`).
     Temporarily set `config/dev.json`'s `PROXY_BASE_URL` to that and
     `APP_TOKEN` to the real deployed secret (`config/prod.json`'s value,
     if you have it) — `./scripts/dev.sh` detects a non-localhost URL and
     skips starting a local proxy. Revert both back to `localhost:8787`
     and the local dev token afterward: every call against the live
     address spends a real Anthropic request and counts against
     production's daily quota, so this isn't the default for a reason.
   - **VS Code** users can use the "GrammarLens (dev)" launch config
     (`.vscode/launch.json`, committed) instead — same flag, wired to
     Run/Debug, but doesn't start the proxy for you; run `npm run dev` in
     `proxy/` yourself first. `scripts/dev.sh` is the primary path since
     day-to-day development on this project happens from the terminal.
   - **Physical device**: `scripts/dev.sh` is simulator-only —
     `config/dev.json`'s `PROXY_BASE_URL` points at `localhost`, which on a
     real device means the device itself, so every proxy call fails. Use
     `flutter run --dart-define-from-file=config/prod.json -d <device-id>`
     instead.
3. **Xcode**: hitting the Run button directly in Xcode does **not** pass
   any `--dart-define`/`--dart-define-from-file` flags — the app will
   build but every API call will fail with the missing-config error
   above. Launch from `scripts/dev.sh` or VS Code instead when you need
   it configured.
4. **Release / TestFlight builds** use a separate `config/prod.json`
   (copy `config/prod.example.json`, fill in the real deployed proxy URL
   and app token — see `proxy/README.md` for deploying it) and need the
   matching flag: `flutter build ipa
   --dart-define-from-file=config/prod.json`. Easy to forget since
   `flutter build ipa` alone still succeeds; the resulting build just
   fails the same missing-config check at runtime instead. The same
   class of mistake already happened once for a plain `flutter run`
   (`docs/build-log.md`, 2026-07-21, "Fixed a 401 'invalid API key'
   error") — worth spelling out explicitly here so it doesn't repeat for
   a release build.
5. **Run `./scripts/preflight.sh` before every `flutter build ipa`** (so
   before every TestFlight or App Store build). It checks that pre-launch
   requirements which are easy to forget mid-build — `AppLinks`' Privacy
   Policy/Terms URLs, `config/prod.json`'s proxy URL/app token, and the
   Daily Test fallback pool's 7 sets (`assets/daily_test_fallback/pool.json`)
   — are actually set, and exits non-zero naming exactly what's missing if
   not.
   It also deletes any macOS `.DS_Store` file under `assets/` and lists
   what it deleted: Flutter bundles every file in a registered asset
   folder, so these would otherwise ship inside the app. More checks land
   here over time rather than each as its own script.

### Monthly Climb debug defines

Compile-time switches for checking the Monthly Climb on a device without
waiting for a day or a month to pass. Pass them with `--dart-define` next
to the usual config, for example
`flutter run --dart-define-from-file=config/dev.json --dart-define=CLIMB_DEBUG_MONTH_CARD=summary_near`.
They are display-only and never change stored progress, the Daily Test or
`dayKey`.

| Define | Builds | What it does |
|---|---|---|
| `CLIMB_DEBUG_DAY=<n>` | debug | The scene shows step n of the month (avatar, passed-day dots, save points). The card's month and step chips keep the real numbers. |
| `CLIMB_DEBUG_THEME=<id>` | debug | The scene shows that theme (`green_slope`, `ember_peak`, `glacier_peak`, `red_canyon`) in any month. |
| `CLIMB_DEBUG_MONTH_CARD=<value>` | debug **and profile** | Replays the month transition card with sample data on every launch and hot restart, then the month-change zoom: `summary_gold`, `summary_none`, `summary_near` (Silver, the near-miss line), `fresh` (the fresh-start card), or `first_run` (no card, the first run's zoom). It never reads or writes the stored "seen" records and sends no analytics events. Works in profile builds so the zoom's frame times can be measured there. |
| `CLIMB_DEBUG_MONTH_CARD_EVENTS=true` | with the one above | Lets the replay send its `month_card_shown`, `month_card_dismissed` and `month_zoom_ended` events, for a DebugView check. Off by default: debug and profile builds write to the production Firebase project. Needs `ANALYTICS_DEBUG_EVENTS=true` as well (below). |

All three combine (for example a month card on Red Canyon, zooming to step
20). Release builds ignore every one of them.

### Analytics in debug and profile builds

Debug and profile builds send **no analytics** by default (roadmap P11):
none of the app's events or user properties, and Firebase's own automatic
events (`first_open`, `session_start`, ...) are switched off too, because
these builds write to the production Firebase project. Release builds
always send; the define does nothing there.

| Define | Builds | What it does |
|---|---|---|
| `ANALYTICS_DEBUG_EVENTS=true` | debug **and profile** | Turns analytics on for that build, for a DebugView check (`docs/analytics-plan.md` §6). |

For example, the profile build that `docs/analytics-plan.md` §6 installs
on a device:

```bash
flutter build ios --profile --dart-define-from-file=config/prod.json --dart-define=ANALYTICS_DEBUG_EVENTS=true
```

The rule lives in `AnalyticsGate` (`lib/services/analytics_service.dart`).
Crashlytics is not affected. A build without the define also leaves
Firebase's collection switch off on that device; the next build with the
define, or any release build, turns it back on.

The same settings can be changed while the app runs from **Settings →
Debug** (debug and profile builds; not in release): the scene's theme and
day, the milestones (celebrations, save point steps) and month cards
replayed on Home, and **Sample collection**, which fills Profile's medal
shelf with sample months (the Welcome badge, seven finished months across
the four themes, this month) for screenshots. None of these writes a
stored record or sends an event; "Reset local data" there is the one
action that deletes stored data.

### Visual previews (no build config needed)

`lib/preview/` holds standalone, debug-only entry points for checking a
feature's every visual state on a device without seeding real data or
waiting for something to happen (a month rollover, a finalized medal) —
each is its own `main()`, guarded by `if (!kDebugMode) throw
StateError(...)` so it can never run in a release build, and none of them
touch `StorageService` or the real `grammar_lens.db`. Unlike the app
itself, these need no `config/dev.json`/proxy setup at all.

- **Monthly Climb** (`lib/preview/monthly_climb_preview.dart`): the
  mountain/route/avatar visual, with sample-progress and month-length
  controls.
- **Monthly Medal** (`lib/preview/monthly_medal_preview.dart`): every
  medal state — In progress, each finalized tier, "No medal", and several
  finalized months at once — with in-preview dark-mode and Small/Medium/
  Large text-size toggles, so a device acceptance pass can check all of
  them without a real month ever rolling over.

Run either directly with `flutter run -t <path>`, or use
`./scripts/preview_monthly_medal.sh` for the medal one (thin wrapper, no
VS Code needed — day-to-day development on this project happens from the
terminal, same as `scripts/dev.sh`). On a physical iPhone: plug it in,
confirm it shows up with `flutter devices`, then
`./scripts/preview_monthly_medal.sh -d <device-id>` (any extra arguments
pass straight through to `flutter run`).
