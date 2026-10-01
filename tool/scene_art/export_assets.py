"""Scene Art Stage 1: the app's background assets, from the source images.

    build/scene_art_venv/bin/python tool/scene_art/export_assets.py

Batch 0's recommendation (docs/design/scene-art/batch0/report.md, §5.1):
1536 x 2048 px, enough for K-b 1.3x at 430 pt on a 3x screen (1526 px),
lossy WebP at quality 80 (Pillow's libwebp, method 6). Lanczos resize from
the full-resolution source. The same source and settings give the same
bytes.

Writes assets/climb/<theme id>/background_<mode>.webp.
"""

from __future__ import annotations

from PIL import Image

import trail as T

WIDTH, HEIGHT = 1536, 2048
QUALITY = 80

# (source image under docs/design/scene-art/source/, asset path)
# (source folder, theme id): the theme ids of lib/models/climb_theme.dart.
THEMES = (("green", "green_slope"), ("ember", "ember_peak"),
          ("glacier", "glacier_peak"), ("canyon", "red_canyon"))
BACKGROUNDS = tuple(
    (f"{folder}/background_{mode}.png", f"assets/climb/{theme}/background_{mode}.webp")
    for folder, theme in THEMES for mode in ("light", "dark"))


def main() -> None:
    for src, dst in BACKGROUNDS:
        im = Image.open(T.SOURCE / src).convert("RGB")
        if im.width * HEIGHT != im.height * WIDTH:
            raise SystemExit(f"{src} is not 3:4")
        out = T.REPO / dst
        out.parent.mkdir(parents=True, exist_ok=True)
        im.resize((WIDTH, HEIGHT), Image.LANCZOS).save(out, "WEBP", quality=QUALITY, method=6)
        print(f"{dst}: {out.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
