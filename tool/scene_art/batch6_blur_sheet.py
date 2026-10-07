"""Batch 6, M22: the K-c blurred backdrop at three strengths, as JPEG sheets,
and the seam between the sharp image's edge and the backdrop.

    build/scene_art_venv/bin/python tool/scene_art/export_blur.py --candidates
    DESIGN_MEASURE_OUT=build/design_measure/batch6_blur \\
        flutter test tool/design_measure/batch6/kc_blur_render_test.dart
    build/scene_art_venv/bin/python tool/scene_art/batch6_blur_sheet.py

Writes docs/design/batch6/blur/blur_430_<mode>.jpg (rows: the four themes;
columns: light / medium / strong; medium is the product's) and
blur_seam.txt: for each render, the CIEDE2000 difference across each side
seam, between the mean colour of the 4 px just inside the sharp image and
the 4 px just outside it (the backdrop), row by row over the window's
height: median and 95th percentile, the larger of the two sides.
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image, ImageDraw
from skimage.color import deltaE_ciede2000, rgb2lab

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/batch6_blur"
DST = T.REPO / "docs/design/batch6/blur"
STRENGTHS = ("light", "medium", "strong")
THEMES = ("green_slope", "ember_peak", "glacier_peak", "red_canyon")
STRIP = 4


def seam(name: str) -> tuple[float, float]:
    box = json.loads((SRC / f"{name}.json").read_text())
    lab = rgb2lab(np.asarray(Image.open(SRC / f"{name}.png").convert("RGB"), dtype=np.float64) / 255)
    top, bottom = int(box["window"][1]) + 2, int(box["window"][3]) - 2
    worst = (0.0, 0.0)
    for edge, inside in ((box["sharp_left"], 1), (box["sharp_right"], -1)):
        x = int(round(edge))
        a = lab[top:bottom, x + 1: x + 1 + STRIP] if inside > 0 else lab[top:bottom, x - 1 - STRIP: x - 1]
        b = lab[top:bottom, x - 1 - STRIP: x - 1] if inside > 0 else lab[top:bottom, x + 1: x + 1 + STRIP]
        de = deltaE_ciede2000(a.mean(axis=1), b.mean(axis=1))
        side = (float(np.median(de)), float(np.percentile(de, 95)))
        worst = max(worst, side)
    return worst


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    lines = [
        "Batch 6 M22: the seam between the sharp image and the blurred backdrop",
        "(K-c, 430 pt, sheet closed; CIEDE2000 across the edge, median / p95, worse side)",
        "",
        "theme          mode   light          medium         strong",
    ]
    for mode in ("light", "dark"):
        rows = []
        for theme in THEMES:
            cells, seams = [], []
            for s in STRENGTHS:
                name = f"blur_{s}_{mode}_{theme}"
                im = Image.open(SRC / f"{name}.png").convert("RGB")
                cells.append((f"{theme} · {mode} · {s}{' (product)' if s == 'medium' else ''}", im.resize((im.width // 2, im.height // 2), Image.LANCZOS)))
                med, p95 = seam(name)
                seams.append(f"{med:5.1f} / {p95:5.1f}")
            rows.append(cells)
            lines.append(f"{theme:<14} {mode:<6} " + "  ".join(seams))
        gap, head = 12, 26
        cw = max(im.width for r in rows for _, im in r)
        rh = max(im.height for r in rows for _, im in r) + head
        out = Image.new("RGB", (3 * cw + 4 * gap, len(rows) * rh + (len(rows) + 1) * gap), "white")
        d = ImageDraw.Draw(out)
        for r, row in enumerate(rows):
            y = gap + r * (rh + gap)
            for i, (label, im) in enumerate(row):
                x = gap + i * (cw + gap)
                d.text((x, y), label, fill="black", font=font(16))
                out.paste(im, (x, y + head))
        out.save(DST / f"blur_430_{mode}.jpg", quality=86)
    (DST / "blur_seam.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
