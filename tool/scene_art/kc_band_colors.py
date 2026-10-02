"""Replaced by M22 (2026-10-02): a record only; the product now shows a
blurred backdrop (export_blur.py).

Batch 6, decision M11: the K-c side bands' colour, one per theme and
mode, measured from the image's own left and right edges.

    build/scene_art_venv/bin/python tool/scene_art/kc_band_colors.py

In K-c the whole image is fitted to the window's height, so the window
shows empty bands beside it (Batch 0 report §6). For each background asset
(what the app draws, assets/climb/<theme>/background_<mode>.webp) this
takes the outer STRIP px of both side edges over the full height and
averages them in CIELAB (a perceptual mean), giving the single band colour.
It also gives the mean of the top and bottom fifth of the same strips (for
the vertical-gradient render only; M11 puts one colour in the product), and
how far the edge pixels are from the single colour (ΔE2000, median and 95th
percentile per row), which is the seam the band can show.

Writes docs/design/batch6/kc_bands.txt and kc_bands.json.
"""

from __future__ import annotations

import json

import numpy as np
from PIL import Image
from skimage.color import deltaE_ciede2000, lab2rgb, rgb2lab

import trail as T

THEMES = ["green_slope", "ember_peak", "glacier_peak", "red_canyon"]
MODES = ["light", "dark"]
STRIP = 8  # px of 1536: about 0.5 % of the width on each side
DST = T.REPO / "docs/design/batch6"


def hexof(lab: np.ndarray) -> str:
    rgb = np.clip(lab2rgb(lab.reshape(1, 1, 3)).reshape(3), 0, 1)
    return "#" + "".join(f"{round(c * 255):02X}" for c in rgb)


def main() -> None:
    out: dict[str, dict[str, dict[str, object]]] = {}
    lines = [
        "Batch 6 M11: K-c side band colours, measured from the image edges",
        f"Outer {STRIP} px of both sides of each background asset, full height, "
        "mean in CIELAB.",
        "",
        "theme          mode   band      top fifth  bottom fifth  ΔE2000 of edge rows to band (median / p95)",
    ]
    for theme in THEMES:
        out[theme] = {}
        for mode in MODES:
            im = Image.open(T.REPO / f"assets/climb/{theme}/background_{mode}.webp").convert("RGB")
            a = np.asarray(im, dtype=np.float64) / 255
            edges = np.concatenate([a[:, :STRIP], a[:, -STRIP:]], axis=1)
            lab = rgb2lab(edges)
            band = lab.reshape(-1, 3).mean(axis=0)
            h = lab.shape[0]
            top = lab[: h // 5].reshape(-1, 3).mean(axis=0)
            bottom = lab[-h // 5 :].reshape(-1, 3).mean(axis=0)
            rows = lab.mean(axis=1)
            de = deltaE_ciede2000(rows, np.broadcast_to(band, rows.shape))
            entry = {
                "band": hexof(band),
                "top": hexof(top),
                "bottom": hexof(bottom),
                "seam_median": round(float(np.median(de)), 1),
                "seam_p95": round(float(np.percentile(de, 95)), 1),
            }
            out[theme][mode] = entry
            lines.append(
                f"{theme:<14} {mode:<6} {entry['band']}   {entry['top']}    {entry['bottom']}       "
                f"{entry['seam_median']} / {entry['seam_p95']}"
            )
    lines += [
        "",
        "band: the single colour M11 put in the product (replaced by M22, a blurred backdrop).",
        "top / bottom: only for the vertical-gradient render (not in the product).",
    ]
    DST.mkdir(parents=True, exist_ok=True)
    (DST / "kc_bands.txt").write_text("\n".join(lines) + "\n")
    (DST / "kc_bands.json").write_text(json.dumps(out, indent=2) + "\n")


if __name__ == "__main__":
    main()
