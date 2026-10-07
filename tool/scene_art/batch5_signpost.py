"""Batch 5 Batch 0, §4: the C5 signpost (N11), measured and rendered.

    build/scene_art_venv/bin/python tool/scene_art/batch5_signpost.py

1. The source (`docs/design/scene-art/source/objects/signpost.png`) is
   cleaned, cropped and resized exactly as export_objects.py does for the
   save points (192 px wide, WebP quality 90), but written to
   build/scene_art/batch5/signpost.webp, not to assets/ (Batch 0 adds no
   asset). Its alpha and colour are reported.
2. Placed on clearing C5 by the save points' rule (place_save_points.py):
   centred on the clearing, the base 0.25 of the clearing's height below
   its centre, the largest width ratio of 1.0, 0.95 … 0.5 whose shape
   (alpha > 25 at the 2172 px source scale) does not touch Green's trail
   mask. The other ratios are listed with the trail pixels they cover.
3. Renders the C5 neighbourhood at app size (375 pt screen, the 341.3 pt
   window, K-b 1.1×, 3 px per pt) in every theme, light and dark: the
   theme's WebP background, the signpost always lit (N11), the campfire
   on C4 lit and the flag on C6 unreached, as on a late day; in dark mode
   every object through G6's relighting at strength 0.5 (the flame kept
   unfiltered on the lit campfire, as the app draws it).

Writes docs/design/batch5/signpost/ (or BATCH5_OUT/signpost):
placement.json (read by tool/design_measure/batch5/save_point_numbers_test.dart),
signpost_numbers.txt, signpost_themes.jpg.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage.color import deltaE_ciede2000, rgb2hsv, rgb2lab

import trail as T
from export_objects import QUALITY, WIDTH, clean, resize
from extract_trail import font

OUT = Path(os.environ.get("BATCH5_OUT", T.REPO / "docs/design/batch5")) / "signpost"
BUILD = T.REPO / "build/scene_art/batch5"
STAGE2 = T.REPO / "docs/design/scene-art/stage2"
RATIOS = (1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5)
ALPHA = 25
BASE_DROP = 0.25
CLEARING = 5
THEMES = ("green_slope", "ember_peak", "glacier_peak", "red_canyon")
# App framing for the renders: the window at 375 pt, K-b 1.1×, at 3x.
WINDOW_PT, ZOOM, PX_PER_PT = 341.3, 1.1, 3
STRENGTH = 0.5  # ClimbSavePoints.defaultDarkFilterStrength
UNREACHED_OPACITY, UNREACHED_SATURATION = 0.5, 0.6  # G8


def export() -> tuple[Image.Image, dict]:
    src = np.asarray(Image.open(T.SOURCE / "objects/signpost.png").convert("RGBA"))
    rgba, strays = clean(src)
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    crop = rgba[box[1]:box[3], box[0]:box[2]]
    im = resize(crop, WIDTH)
    arr, ringing = clean(np.asarray(im))
    im = Image.fromarray(arr)
    BUILD.mkdir(parents=True, exist_ok=True)
    path = BUILD / "signpost.webp"
    im.save(path, "WEBP", quality=QUALITY, method=6)
    a = crop[..., 3]
    body = a > 0
    hsv = rgb2hsv(crop[..., :3] / 255.0)
    wood = body & (hsv[..., 1] > 0.3)  # the post and the board, not the grey stones
    info = {
        "source_crop_px": list(box),
        "stray_pixels_zeroed": strays,
        "ringing_pixels_zeroed_after_resize": ringing,
        "size_px": [im.width, im.height],
        "aspect_h_over_w": round(im.height / im.width, 5),
        "bytes": path.stat().st_size,
        "alpha_median_inside": int(np.median(a[a > 128])),
        "alpha_255_share_inside": round(float((a[a > 128] == 255).mean()), 4),
        "wood_mean_rgb": [int(v) for v in crop[wood][:, :3].mean(0)],
        "wood_mean_hsv_value": round(float(hsv[wood][:, 2].mean()), 3),
    }
    return im, info


def fits(mask: np.ndarray, clearing: dict, obj: Image.Image, size) -> list[dict]:
    W, H = size
    (cx, cy), (bw, bh) = clearing["center_norm"], clearing["box_norm"]
    out = []
    for ratio in RATIOS:
        wpx = bw * ratio * W
        im = obj.resize((round(wpx), round(wpx * obj.height / obj.width)), Image.LANCZOS)
        a = np.asarray(im)[..., 3] > ALPHA
        left, top = round(cx * W - im.width / 2), round((cy + BASE_DROP * bh) * H - im.height)
        out.append({"ratio": ratio, "width_px": round(wpx, 1),
                    "trail_pixels_covered": int((a & mask[top:top + im.height, left:left + im.width]).sum())})
    return out


def matrix_apply(rgba: np.ndarray, lit: float, gain) -> np.ndarray:
    """ClimbSavePoints.matrix, on 0-255 RGBA (un-premultiplied)."""
    out = rgba.astype(float).copy()
    rgb = out[..., :3] / 255
    lum = rgb @ np.array([.2126, .7152, .0722])
    s = UNREACHED_SATURATION + (1 - UNREACHED_SATURATION) * lit
    a = UNREACHED_OPACITY + (1 - UNREACHED_OPACITY) * lit
    rgb = (1 - s) * lum[..., None] + s * rgb
    if gain is not None:
        rgb = rgb * np.array([1 + STRENGTH * (g - 1) for g in gain])
    out[..., :3] = np.clip(rgb, 0, 1) * 255
    out[..., 3] = out[..., 3] * a
    return out.astype(np.uint8)


def place(scene: Image.Image, obj: Image.Image, rect_px) -> None:
    l, t, r, b = rect_px
    o = obj.resize((max(1, round(r - l)), max(1, round(b - t))), Image.LANCZOS)
    scene.alpha_composite(o, (round(l), round(t)))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sign, info = export()
    trail = json.loads((T.OUT / "trail_green.json").read_text())
    clearings = trail["clearings"]
    t = T.extract(T.SOURCE / "green/background_light.png")
    W, H = t.size
    c5 = clearings[CLEARING - 1]
    table = fits(t.mask, c5, sign, (W, H))
    chosen = next(f for f in table if f["trail_pixels_covered"] == 0)
    (cx, cy), (bw, bh) = c5["center_norm"], c5["box_norm"]
    width = bw * chosen["ratio"]
    aspect = info["aspect_h_over_w"]
    # The app's units: x in image widths, y in image widths too (ClimbRoute).
    base_y = (cy + BASE_DROP * bh) * H / W
    rect = [cx - width / 2, base_y - width * aspect, cx + width / 2, base_y]
    placement = {
        "generator": "tool/scene_art/batch5_signpost.py",
        "clearing": f"C{CLEARING}", "object": "signpost", "ratio": chosen["ratio"],
        "base_drop": BASE_DROP, "center_norm": c5["center_norm"], "box_norm": c5["box_norm"],
        "area_px": c5["area_px"],
        "rect_image_widths": [round(v, 5) for v in rect],
        "asset": info, "ratios": table,
    }
    (OUT / "placement.json").write_text(json.dumps(placement, indent=1) + "\n")

    objects = json.loads((STAGE2 / "objects.json").read_text())
    stage2 = json.loads((STAGE2 / "placement.json").read_text())
    gains = objects["dark_gain"]
    lines = [
        "Batch 5 Batch 0 §4: the C5 signpost (tool/scene_art/batch5_signpost.py).",
        "",
        f"Asset (as export_objects.py, written to build/): {info['size_px'][0]} x {info['size_px'][1]} px, "
        f"{info['bytes']} bytes, WebP q{QUALITY}; {info['stray_pixels_zeroed']} stray source pixels zeroed "
        f"(the source has scattered alpha specks), {info['ringing_pixels_zeroed_after_resize']} after the resize.",
        f"Alpha inside the body: median {info['alpha_median_inside']}, "
        f"{info['alpha_255_share_inside'] * 100:.1f} % fully opaque (the other objects: 255).",
        f"Wood colour (saturated pixels): mean RGB {tuple(info['wood_mean_rgb'])}, HSV value "
        f"{info['wood_mean_hsv_value']}.",
        "",
        f"C5: centre {c5['center_norm']}, box {c5['box_px']} px at 2172 ({c5['area_px']} px area); "
        f"for comparison C4 {clearings[3]['box_px']}, C6 {clearings[5]['box_px']}.",
        "Width ratio -> trail pixels covered (alpha > 25 against Green's trail mask, 2172 px):",
        *[f"  {f['ratio']:.2f}  {f['width_px']:6.1f} px  {f['trail_pixels_covered']}" for f in table],
        f"Chosen by the rule: {chosen['ratio']:.2f} ({chosen['width_px']} px at 2172).",
        f"Rect (image widths, ClimbRoute's unit): {placement['rect_image_widths']}.",
        "",
        "On screen (window = card width at 320 / 375 / 430 pt: 288.0 / 341.3 / 391.3; K-b 1.1x):",
    ]
    for screen, window in ((320, 288.0), (375, 341.3), (430, 391.3)):
        scale = window * ZOOM
        lines.append(f"  {screen} pt: signpost {width * scale:.1f} x {width * aspect * scale:.1f} pt; "
                     + ", ".join(f"{p['object']} {p['box_norm'][0] * p['ratio'] * scale:.1f}"
                                 for p in stage2["save_points"] + [stage2["flag"]]) + " pt wide")
    (OUT / "signpost_numbers.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))

    # Renders.
    scale_px = WINDOW_PT * ZOOM * PX_PER_PT  # px per image width
    objs = {n: Image.open(T.REPO / f"assets/climb/objects/{n}.webp").convert("RGBA")
            for n in ("campfire", "campfire_flame", "summit_flag")}
    sp4 = stage2["save_points"][3]
    flag = stage2["flag"]

    def rect_of(p, aspect):
        (x, y), (w_, h_) = p["center_norm"], p["box_norm"]
        wd = w_ * p["ratio"]
        by = (y + BASE_DROP * h_) * H / W
        return [v * scale_px for v in (x - wd / 2, by - wd * aspect, x + wd / 2, by)]

    crop_w, crop_h = 200 * PX_PER_PT, 150 * PX_PER_PT
    ccx, ccy = cx * scale_px, (cy * H / W) * scale_px - 20 * PX_PER_PT
    box = (round(ccx - crop_w * 0.62), round(ccy - crop_h / 2), round(ccx + crop_w * 0.38), round(ccy + crop_h / 2))
    tiles = []
    separation = []
    for theme in THEMES:
        for mode in ("light", "dark"):
            bg = Image.open(T.REPO / f"assets/climb/{theme}/background_{mode}.webp").convert("RGBA")
            bg = bg.resize((round(scale_px), round(scale_px * H / W)), Image.LANCZOS)
            gain = gains[theme] if mode == "dark" else None
            def obj(name, lit):
                return Image.fromarray(matrix_apply(np.asarray(objs[name]), lit, gain))
            place(bg, obj("campfire", 1), rect_of(sp4, objects["objects"]["campfire"]["aspect_h_over_w"]))
            if gain is not None:
                place(bg, objs["campfire_flame"], rect_of(sp4, objects["objects"]["campfire"]["aspect_h_over_w"]))
            place(bg, obj("summit_flag", 0), rect_of(flag, objects["objects"]["summit_flag"]["aspect_h_over_w"]))
            before = np.asarray(bg.convert("RGB")).copy()
            srect = [v * scale_px for v in rect]
            drawn = Image.fromarray(matrix_apply(np.asarray(sign), 1, gain))
            place(bg, drawn, srect)
            # Separation: the drawn wood (saturated, opaque) against the
            # ground in a ring 2-8 pt around the sign, both mean CIELAB.
            layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
            place(layer, drawn, srect)
            la = np.asarray(layer)
            body = la[..., 3] > 200
            hsv = rgb2hsv(la[..., :3] / 255.0)
            wood = body & (hsv[..., 1] > 0.3)
            grown = ndimage.binary_dilation(la[..., 3] > 0, iterations=8 * PX_PER_PT)
            near = ndimage.binary_dilation(la[..., 3] > 0, iterations=2 * PX_PER_PT)
            ring = grown & ~near
            after = np.asarray(bg.convert("RGB"))
            lab_w = rgb2lab(after[wood][None] / 255.0)[0].mean(0)
            lab_g = rgb2lab(before[ring][None] / 255.0)[0].mean(0)
            separation.append(f"  {theme:13} {mode:5}  wood L* {lab_w[0]:5.1f}  ground L* {lab_g[0]:5.1f}  "
                              f"dE2000 {float(deltaE_ciede2000(lab_w, lab_g)):5.1f}")
            tile = bg.crop(box).convert("RGB")
            ImageDraw.Draw(tile).text((10, 8), f"{theme} {mode}", fill=(255, 255, 255) if mode == "dark" else (20, 20, 20),
                                      font=font(26))
            tiles.append(tile)
    tw, th = tiles[0].size
    sheet = Image.new("RGB", (tw * 2 + 10, th * 4 + 30), (255, 255, 255))
    for i, tile in enumerate(tiles):
        r, c = divmod(i, 2)
        sheet.paste(tile, (c * (tw + 10), r * (th + 10)))
    sheet.save(OUT / "signpost_themes.jpg", quality=86)
    lines += ["", "Colour separation at 375 pt (signpost lit; dark: G6 at 0.5): the drawn wood's",
              "mean colour against the ground 2-8 pt around the sign (CIEDE2000).",
              "For scale: G10 measured the orange pennant at 8.4 on Red Canyon (faded,",
              "light) and kept the blue at 16.4 (its weakest case).", *separation]
    (OUT / "signpost_numbers.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(separation))


if __name__ == "__main__":
    main()
