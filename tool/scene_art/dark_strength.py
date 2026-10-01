"""Scene Art Stage 2 fix: G6's dark-mode strength, compared on the real Home.

    for k in 0.4 0.6 0.8 1.0; do
      DESIGN_MEASURE_OUT=build/design_measure/scene_art_strength \\
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=20,31 \\
        DESIGN_MEASURE_MODES=dark DESIGN_MEASURE_DARK_STRENGTH=$k \\
        flutter test tool/design_measure/scene_art/home_render_test.dart
    done
    build/scene_art_venv/bin/python tool/scene_art/dark_strength.py

For each strength and object, from the renders (dark mode, 375 pt, 3x):
the mean lightness (CIE L*, 0–100) of the object's own pixels (its
asset's alpha > 50 % mapped onto its box), on day 20 and on day 31, and
of the ground around it (a band a third of the box wide around it). On
day 20 the fountain (reached on day 21) and the campfire (day 26) are
unreached; on day 31 every save point is reached.

Writes docs/design/scene-art/stage2/fix_dark_strength.txt and
fix_dark_strength.jpg (the cards side by side).
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image, ImageDraw
from skimage.color import rgb2lab

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/scene_art_strength"
DST = T.REPO / "docs/design/scene-art/stage2"
# 1.0 is the full filter the device check found too dark, for reference.
STRENGTHS = ("0.4", "0.6", "0.8", "1.0")
DAYS = (20, 31)
UNREACHED_ON_20 = ("fountain", "campfire")


def measure(png, boxes: dict) -> dict:
    im = np.asarray(Image.open(png).convert("RGB")) / 255.0
    L = rgb2lab(im)[..., 0]
    out = {}
    wl, wt, wr, wb = boxes.pop("window")
    for name, (l, t, r, b) in boxes.items():
        l, t, r, b = (int(round(v)) for v in (l, t, r, b))
        if l < wl or t < wt or r > wr or b > wb:
            continue  # not wholly in the window this day
        a = Image.open(T.REPO / f"assets/climb/objects/{name}.webp").convert("RGBA")
        a = np.asarray(a.resize((r - l, b - t), Image.LANCZOS))[..., 3] > 127
        obj = L[t:b, l:r][a]
        pad = (r - l) // 3
        T0, B0 = max(int(wt), t - pad), min(int(wb), b + pad)
        L0, R0 = max(int(wl), l - pad), min(int(wr), r + pad)
        ring = np.ones((B0 - T0, R0 - L0), bool)
        ring[t - T0:b - T0, l - L0:r - L0] = False
        out[name] = {"object_L": float(obj.mean()), "ground_L": float(L[T0:B0, L0:R0][ring].mean())}
    return out


def main() -> None:
    lines = ["G6 strength in dark mode, 375 pt, real Home: mean L* (0-100) of each object's",
             "own pixels and of the ground around it. Day 20: fountain and campfire",
             "unreached; day 31: all reached.", ""]
    data = {}
    for k in STRENGTHS:
        data[k] = {}
        for day in DAYS:
            stem = SRC / f"home_375_dark_day{day}_strength{k}"
            data[k][day] = measure(f"{stem}.png", json.loads(open(f"{stem}.json").read()))
        lines.append(f"strength {k}")
        for name in ("tent", "cabin", "fountain", "campfire"):
            d31 = data[k][31].get(name)
            d20 = data[k][20].get(name)
            row = f"  {name:9s}"
            if not d31:
                row += " not wholly in the window on day 31"
            if d31:
                row += f" reached (day 31): object {d31['object_L']:5.1f}, ground {d31['ground_L']:5.1f}, object − ground {d31['object_L'] - d31['ground_L']:+5.1f}"
            if d20 and d31 and name in UNREACHED_ON_20:
                row += f" | unreached (day 20): object {d20['object_L']:5.1f}; reached − unreached {d31['object_L'] - d20['object_L']:+5.1f}"
            lines.append(row)
        lines.append("")
    (DST / "fix_dark_strength.txt").write_text("\n".join(lines))
    print("\n".join(lines))

    # The cards side by side: rows = strengths, columns = day 20, day 31.
    tiles = []
    for k in STRENGTHS:
        row = []
        for day in DAYS:
            im = Image.open(SRC / f"home_375_dark_day{day}_strength{k}.png").convert("RGB")
            im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
            ImageDraw.Draw(im).text((24, 140), f"strength {k} · day {day}/31", fill=(255, 255, 255),
                                    font=font(26), stroke_width=3, stroke_fill=(0, 0, 0))
            row.append(im)
        tiles.append(row)
    w, h = tiles[0][0].size
    g = 12
    n = len(tiles)
    sheet = Image.new("RGB", (2 * w + 3 * g, n * h + (n + 1) * g), "white")
    for i, row in enumerate(tiles):
        for j, im in enumerate(row):
            sheet.paste(im, (g + j * (w + g), g + i * (h + g)))
    sheet.save(DST / "fix_dark_strength.jpg", quality=86)


if __name__ == "__main__":
    main()
