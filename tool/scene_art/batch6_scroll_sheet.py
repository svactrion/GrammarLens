"""Batch 6 step 5's stop condition: the real Home after each scroll, with
Batch 0's fullest summary-card prototype open, at Medium text.

    DESIGN_MEASURE_OUT=build/design_measure/batch6_scroll \\
        flutter test tool/design_measure/batch6/scroll_check_test.dart
    build/scene_art_venv/bin/python tool/scene_art/batch6_scroll_sheet.py

Writes docs/design/batch6/scroll/scroll_overview.jpg (rows: 320 / 375 / 430
pt; columns: card / peek / today) and copies scroll_check.txt.
"""

from __future__ import annotations

import shutil

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/batch6_scroll"
DST = T.REPO / "docs/design/batch6/scroll"
SCREENS = [320, 375, 430]
SCROLLS = [("card", "climb card at the top (M10)"), ("peek", "Today card's last 56 pt"), ("today", "Today card at the top")]


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    rows = []
    for screen in SCREENS:
        row = []
        for key, label in SCROLLS:
            im = Image.open(SRC / f"scroll_{screen}_medium_{key}.png").convert("RGB")
            row.append((f"{screen} pt · {label}", im.resize((im.width // 2, im.height // 2), Image.LANCZOS)))
        rows.append(row)
    gap, head = 14, 28
    cw = max(im.width for r in rows for _, im in r)
    rh = [max(im.height for _, im in r) + head for r in rows]
    out = Image.new("RGB", (3 * cw + 4 * gap, sum(rh) + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(out)
    y = gap
    for r, h in zip(rows, rh):
        for i, (label, im) in enumerate(r):
            x = gap + i * (cw + gap)
            d.text((x, y), label, fill="black", font=font(18))
            out.paste(im, (x, y + head))
        y += h + gap
    out.save(DST / "scroll_overview.jpg", quality=84)
    shutil.copy(SRC / "scroll_check.txt", DST / "scroll_check.txt")


if __name__ == "__main__":
    main()
