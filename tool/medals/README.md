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

## App assets (Batch 5, N23)

```bash
build/scene_art_venv/bin/python tool/medals/export_medal_assets.py
```

Runs `build_medals.py` at 384 px into a temporary folder and writes the
13 medals as `assets/medals/<name>.webp` (WebP quality 90, alpha lossless,
method 6; 374.2 KB in all, `docs/design/batch5/assets/medal_export.txt`).
384 px covers the largest medal the app draws, the celebration's 112 pt
disc (its canvas is 126 pt, 378 px at 3x).

```bash
build/scene_art_venv/bin/python tool/medals/export_medal_assets.py --check
```

After a source change: compares the committed assets with what the
sources make now (same bytes, or pixels within 2); exit code 1 when one
is stale or missing (`medal_check.txt`).

## Measuring (Batch 5 Batch 0)

```bash
build/scene_art_venv/bin/python tool/medals/medal_assets.py
```

Reads `build/medals/png/` (the command above) and writes
`docs/design/batch5/medal_assets.txt` and `medals_sheet.jpg`: how far the
stars and the ribbon reach past the body's disc, and the WebP candidates'
bytes and error at 256 / 384 / 512 px (also written to
`build/medals/webp/<px>/` for the prototypes in
`tool/design_measure/batch5/`). About 3 minutes.

## Known limits (N1, N2)

- The stars are not readable below 48 px; "WELCOME" not below 96 px.
- The weakest colour pair is Red Canyon's mountain on the Bronze body.
- Ember Peak's smoke is partly behind the stars (`THEME_DY` moves that
  mountain down 75 px for it).
- The stars stand above the body's disc (up to 5.6 % of its diameter);
  the Welcome ribbon crosses the round outline at the top corners but stays
  inside the disc's bounding square (`docs/design/batch5/medal_assets.txt`).
- The font's licence: SIL Open Font License 1.1, copyright 2020 The
  Poppins Project Authors. The licence text sits beside the font,
  `docs/design/medals/source/extras/OFL.txt` (N26); keep the two together
  if the font moves. The baked-in "WELCOME" carries no licence duty.
