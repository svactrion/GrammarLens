"""Scene Art Batch 0, step 2: the trail's center line, its bends and the
six clearings, from green/background_light.png.

    build/scene_art_venv/bin/python tool/scene_art/extract_trail.py

Writes, under docs/design/scene-art/batch0/:
  trail_green.json      the polyline (normalized), widths, bends, clearings,
                        and the 28-31-day step tables
  trail_numbers.txt     the figures the report quotes
  verify_trail.jpg      the center line, 31 steps and 6 clearings drawn on
                        the image
"""

from __future__ import annotations

import warnings

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import trail as T

warnings.filterwarnings("ignore", category=RuntimeWarning)  # skimage rgb2lab on numpy 2


def font(size: int) -> ImageFont.FreeTypeFont:
    for f in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def r(v, n=4):
    return round(float(v), n)


def main() -> None:
    src = T.SOURCE / "green/background_light.png"
    t = T.extract(src)
    w, h = t.size
    bends = T.bends(t)
    clear = T.clearings(t)
    c = t.cumulative()
    L = t.length_px

    lines = []
    out = lines.append
    out(f"image: {t.image}  {w} x {h} px")
    out(f"trail colour (Lab median): {np.round(t.ref, 1).tolist()}")
    out(f"polyline points: {len(t.points)} (every {r(0.0025 * h, 2)} px = 0.0025 of height)")
    out(f"arc length: {r(L, 1)} px; {r(L / h)} of height; {r(L / w)} of width")
    nlen = float(np.linalg.norm(np.diff(t.norm, axis=0), axis=1).sum())
    out(f"arc length in normalized (x/w, y/h) space: {r(nlen)}")
    out(f"start (foot): px {np.round(t.points[0], 1).tolist()}  norm {np.round(t.norm[0], 4).tolist()}")
    out(f"end (summit): px {np.round(t.points[-1], 1).tolist()}  norm {np.round(t.norm[-1], 4).tolist()}")
    # Widths: the round caps at both ends are not trail width; skip one
    # median width at each end.
    med = float(np.median(t.widths))
    body = (c > med) & (c < L - med)
    wd = t.widths[body]
    out("trail width across (px, image space; caps excluded):")
    out(f"  min {r(wd.min(), 1)}  median {r(np.median(wd), 1)}  max {r(wd.max(), 1)}")
    out(f"  normalized by width: min {r(wd.min() / w)}  median {r(np.median(wd) / w)}  max {r(wd.max() / w)}")
    # Where the trail is narrowest/widest, as an arc fraction.
    i_min, i_max = np.argmin(np.where(body, t.widths, np.inf)), np.argmax(np.where(body, t.widths, -1))
    out(f"  narrowest at arc {r(c[i_min] / L, 3)} (y {r(t.norm[i_min, 1], 3)}), widest at arc {r(c[i_max] / L, 3)} (y {r(t.norm[i_max, 1], 3)})")
    # Width by tenth of the trail (perspective: farther is narrower).
    tenths = []
    for k in range(10):
        sel = body & (c >= L * k / 10) & (c < L * (k + 1) / 10)
        tenths.append(r(np.median(t.widths[sel]), 1) if sel.any() else None)
    out(f"  median width per tenth of arc, foot to summit: {tenths}")
    out(f"bends: {len(bends)} (a bend = the horizontal direction reverses by > 2% of width)")
    for i, b in enumerate(bends, 1):
        out(f"  B{i} {b['side']:5s} apex px {b['px']}  norm {b['norm']}  arc {b['arc_fraction']}")
    out("clearings (automatic: the flat region beyond each bend's outer edge):")
    for i, cl in enumerate(clear, 1):
        if cl.get("missing"):
            out(f"  C{i} MISSING at bend {cl['bend']['norm']}")
            continue
        s, d = T.nearest_arc(t, cl["center_px"])
        out(f"  C{i} {cl['side']:5s} (bend B{i}) center px {cl['center_px']} norm {cl['center_norm']}  "
            f"box px {cl['box_px']} norm {cl['box_norm']}  area {cl['area_px']} px  "
            f"nearest trail arc {r(s / L, 3)} at {r(d, 1)} px")
    out("steps, evenly by arc length (day 0 = foot, last day = summit):")
    tables = {}
    for days in (28, 29, 30, 31):
        st = t.steps(days)
        gap = L / days
        tables[str(days)] = [[r(x / w, 5), r(y / h, 5)] for x, y in st]
        out(f"  {days} days: {r(gap, 1)} px per step along the trail ({r(gap / h, 5)} of height)")
    st31 = t.steps(31)
    straight = np.linalg.norm(np.diff(st31, axis=0), axis=1)
    out(f"  31 days, straight-line distance between neighbours: min {r(straight.min(), 1)} px  max {r(straight.max(), 1)} px")
    # Which step is nearest each clearing (31 days).
    for i, cl in enumerate(clear, 1):
        if cl.get("missing"):
            continue
        s, _ = T.nearest_arc(t, cl["center_px"])
        out(f"  C{i} nearest day: 28d {round(s / L * 28)}, 29d {round(s / L * 29)}, 30d {round(s / L * 30)}, 31d {round(s / L * 31)}")

    T.write_json(T.OUT / "trail_green.json", {
        "source": t.image,
        "generator": "tool/scene_art/extract_trail.py",
        "image_size_px": [w, h],
        "coordinates": "normalized: x / width, y / height, origin top left",
        "polyline": [[r(x, 5), r(y, 5)] for x, y in t.norm],
        "width_px": [r(v, 1) for v in t.widths],
        # The trail's horizontal width through each point (Stage 1, G3: an
        # upright avatar's footprint lies along x on any leg).
        "chord_px": [r(T.horizontal_chord(t.mask, p), 1) for p in t.points],
        # The run's left and right edge (Stage 2: save points must not
        # touch the trail).
        "run_px": [[r(v, 1) for v in T.horizontal_run(t.mask, p)] for p in t.points],
        "arc_length_px": r(L, 2),
        "bends": bends,
        "clearings": clear,
        "steps": tables,
    })
    (T.OUT / "trail_numbers.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))

    # Verification image, at half size (1086 px).
    k = 0.5
    im = Image.open(src).convert("RGB").resize((round(w * k), round(h * k)), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    p = t.points * k
    d.line([tuple(q) for q in p], fill=(220, 30, 30), width=3)
    f_small, f_big = font(15), font(22)
    for i, cl in enumerate(clear, 1):
        if cl.get("missing"):
            continue
        cx, cy = np.array(cl["center_px"]) * k
        bw, bh = np.array(cl["box_px"]) * k
        d.ellipse([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], outline=(30, 90, 255), width=3)
        d.text((cx, cy), f"C{i}", fill=(255, 255, 255), font=f_big, anchor="mm", stroke_width=3, stroke_fill=(30, 90, 255))
    for i, b in enumerate(bends, 1):
        bx, by = np.array(b["px"]) * k
        d.text((bx, by - 26), f"B{i}", fill=(255, 255, 255), font=f_small, anchor="mm", stroke_width=3, stroke_fill=(0, 0, 0))
    for day, (x, y) in enumerate(st31 * k):
        rad = 6
        if day == 0:
            d.ellipse([x - rad, y - rad, x + rad, y + rad], outline=(0, 0, 0), width=3)
        else:
            d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(255, 210, 0), outline=(0, 0, 0), width=2)
        if day % 5 == 0 or day in (1, 31):
            d.text((x + 10, y - 10), str(day), fill=(0, 0, 0), font=f_small, stroke_width=3, stroke_fill=(255, 255, 255))
    d.text((12, 12), "Green light: center line (red), 31-day steps (yellow, day 0 ring), clearings C1-C6 (blue), bends B1-B6",
           fill=(0, 0, 0), font=f_small, stroke_width=3, stroke_fill=(255, 255, 255))
    im.save(T.OUT / "verify_trail.jpg", quality=88)


if __name__ == "__main__":
    main()
