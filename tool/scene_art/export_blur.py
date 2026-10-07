"""Batch 6, M22: the K-c framing's blurred backdrop, one per theme and mode.

    build/scene_art_venv/bin/python tool/scene_art/export_blur.py
    build/scene_art_venv/bin/python tool/scene_art/export_blur.py --candidates

In K-c the whole image is fitted to the window's height, which leaves bands
beside it (Batch 0 report §6). M22 fills the window behind the sharp image
with a blurred copy of the same scene, made here once, so nothing is
blurred at run time. From each full-resolution source
(docs/design/scene-art/source/<folder>/background_<mode>.png): a Lanczos
resize to WIDTH × HEIGHT, then a Gaussian blur whose sigma is STRENGTH ×
WIDTH, then lossy WebP at QUALITY. The same source and settings give the
same bytes (check_theme.py --blur checks the assets against this).

Without arguments: writes assets/climb/<theme id>/background_<mode>_blur.webp
at STRENGTH and docs/design/batch6/blur/blur_assets.txt (sizes).
With --candidates: writes build/scene_art/blur/<name>/<theme id>_<mode>.webp
for each of CANDIDATES, for the comparison render.
"""

from __future__ import annotations

import io
import sys

from PIL import Image, ImageFilter

import trail as T
from export_assets import THEMES

WIDTH, HEIGHT = 192, 256
QUALITY = 70

# The one setting: the blur's sigma as a share of the image's width.
STRENGTH = 0.03
CANDIDATES = (("light", 0.015), ("medium", STRENGTH), ("strong", 0.06))

MODES = ("light", "dark")


def source(folder: str, mode: str) -> Image.Image:
    return Image.open(T.SOURCE / f"{folder}/background_{mode}.png").convert("RGB")


def make_blur(folder: str, mode: str, strength: float = STRENGTH) -> bytes:
    small = source(folder, mode).resize((WIDTH, HEIGHT), Image.LANCZOS)
    blurred = small.filter(ImageFilter.GaussianBlur(radius=strength * WIDTH))
    buf = io.BytesIO()
    blurred.save(buf, "WEBP", quality=QUALITY, method=6)
    return buf.getvalue()


def asset_path(theme: str, mode: str):
    return T.REPO / f"assets/climb/{theme}/background_{mode}_blur.webp"


def main(argv: list[str]) -> None:
    if "--candidates" in argv:
        for name, strength in CANDIDATES:
            out = T.REPO / f"build/scene_art/blur/{name}"
            out.mkdir(parents=True, exist_ok=True)
            for folder, theme in THEMES:
                for mode in MODES:
                    (out / f"{theme}_{mode}.webp").write_bytes(make_blur(folder, mode, strength))
        return
    lines = [
        "Batch 6 M22: the K-c blurred backdrops (tool/scene_art/export_blur.py)",
        f"{WIDTH} x {HEIGHT} px, Gaussian sigma = {STRENGTH} x width = {STRENGTH * WIDTH:.2f} px, "
        f"WebP quality {QUALITY}",
        "",
    ]
    total = 0
    for folder, theme in THEMES:
        for mode in MODES:
            data = make_blur(folder, mode)
            path = asset_path(theme, mode)
            path.write_bytes(data)
            total += len(data)
            lines.append(f"{path.relative_to(T.REPO)}: {len(data) / 1024:.1f} KB ({len(data)} bytes)")
    lines += ["", f"total: {total / 1024:.1f} KB ({total} bytes) for 8 assets"]
    out = T.REPO / "docs/design/batch6/blur"
    out.mkdir(parents=True, exist_ok=True)
    (out / "blur_assets.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv[1:])
