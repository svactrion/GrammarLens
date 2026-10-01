"""Batch 4 check: a close look at what the first check_theme.py failed on.

    build/scene_art_venv/bin/python tool/scene_art/check_theme_detail.py \\
        <out dir> <image> [<image> ...]

For each image, the measure that fails (or is closest to failing): every
clearing whose centre moved past the threshold (or was not found), and
the trail's worst point measured both ways. Each crop shows the reference
(green/background_light.png) and the image side by side, 400 px square at
2172 scale, with:
  red    the reference's centre line and clearing boxes,
  cyan   the image's own extraction.
If the image's actual clearing or trail sits under the red marks, the
failure is the extraction's (colour and flatness tuned on Green), not the
image's.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import trail as T
from check_theme import REFERENCE

# The first check's clearing limit (share of the height), which the Batch 4
# images failed; this tool shows why (the current check verifies at Green's
# positions instead).
MAX_CLEARING_SHIFT = 0.004


def crop_pair(ref_img, img, centre, ref_t, t, ref_cl, cl, label, path):
    cx, cy = int(centre[0]), int(centre[1])
    tiles = []
    for im in (ref_img, img):
        c = im.crop((cx - 200, cy - 200, cx + 200, cy + 200)).convert("RGB")
        d = ImageDraw.Draw(c)
        for pts, colour in ((ref_t.points, (255, 40, 40)), (t.points, (0, 220, 255))):
            d.line([tuple(p - [cx - 200, cy - 200]) for p in pts], fill=colour, width=3)
        for boxes, colour in ((ref_cl, (255, 40, 40)), (cl, (0, 220, 255))):
            for b in boxes:
                if b.get("missing"):
                    continue
                (bx, by), (bw, bh) = b["center_px"], b["box_px"]
                d.ellipse([bx - bw / 2 - cx + 200, by - bh / 2 - cy + 200,
                           bx + bw / 2 - cx + 200, by + bh / 2 - cy + 200], outline=colour, width=3)
        tiles.append(c)
    out = Image.new("RGB", (810, 440), "white")
    out.paste(tiles[0], (0, 40))
    out.paste(tiles[1], (410, 40))
    ImageDraw.Draw(out).text((8, 8), f"{label}  (left: Green reference; right: this image; red = reference, cyan = this image's extraction)",
                             fill=(0, 0, 0))
    out.save(path, quality=88)


def main(argv: list[str]) -> None:
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    ref = T.extract(T.SOURCE / REFERENCE)
    ref_cl = T.clearings(ref)
    ref_img = Image.open(T.SOURCE / REFERENCE)
    H = ref.size[1]
    for name in argv[1:]:
        p = Path(name)
        stem = f"{p.parent.name}_{p.stem}"
        t = T.extract(p)
        cl = T.clearings(t)
        img = Image.open(p)
        for i, (a, b) in enumerate(zip(ref_cl, cl), 1):
            ac = np.array(a["center_px"])
            if b.get("missing"):
                crop_pair(ref_img, img, ac, ref, t, ref_cl, cl, f"{stem}: C{i} not found", out / f"{stem}_C{i}.jpg")
                continue
            shift = float(np.hypot(*(np.array(b["center_px"]) - ac)))
            if shift / H > MAX_CLEARING_SHIFT:
                crop_pair(ref_img, img, ac, ref, t, ref_cl, cl,
                          f"{stem}: C{i} centre {shift:.1f} px from the reference's", out / f"{stem}_C{i}.jpg")
        # The trail's worst point, measured both ways.
        span_a = ref.at(np.linspace(ref.length_px * .03, ref.length_px * .97, 600))
        span_b = t.at(np.linspace(t.length_px * .03, t.length_px * .97, 600))
        d_ab = np.array([np.min(np.linalg.norm(t.points - p, axis=1)) for p in span_a])
        d_ba = np.array([np.min(np.linalg.norm(ref.points - p, axis=1)) for p in span_b])
        worst = span_a[d_ab.argmax()] if d_ab.max() >= d_ba.max() else span_b[d_ba.argmax()]
        dev = max(d_ab.max(), d_ba.max())
        crop_pair(ref_img, img, worst, ref, t, ref_cl, cl,
                  f"{stem}: trail's worst point, {dev:.1f} px", out / f"{stem}_trail.jpg")
        print(stem, "done")


if __name__ == "__main__":
    main(sys.argv[1:])
