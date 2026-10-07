"""Trail and clearing extraction from a scene-art background image.

Measuring code only (Scene Art Batch 0, docs/design/scene-art/batch0/):
nothing in lib/ imports it. Every function is deterministic, so the same
image always gives the same numbers.

Coordinates: pixels of the image being read, and "normalized" = x / width,
y / height (0-1, origin top left), so images of different sizes compare.
"""

from __future__ import annotations

import dataclasses
import json
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from skimage.color import rgb2lab
from skimage.morphology import disk, skeletonize

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "docs/design/scene-art/source"
# SCENE_ART_OUT redirects every output (used for the deliberate-break runs).
OUT = Path(os.environ.get("SCENE_ART_OUT", REPO / "docs/design/scene-art/batch0"))

# A point on the trail's lowest long leg, normalized. Every theme image has
# the trail at the same place (decision S4), so one seed serves them all; a
# theme that moved its trail fails here first (the seed is off the trail).
SEED = (0.444, 0.6215)

# CIE76 colour distance (Lab) from the trail's own colour.
TRAIL_DELTA_E = 14.0


@dataclasses.dataclass
class Trail:
    image: str
    size: tuple[int, int]  # width, height in px
    points: np.ndarray  # (n, 2) px, start (foot) to end (summit)
    widths: np.ndarray  # (n,) px, across the trail at each point
    mask: np.ndarray  # bool, the trail's pixels
    lab: np.ndarray
    ref: np.ndarray  # the trail's reference Lab colour

    @property
    def norm(self) -> np.ndarray:
        w, h = self.size
        return self.points / np.array([w, h])

    @property
    def length_px(self) -> float:
        return float(np.linalg.norm(np.diff(self.points, axis=0), axis=1).sum())

    def cumulative(self) -> np.ndarray:
        seg = np.linalg.norm(np.diff(self.points, axis=0), axis=1)
        return np.concatenate([[0.0], np.cumsum(seg)])

    def at(self, s: np.ndarray) -> np.ndarray:
        """Points at arc lengths [s] (px) along the polyline."""
        c = self.cumulative()
        return np.stack(
            [np.interp(s, c, self.points[:, 0]), np.interp(s, c, self.points[:, 1])],
            axis=1,
        )

    def steps(self, days: int) -> np.ndarray:
        """Day 0 (the foot) to day [days] (the summit), evenly spaced by arc
        length (decision S2)."""
        return self.at(np.linspace(0, self.length_px, days + 1))

    def width_at(self, s: np.ndarray) -> np.ndarray:
        return np.interp(s, self.cumulative(), self.widths)


def load_lab(path: Path) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.asarray(Image.open(path).convert("RGB"))
    return rgb, rgb2lab(rgb / 255.0)


def _component_at(mask: np.ndarray, xy: tuple[int, int]) -> np.ndarray:
    labels, _ = ndimage.label(mask, structure=np.ones((3, 3)))
    lab_id = labels[xy[1], xy[0]]
    if lab_id == 0:
        raise ValueError("seed is not on the trail colour")
    return labels == lab_id


def trail_mask(lab: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    h, w = lab.shape[:2]
    sx, sy = int(SEED[0] * w), int(SEED[1] * h)
    r = max(2, w // 400)
    ref = np.median(lab[sy - r : sy + r + 1, sx - r : sx + r + 1].reshape(-1, 3), 0)
    scale = w / 2172  # radii below are tuned on the 2172 px green image
    for _ in range(3):
        dist = np.linalg.norm(lab - ref, axis=-1)
        # Opening cuts thin bridges to look-alike specks; closing and hole
        # filling absorb the trail's own texture and shading.
        m = ndimage.binary_opening(dist < TRAIL_DELTA_E, disk(max(1, round(3 * scale))))
        m = _component_at(m, (sx, sy))
        m = ndimage.binary_closing(m, disk(max(1, round(6 * scale))))
        m = ndimage.binary_fill_holes(m)
        ref = np.median(lab[m], 0)
    return m, ref


def _longest_path(skel: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(skel)
    idx = -np.ones(skel.shape, dtype=np.int64)
    idx[ys, xs] = np.arange(len(xs))
    rows, cols, wts = [], [], []
    for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
        y2, x2 = ys + dy, xs + dx
        ok = (y2 < skel.shape[0]) & (x2 >= 0) & (x2 < skel.shape[1])
        j = np.full(len(xs), -1)
        j[ok] = idx[y2[ok], x2[ok]]
        ok = j >= 0
        rows.append(np.arange(len(xs))[ok])
        cols.append(j[ok])
        wts.append(np.full(ok.sum(), math.hypot(dy, dx)))
    g = coo_matrix(
        (np.concatenate(wts), (np.concatenate(rows), np.concatenate(cols))),
        shape=(len(xs), len(xs)),
    ).tocsr()
    # Tree diameter: farthest from anywhere, then farthest from that.
    d0 = dijkstra(g, directed=False, indices=0)
    a = int(np.nanargmax(np.where(np.isinf(d0), -1, d0)))
    da, pred = dijkstra(g, directed=False, indices=a, return_predecessors=True)
    b = int(np.nanargmax(np.where(np.isinf(da), -1, da)))
    path = [b]
    while path[-1] != a:
        path.append(int(pred[path[-1]]))
    return np.stack([xs[path], ys[path]], axis=1).astype(float)


def _resample(p: np.ndarray, step: float) -> np.ndarray:
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    c = np.concatenate([[0], np.cumsum(seg)])
    s = np.linspace(0, c[-1], max(2, int(round(c[-1] / step)) + 1))
    return np.stack([np.interp(s, c, p[:, 0]), np.interp(s, c, p[:, 1])], 1)


def _inside(mask: np.ndarray, p: np.ndarray) -> bool:
    x, y = int(round(p[0])), int(round(p[1]))
    return 0 <= y < mask.shape[0] and 0 <= x < mask.shape[1] and bool(mask[y, x])


def _ray(mask: np.ndarray, p: np.ndarray, d: np.ndarray, limit: float) -> float:
    t = 0.0
    while t < limit and _inside(mask, p + d * t):
        t += 0.5
    return t


def _widths(mask: np.ndarray, pts: np.ndarray) -> np.ndarray:
    tan = np.gradient(pts, axis=0)
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    nrm = np.stack([-tan[:, 1], tan[:, 0]], 1)
    lim = mask.shape[1] * 0.2
    return np.array(
        [_ray(mask, p, n, lim) + _ray(mask, p, -n, lim) for p, n in zip(pts, nrm)]
    )


def _cap(mask: np.ndarray, pts: np.ndarray, half: float) -> np.ndarray:
    """Replace the skeleton's ragged end with a straight run to the end
    piece's centroid. The skeleton wanders where a wide trail ends (at the
    foot the trail is cut square against the START mat), so one trail width
    is cut off; what is left of the trail beyond that point (its pixels
    within two widths, ahead along the tangent) is averaged. An area mean
    does not depend on the skeleton's wobble, so light, dark and other
    themes give the same end."""
    trim = int(max(2, 2 * half))  # resampled at 1 px, so points = px
    body = pts[:-trim]
    b = body[-1]
    d = b - body[-1 - trim]
    d /= np.linalg.norm(d)
    r = 4 * half
    x0, y0 = int(max(0, b[0] - r)), int(max(0, b[1] - r))
    x1, y1 = int(min(mask.shape[1], b[0] + r + 1)), int(min(mask.shape[0], b[1] + r + 1))
    yy, xx = np.mgrid[y0:y1, x0:x1]
    rel = np.stack([xx - b[0], yy - b[1]], -1)
    sel = mask[y0:y1, x0:x1] & ((rel**2).sum(-1) <= r * r) & (rel @ d > 0)
    if not sel.any():
        return body
    end = np.array([xx[sel].mean(), yy[sel].mean()])
    n = int(np.linalg.norm(end - b))
    tail = b + (end - b) * (np.arange(1, n + 1)[:, None] / max(n, 1))
    return np.concatenate([body, tail]) if len(tail) else body


def extract(path: Path, spacing_norm: float = 0.0025) -> Trail:
    rgb, lab = load_lab(path)
    h, w = lab.shape[:2]
    mask, ref = trail_mask(lab)
    soft = ndimage.gaussian_filter(mask.astype(float), sigma=4 * w / 2172) > 0.5
    raw = _longest_path(skeletonize(soft))
    if raw[0, 1] < raw[-1, 1]:  # start at the foot (larger y)
        raw = raw[::-1]
    p = _resample(raw, 1.0)
    # Smooth away the skeleton's pixel staircase; ends are re-cut below.
    sig = 12 * w / 2172
    p = np.stack([ndimage.gaussian_filter1d(p[:, i], sig, mode="nearest") for i in (0, 1)], 1)
    half = float(np.median(_widths(mask, p[:: max(1, len(p) // 200)]))) / 2
    p = _cap(mask, p, half)
    p = _cap(mask, p[::-1], half)[::-1]
    p = _resample(p, spacing_norm * h)
    return Trail(
        image=str(path.relative_to(REPO)) if path.is_relative_to(REPO) else str(path),
        size=(w, h),
        points=p,
        widths=_widths(mask, p),
        mask=mask,
        lab=lab,
        ref=ref,
    )


def bends(t: Trail, min_excursion_norm: float = 0.02) -> list[dict]:
    """Turning points: where the trail's horizontal direction reverses (a
    local x extreme), with hysteresis so texture wobble is not a bend."""
    x = t.points[:, 0]
    c = t.cumulative()
    tol = min_excursion_norm * t.size[0]
    out, mode, ext = [], None, 0
    for i in range(1, len(x)):
        if mode is None:
            if abs(x[i] - x[0]) > tol:
                mode, ext = ("up" if x[i] > x[0] else "down"), i
        elif mode == "up":
            if x[i] >= x[ext]:
                ext = i
            elif x[ext] - x[i] > tol:
                out.append(("right", ext))
                mode, ext = "down", i
        else:
            if x[i] <= x[ext]:
                ext = i
            elif x[i] - x[ext] > tol:
                out.append(("left", ext))
                mode, ext = "up", i
    return [
        {
            "side": side,
            "px": [round(float(t.points[i, 0]), 1), round(float(t.points[i, 1]), 1)],
            "norm": [round(float(t.norm[i, 0]), 4), round(float(t.norm[i, 1]), 4)],
            "arc_fraction": round(float(c[i] / c[-1]), 4),
        }
        for side, i in out
    ]


def flatness(t: Trail) -> np.ndarray:
    """Local standard deviation of lightness (L*), over an 8 px window at a
    common 1086 px analysis width (the images come in 1086 and 2172), then
    mapped back to the image's pixels. The clearings are the flattest
    ground there is."""
    f = 1086 / t.size[0]
    L = ndimage.zoom(t.lab[..., 0], f, order=1) if f != 1 else t.lab[..., 0]
    m = ndimage.uniform_filter(L, 8)
    m2 = ndimage.uniform_filter(L * L, 8)
    sd = np.sqrt(np.maximum(m2 - m * m, 0))
    if f != 1:
        sd = ndimage.zoom(sd, (t.size[1] / sd.shape[0], t.size[0] / sd.shape[1]), order=1)
    return sd


# Flat: local L* deviation under this. Clearings measure ~0.1-0.6 inside,
# grass and rock 1-6 (tool/scene_art/README.md).
FLAT_SD = 1.0


def clearings(t: Trail) -> list[dict]:
    """The flat clearings on the bends' outer corners (decision S3): for each
    bend, the largest flat region beyond the trail's outer edge that touches
    the trail. Bends without one are reported as missing."""
    w, h = t.size
    s = w / 2172
    flat = flatness(t) < FLAT_SD
    flat &= ~ndimage.binary_dilation(t.mask, disk(max(1, round(4 * s))))
    flat = ndimage.binary_opening(flat, disk(max(1, round(5 * s))))
    labels, n = ndimage.label(flat)
    # The clearing's flat core stops 13-33 px (at 2172) short of the trail:
    # the rim between them is shaded.
    ring = ndimage.binary_dilation(t.mask, disk(max(1, round(48 * s))))
    touching = sorted(set(np.unique(labels[ring & (labels > 0)]).tolist()) - {0})
    sizes = ndimage.sum(np.ones_like(labels), labels, touching)
    centers = ndimage.center_of_mass(np.ones_like(labels), labels, touching)
    out = []
    for b in bends(t):
        bx, by = b["px"]
        sign = 1 if b["side"] == "right" else -1
        best = None
        for i, size, (cy, cx) in zip(touching, sizes, centers):
            # Beyond the apex on its outer side, at about its height.
            if sign * (cx - bx) <= 0 or abs(cy - by) > 0.06 * h:
                continue
            if size < (40 * s) ** 2 or size > (260 * s) ** 2:
                continue
            if best is None or size > best[0]:
                best = (size, i)
        if best is None:
            out.append({"bend": b, "missing": True})
            continue
        ys, xs = np.nonzero(labels == best[1])
        best = (int(best[0]), xs, ys)
        area, xs, ys = best
        # The flat core misses the clearing's shaded rim: grow it by colour
        # (within 10 of the core's median, at most 30 px out at 2172 scale).
        pad = round(40 * s)
        y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + pad + 1)
        x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + pad + 1)
        core = np.zeros((y1 - y0, x1 - x0), bool)
        core[ys - y0, xs - x0] = True
        lab = t.lab[y0:y1, x0:x1]
        ref = np.median(lab[core], 0)
        near = np.linalg.norm(lab - ref, axis=-1) < 10
        grow = ndimage.binary_dilation(core, disk(max(1, round(30 * s)))) & near
        grow &= ~t.mask[y0:y1, x0:x1]
        lab_g, _ = ndimage.label(grow | core)
        full = lab_g == lab_g[ys[0] - y0, xs[0] - x0]
        full = ndimage.binary_fill_holes(
            ndimage.binary_opening(full, disk(max(1, round(3 * s)))) | core)
        ys, xs = np.nonzero(full)
        ys, xs = ys + y0, xs + x0
        area = int(full.sum())
        cx, cy = float(xs.mean()), float(ys.mean())
        bw, bh = float(xs.max() - xs.min() + 1), float(ys.max() - ys.min() + 1)
        out.append(
            {
                "side": b["side"],
                "bend_norm": b["norm"],
                "center_px": [round(cx, 1), round(cy, 1)],
                "center_norm": [round(cx / w, 4), round(cy / h, 4)],
                "box_px": [round(bw, 1), round(bh, 1)],
                "box_norm": [round(bw / w, 4), round(bh / h, 4)],
                "area_px": area,
                "area_norm": round(area / (w * h), 6),
            }
        )
    return out


def horizontal_run(mask: np.ndarray, p) -> tuple[float, float]:
    """The trail's horizontal run through [p]: its left and right edge
    (px). Not centred on the centre line on a bend."""
    y = int(round(p[1]))
    row = mask[y]
    x = int(round(p[0]))
    if not row[x]:
        return (float(x), float(x))
    l = x
    while l > 0 and row[l - 1]:
        l -= 1
    r = x
    while r < len(row) - 1 and row[r + 1]:
        r += 1
    return (float(l), float(r))


def horizontal_chord(mask: np.ndarray, p) -> float:
    """The trail's horizontal width (px) through [p]: an avatar stands
    upright, so its footprint lies along x whatever the leg's direction."""
    y = int(round(p[1]))
    row = mask[y]
    x = int(round(p[0]))
    if not row[x]:
        return 0.0
    l = x
    while l > 0 and row[l - 1]:
        l -= 1
    r = x
    while r < len(row) - 1 and row[r + 1]:
        r += 1
    return float(r - l + 1)


def nearest_arc(t: Trail, xy) -> tuple[float, float]:
    """(arc length px, distance px) of the trail point nearest [xy]."""
    d = np.linalg.norm(t.points - np.asarray(xy), axis=1)
    i = int(np.argmin(d))
    return float(t.cumulative()[i]), float(d[i])


def compare(a: Trail, b: Trail, samples: int = 1000, end_share: float = 0.03) -> dict:
    """Deviation of trail [b] from trail [a], in [a]'s pixels (b is scaled
    to a's size). The body (the trail without [end_share] of its length at
    each end) is compared both ways, sample to polyline; the two end points
    are compared on their own, because where a wide trail "ends" depends on
    how the mask's edge is cut (see _cap)."""

    def to_poly(p, q):
        d = np.full(len(p), np.inf)
        for q0, q1 in zip(q[:-1], q[1:]):
            v = q1 - q0
            L = (v**2).sum()
            u = np.clip(((p - q0) @ v) / L, 0, 1) if L else np.zeros(len(p))
            d = np.minimum(d, np.linalg.norm(p - (q0 + u[:, None] * v), axis=1))
        return d

    k = np.array(a.size) / np.array(b.size)
    span = lambda t: np.linspace(t.length_px * end_share, t.length_px * (1 - end_share), samples)
    pa, pb = a.at(span(a)), b.at(span(b)) * k
    qa, qb = a.points, b.points * k
    d = np.concatenate([to_poly(pa, qb), to_poly(pb, qa)])
    return {
        "max_px": round(float(d.max()), 2),
        "mean_px": round(float(d.mean()), 2),
        "p95_px": round(float(np.percentile(d, 95)), 2),
        "start_px": round(float(np.linalg.norm(qa[0] - qb[0])), 2),
        "end_px": round(float(np.linalg.norm(qa[-1] - qb[-1])), 2),
        "length_ratio": round(float(np.linalg.norm(np.diff(qb, axis=0), axis=1).sum()) / a.length_px, 4),
    }


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1) + "\n")
