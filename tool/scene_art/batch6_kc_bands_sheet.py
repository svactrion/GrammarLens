"""Batch 6, M11: the K-c bands render, four themes side by side at 430 pt in
light mode; top row the product's single colour, bottom row the vertical
gradient (render only, not in the product).

    DESIGN_MEASURE_OUT=build/design_measure/batch6_kc_bands \\
        flutter test tool/design_measure/batch6/kc_bands_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/batch6_kc_bands_sheet.py

Writes docs/design/batch6/kc_bands_430_light.jpg.
"""

from __future__ import annotations

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/batch6_kc_bands"
DST = T.REPO / "docs/design/batch6"
THEMES = ["green_slope", "ember_peak", "glacier_peak", "red_canyon"]


def main() -> None:
    rows = []
    for kind, label in (("solid", "single colour (product)"), ("gradient", "vertical gradient (render only)")):
        rows.append([(f"{t} · {label}", Image.open(SRC / f"kc_430_light_{t}_{kind}.png").convert("RGB")) for t in THEMES])
    gap, head = 14, 28
    cw = max(im.width for r in rows for _, im in r)
    rh = max(im.height for r in rows for _, im in r) + head
    out = Image.new("RGB", (len(THEMES) * cw + (len(THEMES) + 1) * gap, len(rows) * rh + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(out)
    for r, row in enumerate(rows):
        y = gap + r * (rh + gap)
        for i, (label, im) in enumerate(row):
            x = gap + i * (cw + gap)
            d.text((x, y), label, fill="black", font=font(18))
            out.paste(im, (x, y + head))
    out.save(DST / "kc_bands_430_light.jpg", quality=86)


if __name__ == "__main__":
    main()
