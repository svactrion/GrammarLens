"""Batch 5 Batch 0: the composed medals' geometry and their app-asset cost.

    build/scene_art_venv/bin/python tool/medals/build_medals.py docs/design/medals/source build/medals/png
    build/scene_art_venv/bin/python tool/medals/medal_assets.py

Reads the 13 composed PNGs (768 px, build_medals.py's default) from
build/medals/png and writes docs/design/batch5/medal_assets.txt (or into
BATCH5_OUT):

1. Geometry. The body's circle is measured on the body source
   (medal-ranks/medal_<tier>.png, alpha > 40, the same cut build_medals.py
   uses), scaled to the composed size; every composed medal shares it
   (the script never moves the body). The stars and the Welcome ribbon
   stand outside that circle: per medal, how far the visible image
   (alpha > 40) reaches past the circle on each side, as a share of the
   circle's diameter. A layout that keeps the circle at a given size
   needs that much room around it; a layout that fits the whole image in
   a box draws the circle smaller by the same amount.
2. Asset sizes. Each medal as lossy WebP (alpha lossless, libwebp's
   default) at several pixel sizes and qualities: bytes for one, for all
   13, and the error against a Lanczos PNG at the same size (mean and
   99th percentile absolute difference over visible pixels, 0-255,
   premultiplied by alpha). The candidates go to build/medals/webp/<px>/
   (quality 90) for the Flutter prototypes in tool/design_measure/batch5/.
3. medals_sheet.jpg: the 13 medals at 256 px on white and on the app's
   dark surface (#101416).

Deterministic: the same PNGs give the same text.
"""

from __future__ import annotations

import io
import os
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
PNG = REPO / "build/medals/png"
WEBP = REPO / "build/medals/webp"
SOURCE = REPO / "docs/design/medals/source"
OUT = Path(os.environ.get("BATCH5_OUT", REPO / "docs/design/batch5"))

THEMES = ("green_slope", "ember_peak", "glacier_peak", "red_canyon")
TIERS = ("gold", "silver", "bronze")
NAMES = [f"medal_{t}_{r}" for t in THEMES for r in TIERS] + ["medal_welcome"]
SIZES = (256, 384, 512)
QUALITIES = (80, 90)
CUT = 40  # build_medals.crop_alpha's visible cut


def bbox(alpha: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(alpha > CUT)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def body_box(tier: str, size: int) -> tuple[float, float, float, float]:
    """The body's visible box on the source canvas, scaled to [size]."""
    im = Image.open(SOURCE / f"medal-ranks/medal_{tier}.png").convert("RGBA")
    k = size / im.width
    return tuple(v * k for v in bbox(np.asarray(im)[..., 3]))


def premul(im: Image.Image) -> np.ndarray:
    a = np.asarray(im.convert("RGBA")).astype(float)
    return np.concatenate([a[..., :3] * a[..., 3:] / 255, a[..., 3:]], axis=-1)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lines = [
        "Batch 5 Batch 0: the composed medals (tool/medals/medal_assets.py).",
        "Inputs: build/medals/png, 768 px, from build_medals.py (13 images).",
        "",
        "1. Geometry. Body circle = the body source's visible box (alpha > 40),",
        "scaled to 768 px. Overflow = how far the visible medal (alpha > 40)",
        "reaches past that box, as a share of the circle's diameter. Box = the",
        "visible medal's width and height over the circle's diameter. Past the",
        "disc = the farthest visible pixel beyond the round disc (not its",
        "bounding square), as a share of the diameter; outside = the share of",
        "visible pixels outside the disc (what a circular clip would cut).",
        "",
        "medal                         circle (px)          overflow top / bottom / left / right   box w x h       past the disc  outside",
    ]
    geometry = {}
    for name in NAMES:
        im = Image.open(PNG / f"{name}.png")
        size = im.width
        tier = "welcome" if name == "medal_welcome" else name.rsplit("_", 1)[1]
        cl, ct, cr, cb = body_box(tier, size)
        d = ((cr - cl) + (cb - ct)) / 2
        alpha = np.asarray(im)[..., 3]
        l, t, r, b = bbox(alpha)
        over = (max(0.0, ct - t) / d, max(0.0, b - cb) / d, max(0.0, cl - l) / d, max(0.0, r - cr) / d)
        # Past the round disc itself (not its bounding square): the
        # farthest visible pixel from the circle's centre, and the share of
        # visible pixels outside the disc (what a circular clip would cut).
        ys, xs = np.nonzero(alpha > CUT)
        rad = np.hypot(xs + .5 - (cl + cr) / 2, ys + .5 - (ct + cb) / 2)
        radial = max(0.0, float(rad.max()) - d / 2) / d
        outside = float((rad > d / 2 + 1).mean())
        geometry[name] = (d, over, ((r - l) / d, (b - t) / d), radial, outside)
        lines.append(
            f"{name:29} {cr - cl:6.1f} x {cb - ct:6.1f}       "
            f"{over[0]:.3f} / {over[1]:.3f} / {over[2]:.3f} / {over[3]:.3f}"
            f"             {(r - l) / d:.3f} x {(b - t) / d:.3f}     {radial:.3f}        {outside * 100:4.1f} %")
    monthly = [geometry[n] for n in NAMES if n != "medal_welcome"]
    worst_top = max(g[1][0] for g in monthly)
    w = geometry["medal_welcome"]
    lines += [
        "",
        f"Monthly medals: the stars need up to {worst_top:.3f} of the diameter above the circle;",
        "no other side reaches past it (the body's own shadow is inside the box).",
        f"Welcome: the ribbon needs {w[1][0]:.3f} above, {w[1][2]:.3f} left and {w[1][3]:.3f} right of the",
        "circle's bounding square: it crosses the round outline at the top corners",
        f"(up to {w[3]:.3f} D past the disc) but stays inside the square.",
        f"Monthly: the stars reach up to {max(g[3] for g in monthly):.3f} D past the disc.",
        "So, for a medal whose circle is D pt across:",
        f"- monthly, circle kept at D: a box {max(g[2][0] for g in monthly):.3f} D wide and "
        f"{max(g[2][1] for g in monthly):.3f} D tall (stars above);",
        f"- Welcome, circle kept at D: {w[2][0]:.3f} D wide and {w[2][1]:.3f} D tall;",
        f"- the whole image fitted in a square box S: the circle is "
        f"{1 / max(max(g[2]) for g in monthly):.3f} S (monthly) and {1 / max(w[2]):.3f} S (Welcome).",
        "",
        "2. App asset candidates: lossy WebP, alpha lossless (libwebp default), method 6.",
        "error = |WebP - Lanczos PNG at the same size| over pixels with alpha > 0,",
        "premultiplied, 0-255: mean / 99th percentile.",
        "",
        "px    quality  one medal (bytes, min-max)   all 13 (KB)   error mean / p99 (worst medal)",
    ]
    for px in SIZES:
        for q in QUALITIES:
            sizes, means, p99s = [], [], []
            for name in NAMES:
                ref = Image.open(PNG / f"{name}.png").convert("RGBA").resize((px, px), Image.LANCZOS)
                buf = io.BytesIO()
                ref.save(buf, "WEBP", quality=q, method=6)
                sizes.append(buf.tell())
                back = Image.open(io.BytesIO(buf.getvalue())).convert("RGBA")
                a, b = premul(ref), premul(back)
                vis = np.asarray(ref)[..., 3] > 0
                diff = np.abs(a - b)[vis]
                means.append(float(diff.mean()))
                p99s.append(float(np.percentile(diff, 99)))
                if q == 90:
                    (WEBP / str(px)).mkdir(parents=True, exist_ok=True)
                    (WEBP / str(px) / f"{name}.webp").write_bytes(buf.getvalue())
            lines.append(
                f"{px:<5} {q:>7}  {min(sizes):>7} - {max(sizes):<7}          {sum(sizes) / 1000:>7.1f}"
                f"       {max(means):.2f} / {max(p99s):.1f}")
    png_total = sum((PNG / f"{n}.png").stat().st_size for n in NAMES)
    lines += ["", f"For scale: the 13 composed PNGs at 768 px are {png_total / 1e6:.2f} MB.",
              "The climb's assets today: 8 backgrounds (1536 x 2048 WebP) and the objects;",
              "see docs/design/batch5/batch0-report.md section 1 for the bundle total."]
    (OUT / "medal_assets.txt").write_text("\n".join(lines) + "\n")
    side = 256
    sheet = Image.new("RGB", (side * 6 + 24, side * 5), (255, 255, 255))
    for i, name in enumerate(NAMES):
        im = Image.open(PNG / f"{name}.png").convert("RGBA").resize((side, side), Image.LANCZOS)
        r, c = divmod(i, 3)
        sheet.paste(im, (c * side, r * side), im)
        dark = Image.new("RGBA", (side, side), (16, 20, 22, 255))
        dark.alpha_composite(im)
        sheet.paste(dark.convert("RGB"), (side * 3 + 24 + c * side, r * side))
    sheet.save(OUT / "medals_sheet.jpg", quality=86)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
