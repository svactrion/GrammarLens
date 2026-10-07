"""Scene Art Batch 0, step 4: the save point objects and the summit flag on
the clearings, at app size, in light and dark.

    build/scene_art_venv/bin/python tool/scene_art/objects.py

Writes objects_numbers.txt, objects_ratio.jpg (one object at three sizes
per clearing), objects_closeups.jpg (each clearing at app size: light,
dark as is, dark filtered), objects_whole.jpg (the whole mountain, light
and dark, proposal C1-C4) and objects_edges.jpg (edge and smoke check).
"""

from __future__ import annotations

import json
import warnings

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import trail as T
from extract_trail import font
from framing import Frame, card_width

warnings.filterwarnings("ignore", category=RuntimeWarning)

OBJECTS = ("campfire", "tent", "fountain", "cabin", "summit_flag")
# The proposal (report §5): the four lowest clearings, one object each, in
# the order the scene-art decisions list them.
PROPOSAL = {1: "campfire", 2: "tent", 3: "fountain", 4: "cabin"}
# Object width as a share of its clearing's width; the base sits this far
# below the clearing's centre, as a share of the clearing's height.
RATIOS = (0.8, 1.0, 1.25)
CHOSEN_RATIO = 1.0
BASE_DROP = 0.25
# The summit flag stands beside the trail's end, on the summit's ground:
# its base offset from the end point (px at 2172), placed by hand, and its
# width (px at 2172), the size of the smallest clearing (C6).
FLAG_OFFSET = (70, 10)
FLAG_WIDTH = 116
# App framing for the close-ups: K-b 1.3 at 375 pt, rendered at 3 px per pt
# (a 3x screen), so the size and sharpness are what a phone shows.
CLOSE = ("width", 1.3, 375)
PX_PER_PT = 3


def load_object(name: str) -> Image.Image:
    im = Image.open(T.SOURCE / f"objects/{name}.png").convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 8)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def gain(bg_light: np.ndarray, bg_dark: np.ndarray, regions: list[np.ndarray]) -> np.ndarray:
    """Per-channel dark / light ratio of the ground in the clearings: the
    dusk relighting the dark scene applies, as one colour matrix (in Flutter
    a ColorFilter.matrix with these on the diagonal)."""
    m = np.zeros(bg_light.shape[:2], bool)
    for r in regions:
        m |= r
    return bg_dark[m].reshape(-1, 3).mean(0) / bg_light[m].reshape(-1, 3).mean(0)


def tint(obj: Image.Image, g: np.ndarray) -> Image.Image:
    a = np.asarray(obj).astype(float)
    a[..., :3] = np.clip(a[..., :3] * g, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def place(scene: Image.Image, obj: Image.Image, base_xy, width_px) -> None:
    """Paste [obj] scaled to [width_px], its bottom centre at [base_xy]."""
    h = round(obj.height * width_px / obj.width)
    o = obj.resize((max(1, round(width_px)), max(1, h)), Image.LANCZOS)
    scene.alpha_composite(o, (round(base_xy[0] - o.width / 2), round(base_xy[1] - o.height)))


def edge_report(name: str) -> dict:
    """Halo check: the edge's semi-transparent pixels (alpha 16-239),
    un-premultiplied, against the opaque pixels just inside them. A halo
    left by background removal shows as an edge lighter and greyer than
    the object (the backdrop was plain light grey)."""
    a = np.asarray(Image.open(T.SOURCE / f"objects/{name}.png").convert("RGBA")).astype(float)
    al = a[..., 3]
    rgb = a[..., :3]
    edge = (al >= 16) & (al <= 239)
    solid = al == 255
    inner = solid & ndimage.binary_dilation(edge, iterations=6)
    lum = lambda x: (0.2126 * x[:, 0] + 0.7152 * x[:, 1] + 0.0722 * x[:, 2])
    sat = lambda x: x.max(1) - x.min(1)
    e, i = rgb[edge], rgb[inner]
    width = ndimage.distance_transform_edt(al < 240)[edge]
    lone = (al > 0) & (al < 16)
    # Traces away from the body: any alpha more than 10 px from alpha > 8.
    far = (al > 0) & (ndimage.distance_transform_edt(al <= 8) > 10)
    fy, fx = np.nonzero(far)
    return {
        "stray_px": int(far.sum()),
        "stray_alpha_max": int(al[far].max()) if far.any() else 0,
        "stray_box": [int(fx.min()), int(fy.min()), int(fx.max()), int(fy.max())] if far.any() else None,
        "edge_px": int(edge.sum()),
        "edge_band_px_median": round(float(np.median(width)), 1),
        "edge_lum": round(float(lum(e).mean()), 1),
        "inside_lum": round(float(lum(i).mean()), 1),
        "edge_sat": round(float(sat(e).mean()), 1),
        "inside_sat": round(float(sat(i).mean()), 1),
        "faint_px_alpha_1_15": int(lone.sum()),
    }


def main() -> None:
    t = T.extract(T.SOURCE / "green/background_light.png")
    w, h = t.size
    clear = T.clearings(t)
    light = Image.open(T.SOURCE / "green/background_light.png").convert("RGBA")
    dark = Image.open(T.SOURCE / "green/background_dark.png").convert("RGBA")
    objs = {n: load_object(n) for n in OBJECTS}

    # Clearing regions for the gain: their boxes' inscribed ellipses.
    yy, xx = np.mgrid[0:h, 0:w]
    regions = []
    for c in clear:
        (cx, cy), (bw, bh) = c["center_px"], c["box_px"]
        regions.append(((xx - cx) / (bw / 2)) ** 2 + ((yy - cy) / (bh / 2)) ** 2 <= 0.6)
    g = gain(np.asarray(light)[..., :3].astype(float), np.asarray(dark)[..., :3].astype(float), regions)
    tinted = {n: tint(o, g) for n, o in objs.items()}

    f = Frame(CLOSE[0], CLOSE[1], card_width(CLOSE[2]), (w, h))
    lines = [f"source: {t.image}; objects cropped to alpha > 8",
             f"close-ups: K-b {CLOSE[1]} at {CLOSE[2]} pt ({f.s:.4f} pt per px), {PX_PER_PT} px per pt",
             f"dark filter (per-channel gain, clearings dark / light): R {g[0]:.3f} G {g[1]:.3f} B {g[2]:.3f}",
             "", "objects (cropped content, px; aspect w/h):"]
    for n, o in objs.items():
        lines.append(f"  {n}: {o.width} x {o.height} (aspect {o.width / o.height:.2f})")
    lines += ["", f"sizes at ratio {CHOSEN_RATIO} (object width = clearing width), base {BASE_DROP} of the clearing's height below its centre:"]
    sizes = {}
    for i, c in enumerate(clear, 1):
        bw = c["box_px"][0]
        ow = bw * CHOSEN_RATIO
        sizes[i] = ow
        lines.append(f"  C{i} ({c['side']}): clearing {bw:.0f} x {c['box_px'][1]:.0f} px -> object {ow:.0f} px wide = "
                     f"{ow * f.s:.1f} pt in K-b {CLOSE[1]} at {CLOSE[2]} pt; "
                     + ", ".join(f"{s} pt screen K-a {ow * Frame('width', 1, card_width(s), (w, h)).s:.1f}" for s in (320, 430)))
    end = t.points[-1]
    flag_base = (end[0] + FLAG_OFFSET[0], end[1] + FLAG_OFFSET[1])
    lines.append(f"  summit flag: {FLAG_WIDTH} px wide = {FLAG_WIDTH * f.s:.1f} pt, base at trail end + {FLAG_OFFSET} px")

    lines += ["", "edges and smoke (alpha 16-239 = the soft edge; lum/sat 0-255):"]
    edges = {}
    for n in OBJECTS:
        e = edge_report(n)
        edges[n] = e
        lines.append(f"  {n}: edge {e['edge_px']} px, band ~{e['edge_band_px_median']} px; edge lum {e['edge_lum']} vs inside {e['inside_lum']}; "
                     f"edge sat {e['edge_sat']} vs inside {e['inside_sat']}; faint alpha 1-15: {e['faint_px_alpha_1_15']} px; "
                     f"stray (>10 px from the body): {e['stray_px']} px, alpha max {e['stray_alpha_max']}, box {e['stray_box']}")
    (T.OUT / "objects_numbers.txt").write_text("\n".join(lines) + "\n")
    (T.OUT / "objects.json").write_text(json.dumps({"gain": [round(float(v), 4) for v in g], "edges": edges,
                                                    "object_width_px": {f"C{k}": round(v, 1) for k, v in sizes.items()}}, indent=1) + "\n")
    print("\n".join(lines))

    def scene_with(bg: Image.Image, use: dict[int, str], ratio: float, kind: str = "plain", flag=True) -> Image.Image:
        sc = bg.copy()
        for i, n in use.items():
            c = clear[i - 1]
            (cx, cy), (bw, bh) = c["center_px"], c["box_px"]
            o = tinted[n] if kind == "tinted" else objs[n]
            place(sc, o, (cx, cy + BASE_DROP * bh), bw * ratio)
        if flag:
            place(sc, tinted["summit_flag"] if kind == "tinted" else objs["summit_flag"], flag_base, FLAG_WIDTH)
        return sc

    def window(sc: Image.Image, centre, pt_w=130, pt_h=100) -> Image.Image:
        """A [pt_w] x [pt_h] pt piece of the app window around [centre], at
        app scale and PX_PER_PT."""
        k = f.s * PX_PER_PT
        half_w, half_h = pt_w / f.s / 2, pt_h / f.s / 2
        # Kept inside the image, as the camera is.
        x0 = min(max(centre[0] - half_w, 0), w - 2 * half_w)
        y0 = min(max(centre[1] - half_h, 0), h - 2 * half_h)
        box = (x0, y0, x0 + 2 * half_w, y0 + 2 * half_h)
        return sc.crop(tuple(round(v) for v in box)).resize((round(pt_w * PX_PER_PT), round(pt_h * PX_PER_PT)), Image.LANCZOS).convert("RGB")

    fnt = font(22)
    every = {1: "campfire", 2: "tent", 3: "fountain", 4: "cabin", 5: "campfire", 6: "tent"}

    # Ratio study: per clearing, three sizes, light.
    rows = []
    for i in range(1, 7):
        row = []
        for r in RATIOS:
            sc = scene_with(light, {i: every[i]}, r, flag=False)
            im = window(sc, clear[i - 1]["center_px"])
            ImageDraw.Draw(im).text((8, 6), f"C{i} x{r}", fill=(0, 0, 0), font=fnt, stroke_width=3, stroke_fill=(255, 255, 255))
            row.append(im)
        rows.append(row)
    grid(rows, T.OUT / "objects_ratio.jpg", "Object width = clearing width x 0.8 / 1.0 / 1.25 (app size: K-b 1.3 at 375 pt, 3x)")

    # Close-ups: light, dark as is, dark filtered, at the chosen ratio.
    rows = []
    variants = (("light", light, "plain"), ("dark, as is", dark, "plain"), ("dark, filtered", dark, "tinted"))
    for i in range(1, 7):
        row = []
        for label, bg, kind in variants:
            sc = scene_with(bg, {i: every[i]}, CHOSEN_RATIO, kind, flag=False)
            im = window(sc, clear[i - 1]["center_px"])
            ImageDraw.Draw(im).text((8, 6), f"C{i} {every[i]} · {label}", fill=(0, 0, 0), font=fnt, stroke_width=3, stroke_fill=(255, 255, 255))
            row.append(im)
        rows.append(row)
    row = []
    for label, bg, kind in variants:
        sc = scene_with(bg, {}, CHOSEN_RATIO, kind, flag=True)
        im = window(sc, (flag_base[0] - 40, flag_base[1] - 60))
        ImageDraw.Draw(im).text((8, 6), f"summit flag · {label}", fill=(0, 0, 0), font=fnt, stroke_width=3, stroke_fill=(255, 255, 255))
        row.append(im)
    rows.append(row)
    grid(rows, T.OUT / "objects_closeups.jpg",
         "Each clearing at app size (K-b 1.3, 375 pt, 3x): light | dark as is | dark with the colour filter. C5/C6 show spare objects for size only.")

    # Whole mountain, proposal C1-C4 + flag: light, dark as is, dark filtered.
    wholes = []
    for label, bg, kind in variants:
        im = scene_with(bg, PROPOSAL, CHOSEN_RATIO, kind).convert("RGB").resize((724, 965), Image.LANCZOS)
        ImageDraw.Draw(im).text((10, 8), label, fill=(0, 0, 0), font=fnt, stroke_width=3, stroke_fill=(255, 255, 255))
        wholes.append(im)
    grid([wholes], T.OUT / "objects_whole.jpg", "Proposal: C1 campfire, C2 tent, C3 fountain, C4 cabin, summit flag; object width = clearing width")

    # Edge check: each object 2x on near-black and on magenta (a halo or a
    # grey fringe shows as a light rim), plus its alpha above 0.
    rows = []
    for n in OBJECTS:
        o = Image.open(T.SOURCE / f"objects/{n}.png").convert("RGBA")
        a = np.asarray(o)[..., 3]
        ys, xs = np.nonzero(a > 8)
        o = o.crop((xs.min() - 60, ys.min() - 60, xs.max() + 61, ys.max() + 61))
        tiles = []
        for colour in ((24, 26, 34), (255, 0, 255)):
            bgc = Image.new("RGBA", o.size, colour + (255,))
            bgc.alpha_composite(o)
            tiles.append(bgc.convert("RGB").resize((360, round(360 * o.height / o.width)), Image.LANCZOS))
        # Any trace at all, over the whole source (strays included).
        any_alpha = Image.fromarray(((a > 0) * 255).astype(np.uint8)).convert("RGB")
        any_alpha = any_alpha.resize((360, 360), Image.BOX)
        tiles.append(any_alpha)
        # A 1:1 crop of the top edge on near-black.
        top = Image.new("RGBA", o.size, (24, 26, 34, 255))
        top.alpha_composite(o)
        cx = o.width // 2
        tiles.append(top.crop((cx - 180, 20, cx + 180, 320)).convert("RGB"))
        rows.append(tiles)
    grid(rows, T.OUT / "objects_edges.jpg", "Edges: on near-black | on magenta | alpha > 0 over the whole 2508 px source | top edge 1:1 on near-black")


def grid(rows, path, title: str) -> None:
    gap = 12
    cw = max(im.width for row in rows for im in row)
    rh = [max(im.height for im in row) for row in rows]
    cols = max(len(r) for r in rows)
    out = Image.new("RGB", (cols * cw + (cols + 1) * gap, sum(rh) + (len(rows) + 1) * gap + 36), "white")
    ImageDraw.Draw(out).text((gap, 8), title, fill=(0, 0, 0), font=font(20))
    y = 36 + gap
    for row, hgt in zip(rows, rh):
        for j, im in enumerate(row):
            out.paste(im, (gap + j * (cw + gap), y))
        y += hgt + gap
    out.save(path, quality=84)


if __name__ == "__main__":
    main()
