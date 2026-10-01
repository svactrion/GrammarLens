"""Scene Art Stage 1: the real-Home renders as JPEGs, plus one overview.

    DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage1 \
        flutter test tool/design_measure/scene_art/home_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/stage1_sheet.py

Reads the 3x PNGs from build/design_measure/scene_art_stage1/ and writes
docs/design/scene-art/stage1/home_<screen>_<mode>_day<d>.jpg (2x, quality
88) and overview.jpg (all twelve, 1x).
"""

from __future__ import annotations

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/scene_art_stage1"
DST = T.REPO / "docs/design/scene-art/stage1"


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    rows = []
    for screen in (320, 375):
        for mode in ("light", "dark"):
            row = []
            for day in (1, 15, 31):
                name = f"home_{screen}_{mode}_day{day}"
                im = Image.open(SRC / f"{name}.png").convert("RGB")
                two = im.resize((im.width * 2 // 3, im.height * 2 // 3), Image.LANCZOS)
                two.save(DST / f"{name}.jpg", quality=88)
                row.append((f"{screen} pt · {mode} · day {day}/31", im.resize((im.width // 3, im.height // 3), Image.LANCZOS)))
            rows.append(row)
    gap, head = 12, 26
    cw = max(im.width for row in rows for _, im in row)
    rh = [max(im.height for _, im in row) + head for row in rows]
    sheet = Image.new("RGB", (3 * cw + 4 * gap, sum(rh) + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(sheet)
    y = gap
    for row, h in zip(rows, rh):
        for j, (label, im) in enumerate(row):
            x = gap + j * (cw + gap)
            d.text((x, y), label, fill=(0, 0, 0), font=font(15))
            sheet.paste(im, (x, y + head))
        y += h + gap
    sheet.save(DST / "overview.jpg", quality=88)


if __name__ == "__main__":
    main()
