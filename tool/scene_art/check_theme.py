"""Does a theme image keep the shared trail, clearings and START flag?

Decision S4: every theme background has its trail, clearings and START flag
at the same place, so one coordinate set (Green Slope's) serves them all.
Run it on every new theme image:

    build/scene_art_venv/bin/python tool/scene_art/check_theme.py \\
        green/background_dark.png ember/background_light.png

Paths are relative to docs/design/scene-art/source/, or absolute. With no
arguments it checks green/background_dark.png. Exit code 1 if any image
fails. Writes theme_check.txt and theme_check.jpg (the reference's centre
line, edge points and clearings over each image) to
docs/design/scene-art/batch0/, or to SCENE_ART_OUT.

**Verified at Green's known positions, not re-detected (Batch 4, 2026-10-02).**
The first version re-ran the trail and clearing extraction on each image
and compared the results. That extraction is tuned on Green (the trail's
colour against grass, the clearings' flatness against grass and rock):
on the Batch 4 themes it failed on images that are in fact aligned. Ember's
C6 lies on dark rock as flat as itself, the canyon's trail mask leaked
into sand of the same colour, and on glacier and canyon the clearings
touch the trail with no grass rim, so growing them by colour pulled their
centres 12–14 px toward it (crops: docs/design/scene-art/batch4/check/).
Every START flag there was within 2 px. So the image is now asked about
Green's positions:

1. TRAIL: is Green's centre line on this image's trail? At 600 points
   (3–97 % of its length) the colour (Lab, 3 × 3 median) is compared with
   the image's own trail colour, the median over those points; and the two
   points at ± EDGE of the half width across the trail are compared with
   the centre's colour. A trail elsewhere, or none, fails the first; a
   shift or scale of a few dozen px moves the edge points off the trail
   and fails the second.
2. CLEARINGS: is there flat ground inside each of Green's six clearings?
   The median local L* deviation (8 px window at 1086 px) over the inner
   60 % of the clearing's ellipse.
3. FLAG: the START flag's offset by edge correlation, unchanged, exact to
   the pixel; it catches small rigid shifts the other two let through.

**Batch 6, M22: the K-c blurred backdrops.** With `--blur` it instead checks
the eight assets/climb/<theme>/background_<mode>_blur.webp: each exists and
is up to date with its source, i.e. export_blur.py, run now on the same
source with the same settings, gives the same bytes (or, if the encoder
changed, pixels within MAX_BLUR_DIFF). Exit code 1 if any fails. Writes
docs/design/batch6/blur/blur_check.txt.

    build/scene_art_venv/bin/python tool/scene_art/check_theme.py --blur
"""

from __future__ import annotations

import sys
import warnings
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.signal import fftconvolve
from skimage.color import rgb2lab

import trail as T

warnings.filterwarnings("ignore", category=RuntimeWarning)

REFERENCE = "green/background_light.png"

# Thresholds, from the seven real images and the deliberate breaks
# (batch4/theme_check.txt, theme_check_break.txt):
# - centre on the trail: every real image has 100 % of the 600 points
#   within ΔE 20 of its trail colour (the 95th percentile is at most 5.4);
#   99 % allows a few points on painted details.
CENTRE_DELTA_E = 20.0
MIN_CENTRE_SHARE = 0.99
# - edge points at ± 0.6 of the half width: every real image 100 % within
#   ΔE 15 of the centre; a 20 px shift gives 98.0 %, a 1.5 % scale 97.2 %,
#   so 99 % separates them (an 8 px shift gives 99.7 % and is the flag's).
EDGE = 0.6
EDGE_DELTA_E = 15.0
MIN_EDGE_SHARE = 0.99
# - clearings: median local L* deviation at most 1.0 (the extraction's
#   flatness limit); the seven real images measure 0.10–0.73.
MAX_CLEARING_SD = 1.0
# - flag: unchanged, about 6 px at 2896 (real images: 0–2 px).
MAX_FLAG_SHIFT = 0.002

# The START flag's search box, normalized, placed by hand around the flag
# in the reference (it is not detected).
FLAG_BOX = (0.10, 0.76, 0.24, 0.87)


def lab_of(path_or_image, size) -> np.ndarray:
    im = path_or_image if isinstance(path_or_image, Image.Image) else Image.open(path_or_image)
    im = im.convert("RGB")
    if im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return rgb2lab(np.asarray(im).astype(float) / 255)


def sample(lab: np.ndarray, pts: np.ndarray) -> np.ndarray:
    h, w = lab.shape[:2]
    out = []
    for x, y in pts:
        x = int(np.clip(round(x), 1, w - 2))
        y = int(np.clip(round(y), 1, h - 2))
        out.append(np.median(lab[y - 1:y + 2, x - 1:x + 2].reshape(-1, 3), 0))
    return np.array(out)


def flatness(lab: np.ndarray) -> tuple[np.ndarray, float]:
    f = 1086 / lab.shape[1]
    L = ndimage.zoom(lab[..., 0], f, order=1)
    m = ndimage.uniform_filter(L, 8)
    m2 = ndimage.uniform_filter(L * L, 8)
    return np.sqrt(np.maximum(m2 - m * m, 0)), f


def edges(lab: np.ndarray, box, size) -> np.ndarray:
    w, h = size
    x0, y0, x1, y1 = (int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))
    L = lab[y0:y1, x0:x1, 0]
    g = np.hypot(ndimage.sobel(L, 0), ndimage.sobel(L, 1))
    return (g - g.mean()) / (g.std() + 1e-9)


def flag_shift(ref_lab: np.ndarray, lab: np.ndarray, size) -> tuple[float, float]:
    """Offset (px) that best aligns the START flag's edges, by
    cross-correlation within the search box."""
    a = edges(ref_lab, FLAG_BOX, size)
    m = 30  # search ±30 px
    box = (FLAG_BOX[0] - m / size[0], FLAG_BOX[1] - m / size[1],
           FLAG_BOX[2] + m / size[0], FLAG_BOX[3] + m / size[1])
    b = edges(lab, box, size)
    corr = fftconvolve(b, a[::-1, ::-1], mode="valid")
    dy, dx = np.unravel_index(np.argmax(corr), corr.shape)
    return float(dx - m), float(dy - m)


class Reference:
    def __init__(self) -> None:
        self.trail = T.extract(T.SOURCE / REFERENCE)
        self.size = self.trail.size
        self.lab = self.trail.lab
        self.clearings = T.clearings(self.trail)
        L = self.trail.length_px
        s = np.linspace(L * 0.03, L * 0.97, 600)
        self.points = self.trail.at(s)
        half = self.trail.width_at(s)[:, None] / 2
        tan = np.gradient(self.points, axis=0)
        tan /= np.linalg.norm(tan, axis=1, keepdims=True)
        normal = np.stack([-tan[:, 1], tan[:, 0]], 1)
        self.edges = [self.points + normal * half * EDGE, self.points - normal * half * EDGE]


def check(ref: Reference, image) -> dict:
    lab = lab_of(image, ref.size)
    centre = sample(lab, ref.points)
    colour = np.median(centre, 0)
    d_centre = np.linalg.norm(centre - colour, axis=1)
    d_edge = np.max([np.linalg.norm(sample(lab, e) - centre, axis=1) for e in ref.edges], 0)
    sd, f = flatness(lab)
    yy, xx = np.mgrid[0:sd.shape[0], 0:sd.shape[1]]
    clearing_sd = []
    for c in ref.clearings:
        (cx, cy), (bw, bh) = c["center_px"], c["box_px"]
        inner = ((xx / f - cx) / (bw / 2)) ** 2 + ((yy / f - cy) / (bh / 2)) ** 2 <= 0.36
        clearing_sd.append(float(np.median(sd[inner])))
    fx, fy = flag_shift(ref.lab, lab, ref.size)
    H = ref.size[1]
    r = {
        "centre_share": float(np.mean(d_centre < CENTRE_DELTA_E)),
        "centre_p95": float(np.percentile(d_centre, 95)),
        "edge_share": float(np.mean(d_edge < EDGE_DELTA_E)),
        "edge_p95": float(np.percentile(d_edge, 95)),
        "clearing_sd": clearing_sd,
        "flag": (fx, fy),
        "flag_h": float(np.hypot(fx, fy)) / H,
        "edge_fail_points": ref.points[d_edge >= EDGE_DELTA_E],
    }
    r["checks"] = {
        "trail centre": r["centre_share"] >= MIN_CENTRE_SHARE,
        "trail edges": r["edge_share"] >= MIN_EDGE_SHARE,
        "clearings": all(v <= MAX_CLEARING_SD for v in clearing_sd),
        "flag": r["flag_h"] <= MAX_FLAG_SHIFT,
    }
    r["ok"] = all(r["checks"].values())
    return r


def describe(name: str, r: dict) -> list[str]:
    fx, fy = r["flag"]
    return [
        f"{name}: {'PASS' if r['ok'] else 'FAIL'}",
        f"  trail centre: {r['centre_share']:.1%} of 600 points within ΔE {CENTRE_DELTA_E:g} of its trail colour "
        f"(p95 {r['centre_p95']:.1f})",
        f"  trail edges (±{EDGE:g} of the half width): {r['edge_share']:.1%} within ΔE {EDGE_DELTA_E:g} of the centre "
        f"(p95 {r['edge_p95']:.1f})",
        "  clearing flatness (median L* deviation): "
        + " ".join(f"C{i} {v:.2f}" for i, v in enumerate(r["clearing_sd"], 1)),
        f"  START flag offset: dx {fx:+.0f} px, dy {fy:+.0f} px ({r['flag_h']:.5f} h)",
        "  " + ", ".join(f"{k}: {'ok' if v else 'FAIL'}" for k, v in r["checks"].items()),
    ]


def overlay(ref: Reference, image, r: dict) -> Image.Image:
    im = image if isinstance(image, Image.Image) else Image.open(image)
    im = im.convert("RGB").resize((1086, round(1086 * ref.size[1] / ref.size[0])), Image.LANCZOS)
    k = 1086 / ref.size[0]
    d = ImageDraw.Draw(im)
    d.line([tuple(p) for p in ref.trail.points * k], fill=(255, 40, 40), width=2)
    for e in ref.edges:
        for p in e[::6] * k:
            d.ellipse([p[0] - 1.5, p[1] - 1.5, p[0] + 1.5, p[1] + 1.5], fill=(255, 255, 255))
    for p in r["edge_fail_points"] * k:
        d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], outline=(255, 0, 255), width=2)
    for c in ref.clearings:
        (cx, cy), (bw, bh) = np.array(c["center_px"]) * k, np.array(c["box_px"]) * k
        d.ellipse([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], outline=(0, 220, 255), width=2)
    fx, fy = r["flag"]
    d.rectangle([FLAG_BOX[0] * 1086 + fx * k, FLAG_BOX[1] * im.height + fy * k,
                 FLAG_BOX[2] * 1086 + fx * k, FLAG_BOX[3] * im.height + fy * k], outline=(255, 255, 255), width=2)
    return im


def run(images: list[tuple[str, object]], out_txt: str = "theme_check.txt",
        out_jpg: str | None = "theme_check.jpg") -> int:
    ref = Reference()
    lines = [f"reference: {REFERENCE} {ref.size[0]} x {ref.size[1]} px; checked at its positions",
             f"thresholds: trail centre ≥ {MIN_CENTRE_SHARE:.0%} within ΔE {CENTRE_DELTA_E:g}; "
             f"edges ≥ {MIN_EDGE_SHARE:.0%} within ΔE {EDGE_DELTA_E:g}; clearings ≤ {MAX_CLEARING_SD:g}; "
             f"flag ≤ {MAX_FLAG_SHIFT} h", ""]
    failed, sheet = False, []
    for name, image in images:
        r = check(ref, image)
        failed |= not r["ok"]
        lines += describe(name, r) + [""]
        if out_jpg:
            sheet.append(overlay(ref, image, r))
    T.OUT.mkdir(parents=True, exist_ok=True)
    (T.OUT / out_txt).write_text("\n".join(lines))
    print("\n".join(lines))
    if out_jpg and sheet:
        W = sum(i.width for i in sheet) + 10 * (len(sheet) - 1)
        canvas = Image.new("RGB", (W, max(i.height for i in sheet)), "white")
        x = 0
        for i in sheet:
            canvas.paste(i, (x, 0))
            x += i.width + 10
        canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS).save(T.OUT / out_jpg, quality=85)
    return 1 if failed else 0


# --blur: how far a re-made backdrop may differ, per channel (0–255), when
# its bytes differ (another libwebp); beyond it the asset is stale.
MAX_BLUR_DIFF = 2


def check_blur() -> int:
    import io

    import export_blur as B
    from export_assets import THEMES

    lines = ["Batch 6 M22: the K-c blurred backdrops against their sources", ""]
    failed = False
    for folder, theme in THEMES:
        for mode in B.MODES:
            path = B.asset_path(theme, mode)
            name = path.relative_to(T.REPO)
            if not path.exists():
                lines.append(f"FAIL {name}: missing")
                failed = True
                continue
            fresh = B.make_blur(folder, mode)
            stored = path.read_bytes()
            if fresh == stored:
                lines.append(f"ok   {name}: same bytes as export_blur.py makes now")
                continue
            a = np.asarray(Image.open(io.BytesIO(fresh)).convert("RGB"), dtype=np.int16)
            b = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
            diff = int(np.abs(a - b).max()) if a.shape == b.shape else 255
            ok = diff <= MAX_BLUR_DIFF
            failed |= not ok
            lines.append(f"{'ok  ' if ok else 'FAIL'} {name}: bytes differ, max pixel difference {diff}")
    out = T.REPO / "docs/design/batch6/blur"
    out.mkdir(parents=True, exist_ok=True)
    (out / "blur_check.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    if argv == ["--blur"]:
        return check_blur()
    names = argv or ["green/background_dark.png"]
    images = []
    for n in names:
        p = Path(n)
        p = p if p.is_absolute() else T.SOURCE / n
        label = n if not Path(n).is_absolute() else f"{p.parent.name}/{p.name}"
        images.append((label, p))
    return run(images)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
