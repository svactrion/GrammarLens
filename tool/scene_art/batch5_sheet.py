"""Batch 5 Batch 0: the report's JPEGs from the Flutter tools' PNGs.

    build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py sites
    build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py labels
    build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py welcome

sites:   build/design_measure/batch5_sites (medal_sites_test.dart) ->
         sites_<mode>_medium.jpg (320 / 375 / 430 side by side) and
         sites_320_textsizes_<mode>.jpg (Small / Medium / Large at 320 pt).
labels:  build/design_measure/batch5_labels (save_point_label_test.dart) ->
         labels_A_vs_B_375_light_medium.jpg (the two placements),
         labels_B_light_medium.jpg (placement B at 320 / 375 / 430),
         labels_B_320_light_textsizes.jpg and labels_B_375_dark_medium.jpg.
welcome: build/design_measure/batch5_welcome (welcome_result_test.dart) ->
         welcome_result_scrolltop.jpg (each screen at its scroll top).

Written to docs/design/batch5/ (or BATCH5_OUT), each in its subfolder,
with the tool's text file (medal_sites.txt, save_point_labels.txt,
welcome_result.txt) copied next to the images.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

BUILD = T.REPO / "build/design_measure"
OUT = Path(os.environ.get("BATCH5_OUT", T.REPO / "docs/design/batch5"))


def trim(im: Image.Image) -> Image.Image:
    """Cut the empty bottom (the tools render on a tall surface)."""
    a = np.asarray(im.convert("RGB")).astype(int)
    bg = a[-1, -1]
    rows = np.nonzero((np.abs(a - bg).sum(2) > 12).any(1))[0]
    return im.crop((0, 0, im.width, int(rows.max()) + 12)) if len(rows) else im


def grid(cells: list[list[Image.Image | None]], labels: list[str], scale: float, gap: int = 16) -> Image.Image:
    cells = [[None if c is None else c.resize((round(c.width * scale), round(c.height * scale)), Image.LANCZOS)
              for c in row] for row in cells]
    cols = max(len(r) for r in cells)
    widths = [max((r[i].width for r in cells if i < len(r) and r[i] is not None), default=0) for i in range(cols)]
    heights = [max((c.height for c in r if c is not None), default=0) for r in cells]
    head = 40
    sheet = Image.new("RGB", (sum(widths) + gap * (cols + 1), sum(heights) + gap * (len(cells) + 1) + head),
                      (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    x = gap
    for i, label in enumerate(labels):
        d.text((x, 10), label, fill=(30, 30, 30), font=font(22))
        x += widths[i] + gap
    y = head + gap
    for r, row in enumerate(cells):
        x = gap
        for i, c in enumerate(row):
            if c is not None:
                sheet.paste(c.convert("RGB"), (x, y))
            x += widths[i] + gap
        y += heights[r] + gap
    return sheet


def sites() -> None:
    src, out = BUILD / "batch5_sites", OUT / "sites"
    out.mkdir(parents=True, exist_ok=True)
    for mode in ("light", "dark"):
        cells = [[trim(Image.open(src / f"sites_{w}_{mode}_medium.png")) for w in (320, 375, 430)]]
        grid(cells, [f"{w} pt, Medium, {mode}" for w in (320, 375, 430)], 0.5).save(
            out / f"sites_{mode}_medium.jpg", quality=84)
        cells = [[trim(Image.open(src / f"sites_320_{mode}_{s}.png")) for s in ("small", "medium", "large")]]
        grid(cells, [f"320 pt, {s}, {mode}" for s in ("Small", "Medium", "Large")], 0.5).save(
            out / f"sites_320_textsizes_{mode}.jpg", quality=84)
    shutil.copy(src / "medal_sites.txt", out)


LABELS = (("C1", "First Camp"), ("C2", "Halfway Hut"), ("C3", "Mountain Spring"), ("C4", "High Camp"),
          ("C6", "Summit"))


def labels() -> None:
    src, out = BUILD / "batch5_labels", OUT / "labels"
    out.mkdir(parents=True, exist_ok=True)
    cells = [[Image.open(src / f"label_{c}_375_light_medium_{p}.png") for p in ("A", "B")] for c, _ in LABELS]
    grid(cells, ["A: above the object (N6 as written)", "B: above the object and the avatar"], 0.5).save(
        out / "labels_A_vs_B_375_light_medium.jpg", quality=84)
    cells = [[Image.open(src / f"label_{c}_{w}_light_medium_B.png") for w in (320, 375, 430)] for c, _ in LABELS]
    grid(cells, [f"B, {w} pt, Medium, light" for w in (320, 375, 430)], 0.5).save(
        out / "labels_B_light_medium.jpg", quality=84)
    cells = [[Image.open(src / f"label_{c}_320_light_{s}_B.png") for s in ("small", "medium", "large")]
             for c, _ in LABELS]
    grid(cells, [f"B, 320 pt, {s}, light" for s in ("Small", "Medium", "Large")], 0.5).save(
        out / "labels_B_320_light_textsizes.jpg", quality=84)
    cells = [[Image.open(src / f"label_{c}_375_dark_medium_B.png") for c, _ in LABELS]]
    grid(cells, [f"B, {c} {n}" for c, n in LABELS], 0.5).save(out / "labels_B_375_dark_medium.jpg", quality=84)
    shutil.copy(src / "save_point_labels.txt", out)


def welcome() -> None:
    src, out = BUILD / "batch5_welcome", OUT / "welcome"
    out.mkdir(parents=True, exist_ok=True)
    names = ("320x568", "375x667", "375x812", "430x932")
    cells = [[Image.open(src / f"welcome_{n}_0wrong_medium.png") for n in names]]
    grid(cells, [f"{n}, Medium, scroll top" for n in names], 0.5).save(
        out / "welcome_result_scrolltop.jpg", quality=84)
    shutil.copy(src / "welcome_result.txt", out)


if __name__ == "__main__":
    {"sites": sites, "labels": labels, "welcome": welcome}[sys.argv[1]]()
