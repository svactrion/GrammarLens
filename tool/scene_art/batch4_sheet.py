"""Batch 4: the real-Home renders of the four themes as JPEGs, plus an
overview with the themes side by side.

    for m in 2026-10 2026-11 2026-12 2027-01; do   # last day 31, 30, 31, 31
      DESIGN_MEASURE_OUT=build/design_measure/scene_art_batch4 \\
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=1,20,<last> \\
        DESIGN_MEASURE_MONTH=$m \\
        flutter test tool/design_measure/scene_art/home_render_test.dart
    done
    build/scene_art_venv/bin/python tool/scene_art/batch4_sheet.py

Writes docs/design/scene-art/batch4/<theme>_<mode>_day<d>.jpg (2x, the
three new themes) and overview.jpg: one column per theme (Green Slope,
Ember Peak, Glacier Peak, Red Canyon), rows light day 20, light last day,
dark day 20, dark last day (1x).
"""

from __future__ import annotations

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/scene_art_batch4"
DST = T.REPO / "docs/design/scene-art/batch4"
THEMES = (("green_slope", "Green Slope", "2026-10", 31), ("ember_peak", "Ember Peak", "2026-11", 30),
          ("glacier_peak", "Glacier Peak", "2026-12", 31), ("red_canyon", "Red Canyon", "2027-01", 31))


def png(mode: str, day: int, month: str) -> Image.Image:
    return Image.open(SRC / f"home_375_{mode}_day{day}_{month}.png").convert("RGB")


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    for theme, _, month, last in THEMES[1:]:
        for mode in ("light", "dark"):
            for day in (1, 20, last):
                im = png(mode, day, month)
                im.resize((im.width * 2 // 3, im.height * 2 // 3), Image.LANCZOS).save(
                    DST / f"{theme}_{mode}_day{day}.jpg", quality=88)
    rows = [("light", 20), ("light", None), ("dark", 20), ("dark", None)]
    tiles = [[png(mode, day or last, month) for _, _, month, last in THEMES] for mode, day in rows]
    tiles = [[im.resize((im.width // 3, im.height // 3), Image.LANCZOS) for im in row] for row in tiles]
    w, h = tiles[0][0].size
    g, head, side = 12, 34, 120
    sheet = Image.new("RGB", (side + 4 * w + 5 * g, head + 4 * h + 5 * g), "white")
    d = ImageDraw.Draw(sheet)
    for j, (_, name, month, last) in enumerate(THEMES):
        d.text((side + g + j * (w + g), 8), f"{name} ({month}, {last} days)", fill=(0, 0, 0), font=font(16))
    for i, (mode, day) in enumerate(rows):
        y = head + g + i * (h + g)
        d.text((8, y + h // 2 - 20), f"{mode}\nday {day or 'last'}", fill=(0, 0, 0), font=font(16))
        for j, im in enumerate(tiles[i]):
            sheet.paste(im, (side + g + j * (w + g), y))
    sheet.save(DST / "overview.jpg", quality=88)


if __name__ == "__main__":
    main()
