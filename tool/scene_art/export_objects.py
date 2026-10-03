"""Scene Art Stage 2: the save point objects and the summit flag as app
assets, the campfire's flame layer, and the dark-mode filter.

    build/scene_art_venv/bin/python tool/scene_art/export_objects.py

For each object in docs/design/scene-art/source/objects/ (the save points,
the summit flag and, since Batch 5, the C5 signpost):
1. Stray pixels away from the body are zeroed: any alpha > 0 outside the
   largest 8-connected alpha > 0 region (Batch 0 found 12 invisible
   alpha = 1 pixels at the canvas corners, `avatar_16`'s class).
2. Cropped to the remaining alpha > 0, so the image's bottom edge is the
   object's base.
3. Premultiplied Lanczos resize to WIDTH px wide, then step 1 again (the
   resize's ringing can leave faint alpha cut off from the body); lossy
   WebP quality 90 (libwebp keeps alpha lossless by default).

The campfire also gets campfire_flame.webp: only its bright, saturated
orange pixels (FLAME), the same crop and size. In dark mode the app draws
it unfiltered over the filtered campfire once the save point is reached
(G6, G8). The threshold is applied to the campfire only: the same colours
are the tent's trim, the cabin's knob and the flag's pennant (counted in
objects.json).

The dark-mode filter (G6): per theme, the per-channel gain, dark ÷ light,
of the clearings' ground in that theme's own WebP backgrounds (the
clearings are at the same place in every theme, S4).

Writes assets/climb/objects/*.webp and
docs/design/scene-art/stage2/objects.json (read by
tool/climb_table/climb_save_point_generator.dart).
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image
from scipy import ndimage
from skimage.color import rgb2hsv

import trail as T

# The signpost (Batch 5, N11, N18) is decoration on C5, not a save point:
# no flame, no pennant, always drawn lit.
OBJECTS = ("campfire", "tent", "fountain", "cabin", "summit_flag", "signpost")
# The largest object on screen is about 40 pt wide (C1 at 430 pt, 1.1×),
# 120 px at 3x; 192 px leaves room for a closer framing.
WIDTH = 192
QUALITY = 90
# The flame: hue 15–60°, saturation ≥ 0.55, value ≥ 0.90 (on the
# un-premultiplied colour). Chosen on the campfire: it takes the flames
# and the firelit log tips and stone edges, not the logs or the stones.
FLAME = {"hue_min": 15, "hue_max": 60, "saturation_min": 0.55, "value_min": 0.90}

# The flag's pennant (G10, Red Canyon recolours it): hue 10–40°,
# saturation ≥ 0.72, value ≥ 0.40, then the largest connected region with
# its holes filled. Chosen on the flag: it takes the whole pennant, its
# shaded lower edge included, and leaves the pole's lit edges and the
# stones out (the flame's threshold missed the pennant's shade; lower
# saturation limits took the pole).
PENNANT = {"hue_min": 10, "hue_max": 40, "saturation_min": 0.72, "value_min": 0.40}

ASSETS = T.REPO / "assets/climb/objects"
STAGE2 = T.REPO / "docs/design/scene-art/stage2"


def flame_mask(rgba: np.ndarray) -> np.ndarray:
    hsv = rgb2hsv(rgba[..., :3] / 255.0)
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    return ((rgba[..., 3] > 0) & (h >= FLAME["hue_min"]) & (h <= FLAME["hue_max"])
            & (s >= FLAME["saturation_min"]) & (v >= FLAME["value_min"]))


def pennant_mask(rgba: np.ndarray) -> np.ndarray:
    hsv = rgb2hsv(rgba[..., :3] / 255.0)
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    m = ((rgba[..., 3] > 0) & (h >= PENNANT["hue_min"]) & (h <= PENNANT["hue_max"])
         & (s >= PENNANT["saturation_min"]) & (v >= PENNANT["value_min"]))
    labels, n = ndimage.label(m)
    sizes = ndimage.sum(m, labels, range(1, n + 1))
    return ndimage.binary_fill_holes(labels == (int(np.argmax(sizes)) + 1))


def luminance(rgb: np.ndarray) -> np.ndarray:
    """Rec. 709 weights on the sRGB values (0–1): what a colour matrix
    can compute."""
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def clean(rgba: np.ndarray) -> tuple[np.ndarray, int]:
    """Zero alpha outside the largest 8-connected alpha > 0 region."""
    labels, n = ndimage.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    if n <= 1:
        return rgba, 0
    sizes = ndimage.sum(np.ones(labels.shape), labels, range(1, n + 1))
    keep = labels == (int(np.argmax(sizes)) + 1)
    stray = (rgba[..., 3] > 0) & ~keep
    out = rgba.copy()
    out[stray] = 0
    return out, int(stray.sum())


def resize(rgba: np.ndarray, width: int) -> Image.Image:
    im = Image.fromarray(rgba.astype(np.uint8), "RGBA").convert("RGBa")
    h = round(im.height * width / im.width)
    return im.resize((width, h), Image.LANCZOS).convert("RGBA")


def save(im: Image.Image, name: str) -> int:
    path = ASSETS / f"{name}.webp"
    im.save(path, "WEBP", quality=QUALITY, method=6)
    return path.stat().st_size


THEMES = ("green_slope", "ember_peak", "glacier_peak", "red_canyon")


def dark_gain(clearings: list[dict], theme: str) -> list[float]:
    light = np.asarray(Image.open(T.REPO / f"assets/climb/{theme}/background_light.webp").convert("RGB"), float)
    dark = np.asarray(Image.open(T.REPO / f"assets/climb/{theme}/background_dark.webp").convert("RGB"), float)
    h, w = light.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros((h, w), bool)
    for c in clearings:
        (cx, cy), (bw, bh) = c["center_norm"], c["box_norm"]
        m |= ((xx / w - cx) / (bw / 2)) ** 2 + ((yy / h - cy) / (bh / 2)) ** 2 <= 0.6
    return [round(float(v), 4) for v in dark[m].mean(0) / light[m].mean(0)]


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    STAGE2.mkdir(parents=True, exist_ok=True)
    data: dict = {"generator": "tool/scene_art/export_objects.py", "width_px": WIDTH,
                  "quality": QUALITY, "flame_threshold": FLAME, "objects": {}}
    for name in OBJECTS:
        src = np.asarray(Image.open(T.SOURCE / f"objects/{name}.png").convert("RGBA"))
        rgba, strays = clean(src)
        ys, xs = np.nonzero(rgba[..., 3] > 0)
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        crop = rgba[box[1]:box[3], box[0]:box[2]]
        im = resize(crop, WIDTH)
        # Lanczos rings: faint alpha (≤ 3) can land just off the edge, cut
        # off from the body by a zero. Cleaned again at the final size.
        arr, ringing = clean(np.asarray(im))
        im = Image.fromarray(arr, "RGBA")
        entry = {
            "asset": f"assets/climb/objects/{name}.webp",
            "source_crop_px": [int(v) for v in box],
            "stray_pixels_zeroed": strays,
            "ringing_pixels_zeroed_after_resize": ringing,
            "size_px": [im.width, im.height],
            "aspect_h_over_w": round(im.height / im.width, 5),
            "bytes": save(im, name),
            "flame_threshold_pixels": int((flame_mask(src) & (src[..., 3] > 230)).sum()),
        }
        if name == "campfire":
            fl = crop.copy().astype(float)
            mask = flame_mask(crop).astype(float)
            # Feather the mask's edge over ~2 source px, so the unfiltered
            # flame blends into the filtered fire.
            mask = ndimage.gaussian_filter(mask, 1.5)
            fl[..., 3] = fl[..., 3] * mask
            fim = resize(fl, WIDTH)
            entry["flame_asset"] = "assets/climb/objects/campfire_flame.webp"
            entry["flame_bytes"] = save(fim, "campfire_flame")
            entry["flame_share_of_body"] = round(float(flame_mask(crop).sum() / (crop[..., 3] > 0).sum()), 4)
        if name == "summit_flag":
            pm = pennant_mask(crop)
            # A 1 px feather: the pennant meets the pole there. The pennant
            # and the base split each pixel's alpha (m and 1 − m), so drawn
            # together, at any shared opacity, they add up to the flag.
            soft = np.clip(ndimage.gaussian_filter(pm.astype(float), 1.0) * 1.5, 0, 1)
            base = crop.copy().astype(float)
            base[..., 3] = base[..., 3] * (1 - soft)
            entry["pennant_asset"] = "assets/climb/objects/summit_flag_pennant.webp"
            # The base is cleaned like the objects (the feather leaves faint
            # specks cut off from it); the pennant is then the flag minus
            # the base, so the two add up to the flag exactly.
            bim, specks = clean(np.asarray(resize(base, WIDTH)))
            full = np.asarray(im).astype(int)
            pim = full.copy()
            pim[..., 3] = np.clip(full[..., 3] - bim[..., 3].astype(int), 0, 255)
            pim, _ = clean(pim.astype(np.uint8))
            entry["pennant_bytes"] = save(Image.fromarray(pim, "RGBA"), "summit_flag_pennant")
            entry["base_asset"] = "assets/climb/objects/summit_flag_base.webp"
            entry["base_bytes"] = save(Image.fromarray(bim, "RGBA"), "summit_flag_base")
            entry["base_specks_zeroed"] = specks
            entry["pennant_threshold"] = PENNANT
            entry["pennant_share_of_body"] = round(float(pm.sum() / (crop[..., 3] > 0).sum()), 4)
            # The pennant's median luminance: a recolour scales the target
            # colour by each pixel's luminance over this, keeping the shading.
            entry["pennant_luminance"] = round(float(np.median(luminance(crop[pm][:, :3] / 255.0))), 4)
        data["objects"][name] = entry
    trail = json.loads((T.OUT / "trail_green.json").read_text())
    data["dark_gain"] = {t: dark_gain(trail["clearings"], t) for t in THEMES}
    data["total_bytes"] = sum(o["bytes"] + o.get("flame_bytes", 0) + o.get("pennant_bytes", 0)
                              + o.get("base_bytes", 0) for o in data["objects"].values())
    (STAGE2 / "objects.json").write_text(json.dumps(data, indent=1) + "\n")
    print(json.dumps(data, indent=1))


if __name__ == "__main__":
    main()
