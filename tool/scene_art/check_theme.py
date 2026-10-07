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

**Batch 5, N18: the C5 signpost.** With `--signpost` it checks, in each
theme image (all eight sources when none are given), that the signpost
where the app draws it (assets/climb/objects/signpost.webp, the
placement's ratio) touches none of that image's own trail near C5. Exit
code 1 if any pixel touches. Writes docs/design/batch5/signpost/
signpost_check.txt and signpost_check.jpg (trail magenta, signpost
outline green, contact red).

    build/scene_art_venv/bin/python tool/scene_art/check_theme.py --signpost

`--signpost-break` runs its deliberate breaks in memory on
glacier/background_dark.png (back at the clearing's centre without N35's
shift, and moved 20 px down: each must touch; as placed it must not) and
writes signpost_check_break.txt.
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


# --signpost (Batch 5, N18): the C5 signpost, decoration placed by the save
# points' rule on Green's trail mask, must touch no trail in any theme.
SIGNPOST_IMAGES = [f"{t}/background_{m}.png" for t in ("green", "ember", "glacier", "canyon")
                   for m in ("light", "dark")]
# The local trail colour cut: the extraction's own ΔE (trail.py), on the
# image's trail colour around C5 (the median at Green's centre line there).
SIGNPOST_DELTA_E = 14.0
SIGNPOST_WINDOW = 300  # px at 2172 around C5's centre
SIGNPOST_ALPHA = 25  # the placement rule's cut (place_save_points.py)


def signpost_shape(size, ratio=None, dy=0) -> np.ndarray:
    """The signpost's visible pixels (alpha > 25) where the app draws it,
    at the reference's size: the asset, the placement's ratio (or
    [ratio]) and centre, the base 0.25 of C5's height below that centre."""
    import json

    p = json.loads((T.REPO / "docs/design/scene-art/stage2/placement.json").read_text())["decor"][0]
    return signpost_shape_at(size, ratio or p["ratio"], p["center_norm"], p["box_norm"], p["base_drop"], dy=dy)


def signpost_shape_at(size, ratio, centre, box, base_drop, dx=0, dy=0) -> np.ndarray:
    """The signpost's visible pixels with its centre at [centre]
    (normalized) moved by [dx], [dy] px, sized [ratio] of the clearing's
    width [box][0]."""
    W, H = size
    (cx, cy), (bw, bh) = centre, box
    src = Image.open(T.REPO / "assets/climb/objects/signpost.webp").convert("RGBA")
    wpx = bw * ratio * W
    im = src.resize((round(wpx), round(wpx * src.height / src.width)), Image.LANCZOS)
    left = round(cx * W - im.width / 2) + dx
    top = round((cy + base_drop * bh) * H - im.height) + dy
    out = np.zeros((H, W), bool)
    out[top:top + im.height, left:left + im.width] = np.asarray(im)[..., 3] > SIGNPOST_ALPHA
    return out


def local_trail(ref: Reference, lab: np.ndarray, box) -> np.ndarray:
    """The image's own trail near C5: pixels within ΔE 14 of its trail
    colour there, opened by 2 px, the regions that Green's centre line runs
    through. Checked per image, so a theme whose trail edge sits closer to
    the clearing than Green's shows it."""
    x0, y0, x1, y1 = box
    inside = np.array([(x, y) for x, y in ref.points if x0 <= x < x1 and y0 <= y < y1])
    colour = np.median(sample(lab, inside), 0)
    near = np.linalg.norm(lab[y0:y1, x0:x1] - colour, axis=2) < SIGNPOST_DELTA_E
    near = ndimage.binary_opening(near, iterations=2)
    labels, _ = ndimage.label(near)
    keep = set(int(labels[int(y) - y0, int(x) - x0]) for x, y in inside) - {0}
    out = np.zeros(lab.shape[:2], bool)
    out[y0:y1, x0:x1] = np.isin(labels, list(keep))
    return out


def check_signpost(names: list[str]) -> int:
    import json

    ref = Reference()
    W, H = ref.size
    p = json.loads((T.REPO / "docs/design/scene-art/stage2/placement.json").read_text())["decor"][0]
    cx, cy = p["center_norm"][0] * W, p["center_norm"][1] * H
    box = (int(cx - SIGNPOST_WINDOW), int(cy - SIGNPOST_WINDOW), int(cx + SIGNPOST_WINDOW), int(cy + SIGNPOST_WINDOW))
    shape = signpost_shape(ref.size)
    # A pixel at 2172 is 430 × 1.1 ÷ 2172 pt wide on the widest phone.
    pt = 391.3 * 1.1 / W
    lines = ["Batch 5 N18: does the C5 signpost touch the trail? (check_theme.py --signpost)",
             f"signpost: {p['object']} on {p['clearing']} at ratio {p['ratio']}, {int(shape.sum())} visible px "
             f"(alpha > {SIGNPOST_ALPHA}) at {W} px; trail: each image's own, within ΔE {SIGNPOST_DELTA_E:g} of its "
             f"trail colour near C5. Pass: 0 px.",
             f"1 px at {W} is {pt:.3f} pt on a 430 pt phone ({pt * pt:.3f} pt² of area).", ""]
    failed, tiles = False, []
    for n in names:
        lab = lab_of(T.SOURCE / n, ref.size)
        trail = local_trail(ref, lab, box)
        contact = trail & shape
        k = int(contact.sum())
        failed |= k > 0
        lines.append(f"{'ok  ' if k == 0 else 'FAIL'} {n}: {k} px of the signpost on the trail"
                     + ("" if k == 0 else f" ({k * pt * pt:.2f} pt² at 430 pt)"))
        im = np.asarray(Image.open(T.SOURCE / n).convert("RGB").resize(ref.size, Image.LANCZOS)).copy()
        im[trail] = (im[trail] * 0.5 + np.array([255, 0, 255]) * 0.5).astype(np.uint8)
        im[shape & ~ndimage.binary_erosion(shape)] = (0, 255, 0)
        im[ndimage.binary_dilation(contact, iterations=2)] = (255, 0, 0)
        tiles.append(Image.fromarray(im).crop(box).resize((300, 300), Image.LANCZOS))
    out = T.REPO / "docs/design/batch5/signpost"
    out.mkdir(parents=True, exist_ok=True)
    (out / "signpost_check.txt").write_text("\n".join(lines) + "\n")
    sheet = Image.new("RGB", (300 * 4 + 30, 300 * ((len(tiles) + 3) // 4) + 10 * ((len(tiles) - 1) // 4)), "white")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 4) * 310, (i // 4) * 310))
    sheet.save(out / "signpost_check.jpg", quality=85)
    print("\n".join(lines))
    return 1 if failed else 0


def check_signpost_breaks() -> int:
    """The signpost check's deliberate breaks, in memory, on the image that
    touched most before N35 (glacier/background_dark.png): the signpost back
    at its clearing's centre (without N35's shift) and moved 20 px down must
    each touch the trail; as placed it must not. Exit code 1 if a break goes
    unseen."""
    import json

    image = "glacier/background_dark.png"
    ref = Reference()
    W, H = ref.size
    p = json.loads((T.REPO / "docs/design/scene-art/stage2/placement.json").read_text())["decor"][0]
    cx, cy = p["center_norm"][0] * W, p["center_norm"][1] * H
    box = (int(cx - SIGNPOST_WINDOW), int(cy - SIGNPOST_WINDOW), int(cx + SIGNPOST_WINDOW), int(cy + SIGNPOST_WINDOW))
    trail = local_trail(ref, lab_of(T.SOURCE / image, ref.size), box)
    sx, sy = p.get("shift_px", [0, 0])
    lines = [f"Batch 5 N18, N35: the signpost check's deliberate breaks ({image}).", ""]
    missed = False
    for label, kw, must_touch in (
            (f"at the clearing's centre (shift {-sx}, {-sy} px undone)", {"dx": -sx, "dy": -sy}, True),
            ("moved 20 px down", {"dy": 20}, True),
            ("as placed (control)", {}, False)):
        shape = signpost_shape_at(ref.size, p["ratio"], p["center_norm"], p["box_norm"], p["base_drop"], **kw)
        k = int((trail & shape).sum())
        ok = (k > 0) == must_touch
        missed |= not ok
        lines.append(f"{'ok  ' if ok else 'MISS'} {label}: {k} px on the trail")
    out = T.REPO / "docs/design/batch5/signpost"
    (out / "signpost_check_break.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if missed else 0


def main(argv: list[str]) -> int:
    if argv == ["--signpost-break"]:
        return check_signpost_breaks()
    if argv == ["--blur"]:
        return check_blur()
    if argv[:1] == ["--signpost"]:
        return check_signpost(argv[1:] or SIGNPOST_IMAGES)
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
