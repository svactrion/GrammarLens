"""Batch 6 Batch 0 §5: the month card prototype's renders as JPEGs.

    DESIGN_MEASURE_OUT=build/design_measure/batch6_sheet \\
        flutter test tool/design_measure/batch6/month_card_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/batch6_sheet_sheet.py

Reads the 2x PNGs from build/design_measure/batch6_sheet/ and writes to
docs/design/batch6/sheet/:
- <card>_<screen>_<mode>_medium_scroll<top|card>.jpg, 1x, Medium text;
- overview_<card>_scroll<top|card>.jpg: 3 screens × light/dark, Medium;
- textsizes_320.jpg: both cards at 320 × 568, light, Small/Medium/Large,
  Home at its top and scrolled to the card;
and copies month_card_numbers.txt.
"""

from __future__ import annotations

import shutil

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/batch6_sheet"
DST = T.REPO / "docs/design/batch6/sheet"
SCREENS = [320, 375, 430]
MODES = ["light", "dark"]
CARDS = ["summary", "fresh"]
SCROLLS = ["top", "card"]


def one(name: str) -> Image.Image:
    im = Image.open(SRC / f"{name}.png").convert("RGB")
    return im.resize((im.width // 2, im.height // 2), Image.LANCZOS)


def grid(cells: list[tuple[str, Image.Image]], cols: int) -> Image.Image:
    gap, head = 12, 26
    cw = max(im.width for _, im in cells)
    rows = [cells[i:i + cols] for i in range(0, len(cells), cols)]
    rh = [max(im.height for _, im in r) + head for r in rows]
    out = Image.new("RGB", (cols * cw + (cols + 1) * gap, sum(rh) + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(out)
    y = gap
    for r, h in zip(rows, rh):
        for i, (label, im) in enumerate(r):
            x = gap + i * (cw + gap)
            d.text((x, y), label, fill="black", font=font(18))
            out.paste(im, (x, y + head))
        y += h + gap
    return out


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    for card in CARDS:
        for scroll in SCROLLS:
            cells = []
            for screen in SCREENS:
                for mode in MODES:
                    name = f"{card}_{screen}_{mode}_medium_scroll{scroll}"
                    im = one(name)
                    im.save(DST / f"{name}.jpg", quality=85)
                    cells.append((f"{screen} pt · {mode}", im))
            grid(cells, 6).save(DST / f"overview_{card}_scroll{scroll}.jpg", quality=82)
    cells = []
    for scroll in SCROLLS:
        for card in CARDS:
            for size in ["small", "medium", "large"]:
                cells.append((f"{card} · {size} · Home {scroll}", one(f"{card}_320_light_{size}_scroll{scroll}")))
    grid(cells, 6).save(DST / "textsizes_320.jpg", quality=82)
    shutil.copy(SRC / "month_card_numbers.txt", DST / "month_card_numbers.txt")


if __name__ == "__main__":
    main()
