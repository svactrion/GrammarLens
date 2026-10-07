# 1.2.0 visual assets

Made from the real app in the simulator with a made-up learner ("Sam",
the Fox, Glacier Peak), framed in the 1.0.0 / 1.1.0 style. No personal
data, status bar 9:41 with full signal and battery, every PNG RGB (no
alpha). How they are made: build log 2026-10-06 and 2026-10-07.

```bash
tool/screenshots/capture.sh
```

```bash
build/scene_art_venv/bin/python tool/screenshots/frame.py
```

```bash
build/scene_art_venv/bin/python tool/screenshots/assets.py
```

`capture.sh` takes about 45 minutes (`RUNS=free capture.sh iphone` for one
run); `frame.py` writes `store/`, `subscription-review/` and
`overview.jpg`; `assets.py` writes `readme/` and `case-study/` (it reads
the site repository's current case-study images for the 1.0.0 side of the
comparisons, read only).

## App Store Connect slots

Version 1.2.0, English (U.S.). Upload in this order (the first three
appear in search).

### iPhone 6.5" Display (1284 × 2778)

| Order | File | Caption on the image |
|---|---|---|
| 1 | `store/iphone/01-result.png` | Every answer explained |
| 2 | `store/iphone/02-home.png` | Climb a new mountain each month |
| 3 | `store/iphone/03-question.png` | A new test every day |
| 4 | `store/iphone/04-review.png` | Your weak spots, tracked |
| 5 | `store/iphone/05-weak-spot.png` | Practice what you got wrong |
| 6 | `store/iphone/06-review-premium.png` | Premium shows your next focus |
| 7 | `store/iphone/07-collection.png` | Collect every mountain |
| 8 | `store/iphone/08-goal.png` | Set your goal in a minute |

If an iPhone 6.9" set is already in App Store Connect, clear it (or
replace it): with no 6.9" set, App Store Connect scales the 6.5" set for
the larger iPhones; with an old one, they keep showing it.

### iPad 13" Display (2064 × 2752)

| Order | File | Caption on the image |
|---|---|---|
| 1 | `store/ipad/01-result.png` | Every answer explained |
| 2 | `store/ipad/02-home.png` | Climb a new mountain each month |
| 3 | `store/ipad/03-question.png` | A new test every day |
| 4 | `store/ipad/04-review.png` | Your weak spots, tracked |
| 5 | `store/ipad/05-collection.png` | Collect every mountain |

### Subscriptions, App Review screenshot (review only, not shown on the App Store)

| Subscription | Product ID | File |
|---|---|---|
| Annual, $49.99, 1-week free trial | `grammarlens_premium_annual` | `subscription-review/annual.png` (annual selected, "Start my 7-day free trial") |
| Monthly, $5.99, 3-day free trial | `grammarlens_premium_monthly` | `subscription-review/monthly.png` (monthly selected, "Start my 3-day free trial") |

1284 × 2778 (an accepted iPhone size), unframed. Taken with the debug
price fixture (the real prices and trial lengths, eligible). Before
uploading they were compared with the sandbox paywall on the owner's
iPhone (2026-10-07): the same prices, "≈ $4.17 per month", the struck
"$71.88" and the 7-day / 3-day trial lines.

## Other folders

- `readme/`: the GitHub README's hero (1800 × 1100) and four frames
  (600 × 1298).
- `case-study/`: for ahmettayfur.com, not copied there (the owner's step).
  - Same names and size as the site's current images (600 × 1298 webp,
    raw app screens): `daily-test-explanation`, `day0-1-test`,
    `day0-2-result` (now the Welcome celebration over the result),
    `day0-3-climb`, `day0-4-paywall`, `practice-offer-card` (now Review's
    "See Premium" once the free practice is used).
  - New: `onboarding-goal`, `home-glacier` (Home with the Halfway Hut
    label), `weak-spot-premium` ("Practice this").
  - Comparisons (1260 × 1398 webp, labelled):
    `compare-review-free-premium`, `compare-home-1.0.0-1.2.0`,
    `compare-paywall-1.0.0-1.2.0`. The 1.0.0 side is the site's own
    image; the owner's name on its Home is blurred.
  - `og-candidate.png` (1672 × 941, the size of the site's
    `grammarlens-og.png`): its subline approved by the owner (2026-10-07).
- `overview.jpg`: every store frame, reduced.
