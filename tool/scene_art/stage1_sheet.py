"""Scene Art: the real-Home renders as JPEGs, plus one overview.

    DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage1 \
        flutter test tool/design_measure/scene_art/home_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/stage1_sheet.py

Reads the 3x PNGs from build/design_measure/scene_art_<stage>/ and writes
docs/design/scene-art/<stage>/home_<screen>_<mode>_day<d>.jpg (2x, quality
88) and overview.jpg (all, 1x). Stage 1 by default; Stage 2:

    DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage2 \
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=1,10,20,31 \
        flutter test tool/design_measure/scene_art/home_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/stage1_sheet.py stage2 375 1,10,20,31

The Stage 2 fix's renders (days 20, 30, 31) go to the same folder with a
"fix_" prefix:

    DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage2 \
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=20,30,31 \
        flutter test tool/design_measure/scene_art/home_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/stage1_sheet.py stage2 375 20,30,31 fix_
"""

from __future__ import annotations

import sys

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

STAGE = sys.argv[1] if len(sys.argv) > 1 else "stage1"
SCREENS = [int(s) for s in sys.argv[2].split(",")] if len(sys.argv) > 2 else [320, 375]
DAYS = [int(d) for d in sys.argv[3].split(",")] if len(sys.argv) > 3 else [1, 15, 31]
# An optional prefix for the written files (the Stage 2 fix: "fix_").
PREFIX = sys.argv[4] if len(sys.argv) > 4 else ""
SRC = T.REPO / f"build/design_measure/scene_art_{STAGE}"
DST = T.REPO / f"docs/design/scene-art/{STAGE}"


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    rows = []
    for screen in SCREENS:
        for mode in ("light", "dark"):
            row = []
            for day in DAYS:
                name = f"home_{screen}_{mode}_day{day}"
                im = Image.open(SRC / f"{name}.png").convert("RGB")
                two = im.resize((im.width * 2 // 3, im.height * 2 // 3), Image.LANCZOS)
                two.save(DST / f"{PREFIX}{name}.jpg", quality=88)
                row.append((f"{screen} pt · {mode} · day {day}/31", im.resize((im.width // 3, im.height // 3), Image.LANCZOS)))
            rows.append(row)
    gap, head = 12, 26
    cw = max(im.width for row in rows for _, im in row)
    rh = [max(im.height for _, im in row) + head for row in rows]
    n = len(DAYS)
    sheet = Image.new("RGB", (n * cw + (n + 1) * gap, sum(rh) + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(sheet)
    y = gap
    for row, h in zip(rows, rh):
        for j, (label, im) in enumerate(row):
            x = gap + j * (cw + gap)
            d.text((x, y), label, fill=(0, 0, 0), font=font(15))
            sheet.paste(im, (x, y + head))
        y += h + gap
    sheet.save(DST / f"{PREFIX}overview.jpg", quality=88)


if __name__ == "__main__":
    main()
