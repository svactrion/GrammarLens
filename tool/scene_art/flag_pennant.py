"""G10: Red Canyon's pennant colour, candidates measured on the real Home.

    for c in 1E4FA3 2F7BD8 1FB5C9 F0843A; do
      DESIGN_MEASURE_OUT=build/design_measure/scene_art_pennant \\
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=30,31 \\
        DESIGN_MEASURE_MONTH=2027-01 DESIGN_MEASURE_PENNANT=$c \\
        flutter test tool/design_measure/scene_art/home_render_test.dart
    done
    build/scene_art_venv/bin/python tool/scene_art/flag_pennant.py

For each candidate, mode and day (30: the flag faded; 31: lit), the
CIEDE2000 difference between the pennant's mean colour (its asset's alpha
> 50 % mapped onto the flag's box) and the rock around the flag (a band
a third of the box wide around it). F0843A is the brand orange through the
same recolour, standing in for today's pennant. Writes
docs/design/scene-art/batch4/flag_pennant.txt and flag_pennant.jpg (the
flag's surroundings, 3x, per candidate).
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image, ImageDraw
from skimage.color import deltaE_ciede2000, rgb2lab

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure/scene_art_pennant"
DST = T.REPO / "docs/design/scene-art/batch4"
CANDIDATES = (("1E4FA3", "dark blue"), ("2F7BD8", "mid blue"), ("1FB5C9", "cyan"),
              ("F0843A", "brand orange (≈ today)"))
SHOTS = (("light", 30), ("light", 31), ("dark", 30), ("dark", 31))


def measure(png, box):
    im = np.asarray(Image.open(png).convert("RGB")) / 255.0
    lab = rgb2lab(im)
    l, t, r, b = (int(round(v)) for v in box)
    a = Image.open(T.REPO / "assets/climb/objects/summit_flag_pennant.webp").convert("RGBA")
    a = np.asarray(a.resize((r - l, b - t), Image.LANCZOS))[..., 3] > 127
    pennant = lab[t:b, l:r][a].mean(0)
    pad = (r - l) // 3
    ring = np.ones((b - t + 2 * pad, r - l + 2 * pad), bool)
    ring[pad:-pad, pad:-pad] = False
    rock = lab[t - pad:b + pad, l - pad:r + pad][ring].mean(0)
    return float(deltaE_ciede2000(pennant[None], rock[None])[0]), (l, t, r, b)


def main() -> None:
    lines = ["G10: Red Canyon's pennant against the rock around the flag (CIEDE2000, mean colours),",
             "real Home at 375 pt, January 2027. Day 30: the flag faded; day 31: lit.", "",
             f"{'candidate':28s} " + "  ".join(f"{m} day {d:2d}" for m, d in SHOTS)]
    crops = []
    scores = {}
    for hexc, name in CANDIDATES:
        row, tiles = [], []
        for mode, day in SHOTS:
            stem = SRC / f"home_375_{mode}_day{day}_2027-01_pennant{hexc}"
            box = json.loads(open(f"{stem}.json").read())["summit_flag"]
            de, (l, t, r, b) = measure(f"{stem}.png", box)
            row.append(de)
            im = Image.open(f"{stem}.png").convert("RGB")
            cx, cy = (l + r) // 2, (t + b) // 2
            tiles.append(im.crop((cx - 150, cy - 120, cx + 150, cy + 120)))
        scores[hexc] = row
        lines.append(f"{('#' + hexc + ' ' + name):28s} " + "  ".join(f"{v:12.1f}" for v in row))
        crops.append((f"#{hexc} {name}", tiles))
    blues = [c for c, _ in CANDIDATES if c != "F0843A"]
    best = max(blues, key=lambda c: min(scores[c]))
    lines += ["", f"Best separated (largest lowest ΔE of the four shots): #{best}"]
    (DST / "flag_pennant.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    w, h = 300, 240
    g, head = 10, 30
    sheet = Image.new("RGB", (170 + 4 * (w + g), len(crops) * (h + g) + head + g), "white")
    d = ImageDraw.Draw(sheet)
    for j, (mode, day) in enumerate(SHOTS):
        d.text((170 + j * (w + g), 6), f"{mode}, day {day}", fill=(0, 0, 0), font=font(16))
    for i, (label, tiles) in enumerate(crops):
        y = head + i * (h + g)
        d.text((8, y + h // 2 - 10), label.replace(" (", "\n("), fill=(0, 0, 0), font=font(14))
        for j, tile in enumerate(tiles):
            sheet.paste(tile, (170 + j * (w + g), y))
    sheet.save(DST / "flag_pennant.jpg", quality=88)


if __name__ == "__main__":
    main()
