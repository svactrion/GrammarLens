"""Batch 6 step B: the real month card's renders as JPEGs.

    DESIGN_MEASURE_OUT=build/design_measure/batch6_card \\
        flutter test tool/design_measure/batch6/month_card_real_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/batch6_card_sheet.py

Writes to docs/design/batch6/card/: overview_<card>.jpg (3 screens × light
and dark, Medium), textsizes_320.jpg (both cards at 320 × 568, light,
Small / Medium / Large), one 1x JPEG per screen and mode at Medium, and
month_card_real_numbers.txt.
"""

from __future__ import annotations

import shutil

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/batch6_card"
DST = T.REPO / "docs/design/batch6/card"


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
    for card in ("summary", "fresh"):
        cells = []
        for screen in (320, 375, 430):
            for mode in ("light", "dark"):
                name = f"card_{card}_{screen}_{mode}_medium"
                im = one(name)
                im.save(DST / f"{name}.jpg", quality=85)
                cells.append((f"{screen} pt · {mode}", im))
        grid(cells, 6).save(DST / f"overview_{card}.jpg", quality=82)
    cells = [
        (f"{card} · {size}", one(f"card_{card}_320_light_{size}"))
        for card in ("summary", "fresh")
        for size in ("small", "medium", "large")
    ]
    grid(cells, 6).save(DST / "textsizes_320.jpg", quality=82)
    shutil.copy(SRC / "month_card_real_numbers.txt", DST / "month_card_real_numbers.txt")


if __name__ == "__main__":
    main()
