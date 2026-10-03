"""1.1.0 release step 2: the iPad check's JPEGs from the Flutter tool's PNGs.

    DESIGN_MEASURE_OUT=build/design_measure/ipad \\
      flutter test tool/design_measure/release/ipad_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/release_ipad_sheet.py

Reads build/design_measure/ipad (or IPAD_IN) and writes to
docs/design/release-1.1.0/ipad/ (or IPAD_OUT):
- <case>.jpg: one sheet per case, rows 13 in / 11 in / mini, columns
  light Medium, light Large, dark Medium, dark Large, each screen at
  0.15 of its pixels (0.3 of its points);
- scene_1to1_<device>.jpg: Home's mountain window on day 15 (light,
  Medium) cut out at the device's own pixels, to judge the image's
  sharpness;
- ipad_numbers.txt copied.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = Path(os.environ.get("IPAD_IN", T.REPO / "build/design_measure/ipad"))
OUT = Path(os.environ.get("IPAD_OUT", T.REPO / "docs/design/release-1.1.0/ipad"))

CASES = ("launch", "home_day1", "home_day15", "home_day31", "card_summary", "card_fresh", "kc", "label",
         "cel_welcome", "cel_gold", "result", "profile", "profile_detail", "avatar_picker")
DEVICES = (("13in", "13 in, 1032 × 1376"), ("11in", "11 in, 834 × 1194"), ("mini", "mini, 744 × 1133"))
COLUMNS = (("light", "medium"), ("light", "large"), ("dark", "medium"), ("dark", "large"))
SCALE = 0.15
GAP = 14
HEAD = 34
SIDE = 190


def sheet(case: str) -> Image.Image:
    cells = [[Image.open(SRC / f"ipad_{case}_{d}_{m}_{s}.png").convert("RGB") for m, s in COLUMNS]
             for d, _ in DEVICES]
    cells = [[c.resize((round(c.width * SCALE), round(c.height * SCALE)), Image.LANCZOS) for c in row]
             for row in cells]
    col_w = max(c.width for row in cells for c in row)
    heights = [max(c.height for c in row) for row in cells]
    W = SIDE + len(COLUMNS) * (col_w + GAP) + GAP
    H = HEAD + sum(heights) + GAP * (len(cells) + 1)
    out = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, (m, s) in enumerate(COLUMNS):
        d.text((SIDE + GAP + i * (col_w + GAP), 8), f"{m}, {s.capitalize()}", fill=(30, 30, 30), font=font(18))
    y = HEAD + GAP
    for r, row in enumerate(cells):
        d.text((GAP, y), DEVICES[r][1], fill=(30, 30, 30), font=font(16))
        for i, c in enumerate(row):
            x = SIDE + GAP + i * (col_w + GAP)
            out.paste(c, (x, y))
            d.rectangle((x - 1, y - 1, x + c.width, y + c.height), outline=(200, 200, 200))
        y += heights[r] + GAP
    return out


def scene_1to1() -> None:
    """The mountain window at device pixels: the window is at (28, 312 + 18)
    pt with Medium text (ipad_numbers.txt), 350 pt tall."""
    for d, width in (("13in", 976), ("11in", 778), ("mini", 688)):
        im = Image.open(SRC / f"ipad_home_day15_{d}_light_medium.png").convert("RGB")
        box = (28 * 2, 330 * 2, (28 + width) * 2, (330 + 350) * 2)
        im.crop(box).save(OUT / f"scene_1to1_{d}.jpg", quality=88)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for case in CASES:
        sheet(case).save(OUT / f"{case}.jpg", quality=80)
    scene_1to1()
    shutil.copy(SRC / "ipad_numbers.txt", OUT)


if __name__ == "__main__":
    main()
