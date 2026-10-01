"""Scene Art Batch 0, step 2.5: does a theme image keep the shared trail?

Decision S4: every theme background has its trail, clearings and START flag
at the same place, so one coordinate set serves them all. This runs the
same extraction on each image and compares it with the reference
(green/background_light.png). Run it on every new theme image:

    build/scene_art_venv/bin/python tool/scene_art/check_theme.py \
        green/background_dark.png volcanic/background_light.png

Paths are relative to docs/design/scene-art/source/. With no arguments it
checks the two images above. Exit code 1 if any image fails a threshold.
Writes docs/design/scene-art/batch0/theme_check.txt and theme_check.jpg
(each image's center line and clearings over the reference's).
"""

from __future__ import annotations

import sys
import warnings

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.signal import fftconvolve

import trail as T

warnings.filterwarnings("ignore", category=RuntimeWarning)

REFERENCE = "green/background_light.png"

# Proposed thresholds, as a share of the image height (so they hold at any
# resolution). 0.004 was tried first; volcanic measured 0.0042 at bend B2,
# where the crop (theme_check_worst_*.jpg) shows the trail's edges
# coinciding and the center line moving with how the inner rim is
# segmented. 0.005 h is about 14 px at 2896 px, a fifth of the median trail
# width, and under 3 pt in the K-a framing at 430 pt (report, step 3).
MAX_TRAIL_DEVIATION = 0.005  # largest distance between the two center lines
MEAN_TRAIL_DEVIATION = 0.0015
MAX_END_SHIFT = 0.012  # each end point; looser, see trail.compare
# The flag's offset is exact to the pixel (an edge correlation, not a
# segmentation): 0 px dark, 1 px volcanic, so it carries the tight limit
# that catches a small rigid shift the trail line's noise would hide (an
# 8 px shifted copy passes the trail limits and fails this one).
MAX_CLEARING_SHIFT = 0.004  # a clearing's center (measured: up to 0.002)
MAX_FLAG_SHIFT = 0.002  # the START flag, about 6 px at 2896

# The START flag's search box, normalized, placed by hand around the flag
# in the reference (it is not detected).
FLAG_BOX = (0.10, 0.76, 0.24, 0.87)


def edges(lab: np.ndarray, box, size) -> np.ndarray:
    w, h = size
    x0, y0, x1, y1 = (int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))
    L = lab[y0:y1, x0:x1, 0]
    g = np.hypot(ndimage.sobel(L, 0), ndimage.sobel(L, 1))
    return (g - g.mean()) / (g.std() + 1e-9)


def flag_shift(ref: T.Trail, other: T.Trail) -> tuple[float, float]:
    """Offset (px, in the reference's pixels) that best aligns the START
    flag's edges, by cross-correlation within the search box."""
    lab = other.lab
    if other.size != ref.size:
        f = (ref.size[1] / other.size[1], ref.size[0] / other.size[0], 1)
        lab = ndimage.zoom(lab, f, order=1)
    a = edges(ref.lab, FLAG_BOX, ref.size)
    m = 30  # search ±30 px
    box = (FLAG_BOX[0] - m / ref.size[0], FLAG_BOX[1] - m / ref.size[1],
           FLAG_BOX[2] + m / ref.size[0], FLAG_BOX[3] + m / ref.size[1])
    b = edges(lab, box, ref.size)
    corr = fftconvolve(b, a[::-1, ::-1], mode="valid")
    dy, dx = np.unravel_index(np.argmax(corr), corr.shape)
    return float(dx - m), float(dy - m)


def main(argv: list[str]) -> int:
    names = argv or ["green/background_dark.png", "volcanic/background_light.png"]
    T.OUT.mkdir(parents=True, exist_ok=True)
    ref = T.extract(T.SOURCE / REFERENCE)
    ref_clear = T.clearings(ref)
    H = ref.size[1]
    lines = [f"reference: {REFERENCE} {ref.size[0]} x {ref.size[1]} px; "
             f"px below are the reference's pixels; 'h' = share of its height",
             f"thresholds: trail body max {MAX_TRAIL_DEVIATION} h, mean {MEAN_TRAIL_DEVIATION} h, "
             f"ends {MAX_END_SHIFT} h, "
             f"clearing {MAX_CLEARING_SHIFT} h, flag {MAX_FLAG_SHIFT} h"]
    failed = False
    k = 1086 / ref.size[0]
    sheet = []
    for name in names:
        t = T.extract(T.SOURCE / name)
        cmp = T.compare(ref, t)
        cl = T.clearings(t)
        sx = ref.size[0] / t.size[0]
        shifts = []
        for a, b in zip(ref_clear, cl):
            if a.get("missing") or b.get("missing"):
                shifts.append(None)
                continue
            d = np.subtract(np.array(b["center_norm"]) * ref.size, np.array(a["center_norm"]) * ref.size)
            shifts.append(float(np.hypot(*d)))
        fx, fy = flag_shift(ref, t)
        fshift = float(np.hypot(fx, fy))
        checks = {
            "trail max": cmp["max_px"] / H <= MAX_TRAIL_DEVIATION,
            "trail mean": cmp["mean_px"] / H <= MEAN_TRAIL_DEVIATION,
            "ends": max(cmp["start_px"], cmp["end_px"]) / H <= MAX_END_SHIFT,
            "clearings": all(s is not None and s / H <= MAX_CLEARING_SHIFT for s in shifts)
            and len(cl) == len(ref_clear),
            "flag": fshift / H <= MAX_FLAG_SHIFT,
        }
        ok = all(checks.values())
        failed |= not ok
        lines.append("")
        lines.append(f"{name}: {t.size[0]} x {t.size[1]} px (x{sx:g} to the reference)  {'PASS' if ok else 'FAIL'}")
        lines.append(f"  trail body (3-97 % of its length) deviation: max {cmp['max_px']} px ({cmp['max_px'] / H:.5f} h), "
                     f"mean {cmp['mean_px']} px ({cmp['mean_px'] / H:.5f} h), p95 {cmp['p95_px']} px")
        lines.append(f"  ends: start {cmp['start_px']} px, summit {cmp['end_px']} px; "
                     f"arc length ratio {cmp['length_ratio']}")
        lines.append("  clearing center shifts (px): " + ", ".join(
            f"C{i} " + ("missing" if s is None else f"{s:.1f}") for i, s in enumerate(shifts, 1)))
        lines.append(f"  START flag offset: dx {fx:+.0f} px, dy {fy:+.0f} px ({fshift / H:.5f} h)")
        lines.append("  " + ", ".join(f"{k_}: {'ok' if v else 'FAIL'}" for k_, v in checks.items()))

        # Overlay: reference line (red) and this image's (cyan) on this image.
        im = Image.open(T.SOURCE / name).convert("RGB").resize((1086, round(1086 * t.size[1] / t.size[0])), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.line([tuple(q) for q in ref.points * k], fill=(255, 40, 40), width=5)
        d.line([tuple(q) for q in t.points * (1086 / t.size[0])], fill=(0, 230, 255), width=2)
        for c_ in cl:
            if c_.get("missing"):
                continue
            cx, cy = np.array(c_["center_norm"]) * [1086, im.height]
            bw, bh = np.array(c_["box_norm"]) * [1086, im.height]
            d.ellipse([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], outline=(0, 230, 255), width=2)
        for c_ in ref_clear:
            cx, cy = np.array(c_["center_norm"]) * [1086, im.height]
            d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 40, 40))
        d.rectangle([FLAG_BOX[0] * 1086 + fx * k, FLAG_BOX[1] * im.height + fy * k,
                     FLAG_BOX[2] * 1086 + fx * k, FLAG_BOX[3] * im.height + fy * k], outline=(255, 255, 255), width=2)
        sheet.append(im)

        # The worst point of the body, cropped from both images (600 px
        # square at the reference's scale), both lines drawn.
        span = np.linspace(ref.length_px * 0.03, ref.length_px * 0.97, 1000)
        pa = ref.at(span)
        qb = t.points * np.array(ref.size) / np.array(t.size)
        dev = np.array([np.min(np.linalg.norm(qb - p, axis=1)) for p in pa])
        cx, cy = pa[int(np.argmax(dev))].astype(int)
        crops = []
        for img_name, im_size in ((REFERENCE, ref.size), (name, t.size)):
            full = Image.open(T.SOURCE / img_name).convert("RGB")
            if im_size != ref.size:
                full = full.resize(ref.size, Image.LANCZOS)
            crop = full.crop((cx - 300, cy - 300, cx + 300, cy + 300))
            dd = ImageDraw.Draw(crop)
            dd.line([tuple(q - [cx - 300, cy - 300]) for q in ref.points], fill=(255, 40, 40), width=3)
            dd.line([tuple(q - [cx - 300, cy - 300]) for q in qb], fill=(0, 200, 255), width=3)
            crops.append(crop)
        pair = Image.new("RGB", (1210, 600), "white")
        pair.paste(crops[0], (0, 0))
        pair.paste(crops[1], (610, 0))
        stem = Path(name).stem if Path(name).is_absolute() else name.replace("/", "_").removesuffix(".png")
        pair.save(T.OUT / f"theme_check_worst_{stem}.jpg", quality=85)
        lines.append(f"  worst body point: px ({cx}, {cy}), {dev.max():.1f} px; crop theme_check_worst_{stem}.jpg")
    T.OUT.mkdir(parents=True, exist_ok=True)
    (T.OUT / "theme_check.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if sheet:
        W = sum(i.width for i in sheet) + 10 * (len(sheet) - 1)
        out = Image.new("RGB", (W, max(i.height for i in sheet)), "white")
        x = 0
        for i in sheet:
            out.paste(i, (x, 0))
            x += i.width + 10
        out.resize((out.width // 2, out.height // 2), Image.LANCZOS).save(T.OUT / "theme_check.jpg", quality=85)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
