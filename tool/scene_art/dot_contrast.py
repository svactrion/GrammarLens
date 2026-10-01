"""Scene Art device follow-up: how faint are the passed-day dots?

    build/scene_art_venv/bin/python tool/scene_art/dot_contrast.py

For each step of a 31-day month (0-30, where dots can stand), the trail's
colour under the dot is read from the app's own WebP backgrounds (median
of a 10 px disc), the dot is composited over it (the palette's ink at the
given opacity, ClimbTrailDots) and the WCAG contrast ratio between the dot
and the trail around it is computed. Writes
docs/design/scene-art/stage1-device/dot_contrast.txt.
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image

import trail as T

INK = {"light": (0x26, 0x3D, 0x39), "dark": (0xE4, 0xE2, 0xD8)}  # ClimbPalette.ink
OPACITIES = (0.22, 0.30, 0.40, 0.50, 0.60)
CURRENT = 0.22


def lum(rgb) -> float:
    c = np.asarray(rgb, float) / 255
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])


def ratio(a, b) -> float:
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def main() -> None:
    steps = json.loads((T.OUT / "trail_green.json").read_text())["steps"]["31"][:31]
    out = T.REPO / "docs/design/scene-art/stage1-device"
    out.mkdir(parents=True, exist_ok=True)
    lines = ["Passed-day dots: WCAG contrast between a dot and the trail around it,",
             "31-day month, steps 0-30; trail colour from the app's WebP backgrounds.",
             f"Dots today: 4 pt, opacity {CURRENT}. For scale: 3:1 is WCAG's minimum for",
             "meaningful non-text marks (1.4.11); these dots are decorative, so it is",
             "a reference, not a rule.", ""]
    for mode in ("light", "dark"):
        im = np.asarray(Image.open(T.REPO / f"assets/climb/green_slope/background_{mode}.webp").convert("RGB")).astype(float)
        h, w = im.shape[:2]
        yy, xx = np.mgrid[-10:11, -10:11]
        disc = xx**2 + yy**2 <= 100
        trails = []
        for x, y in steps:
            cx, cy = round(x * w), round(y * h)
            patch = im[cy - 10:cy + 11, cx - 10:cx + 11][disc]
            trails.append(np.median(patch, 0))
        trail = np.median(trails, 0)
        lines.append(f"{mode}: trail under the dots, median RGB {np.round(trail).astype(int).tolist()}; ink {INK[mode]}")
        for a in OPACITIES:
            rs = [ratio(np.array(INK[mode]) * a + t * (1 - a), t) for t in trails]
            mark = "  <- today" if a == CURRENT else ""
            lines.append(f"  opacity {a:.2f}: contrast median {np.median(rs):.2f}:1, lowest {min(rs):.2f}:1{mark}")
        lines.append("")
    (out / "dot_contrast.txt").write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
