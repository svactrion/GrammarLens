# medals

Composes the GrammarLens medals (Batch 5, decisions N1–N3 in
`docs/1.1.0-design-side-tracks.md`): 12 monthly medals (4 themes × 3
tiers) and the Welcome badge. The app never layers a medal at run time; it
picks one of these finished images. Nothing in `lib/` imports this tool,
and `flutter test` does not run it.

- **Monthly medal:** the tier's body (`medal-ranks/medal_<tier>.png`),
  the theme's mountain clipped to the body's inner well
  (`mountains/<theme>_mountain_medal.png`), a soft shadow and an inner rim
  shadow, then stars on the top rim: Gold 3, Silver 2, Bronze 1
  (`extras/sharp_star.png`).
- **Welcome badge:** the beige body, the stone mountain with the START
  flag, no stars, and the orange ribbon (`extras/ribbon_orange.png`) with
  "WELCOME" set along an arc in Poppins Bold (`extras/Poppins-Bold.ttf`,
  SIL Open Font License 1.1, copyright 2020 The Poppins Project Authors).

Sources: `docs/design/medals/source/` (1254 × 1254 px PNGs; the script
asserts that size). Every placement constant is at the top of
`build_medals.py`.

## Setup (once)

Python 3 with Pillow and NumPy. The scene-art environment already has
both, pinned (`tool/scene_art/requirements.txt`: Pillow 11.3.0, NumPy
2.0.2), so the medals use it:

```bash
python3 -m venv build/scene_art_venv
```

```bash
build/scene_art_venv/bin/pip install -r tool/scene_art/requirements.txt
```

## Run

From the repository root. The output goes to `build/` (git-ignored); the
composed PNGs are not committed (N3).

```bash
build/scene_art_venv/bin/python tool/medals/build_medals.py docs/design/medals/source build/medals/png
```

Arguments: the source folder, the output folder and, optionally, the
output size in px (default 768). It writes 13 files:

- `medal_<theme>_<tier>.png` for `<theme>` in `green_slope`,
  `ember_peak`, `glacier_peak`, `red_canyon` (the app's theme ids) and
  `<tier>` in `gold`, `silver`, `bronze`;
- `medal_welcome.png`.

The run is deterministic: two runs give byte-identical files (checked
2026-10-02 with Pillow 11.3.0 and NumPy 2.0.2, Python 3.9.6, about 2 s).

## Known limits (N1, N2)

- The stars are not readable below 48 px; "WELCOME" not below 96 px.
- The weakest colour pair is Red Canyon's mountain on the Bronze body.
- Ember Peak's smoke is partly behind the stars (`THEME_DY` moves that
  mountain down 75 px for it).
- The stars stand above the body's circle and the Welcome ribbon is wider
  than it: the measured overflow is in `docs/design/batch5/batch0-report.md`.
