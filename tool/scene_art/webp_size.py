"""Scene Art Batch 0, step 5.1: what the backgrounds and objects cost as
WebP, and at what quality.

    build/scene_art_venv/bin/python tool/scene_art/webp_size.py

For each background (and the objects), resized to the widths the framing
study needs (framing_numbers.txt: the largest 3x need per option), encoded
lossy at several qualities with Pillow's libwebp (method 6), decoded, and
compared with the same-size resized source: PSNR and SSIM on lightness.
Writes webp_numbers.txt, webp.json and webp_crops.jpg (the START flag
and the trail's edge at 1536 px: source and q70/q80/q90, at 2x).
"""

from __future__ import annotations

import io
import json
import warnings
from pathlib import Path

import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity

import trail as T

warnings.filterwarnings("ignore", category=RuntimeWarning)

BACKGROUNDS = ("green/background_light.png", "green/background_dark.png", "archive/volcanic/background_light.png")
# 1086: the pre-upscale size; 1174: K-a at 430 pt; 1536: K-b 1.3 at 430 pt
# (needs 1526); 1878: K-b 1.6 at 430 pt; 2172: the delivered size.
WIDTHS = (1086, 1174, 1536, 1878, 2172)
QUALITIES = (70, 80, 90)
OBJECT_WIDTHS = (192, 256)  # the largest object on screen, 58 pt x 3 = 174 px
OBJECT_QUALITY = 90


def lum(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert("L")).astype(float)


def encode(im: Image.Image, q: int) -> bytes:
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=q, method=6)
    return buf.getvalue()


def main() -> None:
    lines, data = [], {"backgrounds": {}, "objects": {}}
    out = lines.append
    out("lossy WebP, Pillow libwebp method 6; PSNR / SSIM on lightness against the resized source")
    for name in BACKGROUNDS:
        src = Image.open(T.SOURCE / name).convert("RGB")
        out(f"\n{name} ({src.width} x {src.height}, PNG {(T.SOURCE / name).stat().st_size / 1e6:.2f} MB)")
        for w in WIDTHS:
            h = round(src.height * w / src.width)
            ref = src.resize((w, h), Image.LANCZOS)
            up = " (upscaled from the source)" if w > src.width else ""
            row = []
            for q in QUALITIES:
                b = encode(ref, q)
                dec = Image.open(io.BytesIO(b)).convert("RGB")
                a, r = lum(dec), lum(ref)
                mse = ((a - r) ** 2).mean()
                psnr = 10 * np.log10(255**2 / mse) if mse else float("inf")
                ssim = structural_similarity(a, r, data_range=255)
                row.append(f"q{q} {len(b) / 1024:.0f} KB (PSNR {psnr:.1f}, SSIM {ssim:.4f})")
                data["backgrounds"][f"{name} {w} q{q}"] = {"kb": round(len(b) / 1024, 1), "psnr": round(psnr, 2),
                                                           "ssim": round(ssim, 4)}
            out(f"  {w} x {h}{up}: " + "; ".join(row))
    out(f"\nobjects at q{OBJECT_QUALITY} (alpha kept, lossy RGB + alpha):")
    for n in ("campfire", "tent", "fountain", "cabin", "summit_flag"):
        im = Image.open(T.SOURCE / f"objects/{n}.png").convert("RGBA")
        a = np.asarray(im)[..., 3]
        ys, xs = np.nonzero(a > 8)
        pad = 8
        im = im.crop((xs.min() - pad, ys.min() - pad, xs.max() + pad + 1, ys.max() + pad + 1))
        row = []
        for w in OBJECT_WIDTHS:
            r = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
            b = encode(r, OBJECT_QUALITY)
            data["objects"][f"{n} {w}"] = round(len(b) / 1024, 1)
            row.append(f"{w} px wide {len(b) / 1024:.1f} KB")
        out(f"  {n}: " + "; ".join(row))
    # Visual: a 260 px square around the START flag at 1536 px, light.
    from PIL import ImageDraw
    from extract_trail import font
    src = Image.open(T.SOURCE / BACKGROUNDS[0]).convert("RGB")
    ref = src.resize((1536, round(src.height * 1536 / src.width)), Image.LANCZOS)
    box = (150, 1530, 410, 1790)
    tiles = [("source", ref.crop(box))]
    for q in QUALITIES:
        tiles.append((f"q{q}", Image.open(io.BytesIO(encode(ref, q))).convert("RGB").crop(box)))
    sheet = Image.new("RGB", (4 * 520 + 50, 560), "white")
    for i, (label, im) in enumerate(tiles):
        sheet.paste(im.resize((520, 520), Image.NEAREST), (10 + i * 530, 40))
        ImageDraw.Draw(sheet).text((10 + i * 530, 8), f"{label} (1536 px, 2x)", fill=(0, 0, 0), font=font(20))
    sheet.save(T.OUT / "webp_crops.jpg", quality=92)
    avatars = sum(p.stat().st_size for p in (T.REPO / "assets/avatars").glob("*.webp"))
    out(f"\nfor scale: the 16 bundled avatars total {avatars / 1024:.0f} KB")
    (T.OUT / "webp_numbers.txt").write_text("\n".join(lines) + "\n")
    (T.OUT / "webp.json").write_text(json.dumps(data, indent=1) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
