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
card:    build/design_measure/batch5_card (Batch 6's month_card_real_render_test.dart
         with the four screens) -> card/: overview_summary.jpg, overview_fresh.jpg,
         summary_320_textsizes.jpg, the numbers and card_compare.txt.
celebration: build/design_measure/batch5_celebration (celebration_render_test.dart)
         -> celebration/: the five cases at 375 pt, 320 pt text sizes, numbers.
labels_real: build/design_measure/batch5_labels_real (label_real_render_test.dart)
         -> labels_real/: the five labels at 320 / 375 / 430, 320 pt text sizes,
         375 pt dark, numbers.
profile: build/design_measure/batch5_profile (profile_render_test.dart) ->
         profile/: shelf_<empty|three|twelve>.jpg (light over dark),
         shelf_twelve_320_textsizes.jpg, detail_<october|running>.jpg, numbers.
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


def _rows(path: Path) -> dict[tuple[str, str, str, str], list[str]]:
    out = {}
    for line in path.read_text().splitlines():
        f = line.split()
        if f and f[0] in ("summary", "fresh"):
            out[(f[0], f[1], f[2], f[3])] = f
    return out


def card() -> None:
    """Batch 5 (N16, N30, N37): the real month card, from
    month_card_real_render_test.dart run with DESIGN_MEASURE_CARD_SCREENS=
    320x568,375x812,430x932,375x667 into build/design_measure/batch5_card;
    compared with Batch 6's numbers (docs/design/batch6/card/) and N30's
    (month_card_real_numbers_N30.txt, kept when N37 replaced them)."""
    src, out = BUILD / "batch5_card", OUT / "card"
    out.mkdir(parents=True, exist_ok=True)
    new_file = src / "month_card_real_numbers_320x568_375x812_430x932_375x667.txt"
    shutil.copy(new_file, out)
    old = _rows(T.REPO / "docs/design/batch6/card/month_card_real_numbers.txt")
    old.update(_rows(T.REPO / "docs/design/batch6/card/month_card_real_numbers_375x667.txt"))
    n30 = _rows(out / "month_card_real_numbers_N30.txt")
    new = _rows(new_file)
    lines = ["Batch 5 (N30, N37): the real month card on the real Home after the M21 scroll: Batch 6",
             "(40 pt medal in a row) -> N30 (centred, 88 / 70 / 48 pt by screen height) -> N37",
             "(112 / 70 / 48 pt). Sheet height in points; window = the mountain above the sheet (of",
             "350 pt); START = the K-c avatar above the sheet. Dark lays out the same:",
             f"{'yes' if all(new[k][5:] == new[(k[0], k[1], 'light', k[3])][5:] for k in new if k[2] == 'dark') else 'NO'}.", "",
             "card     screen    text    sheet B6 -> N30 -> N37       scrolls B6/N30/N37   window B6 -> N30 -> N37        START N30/N37"]
    for key, f in new.items():
        if key[2] != "light" or key not in old:
            continue
        o, m = old[key], n30.get(key, old[key])
        lines.append(f"{key[0]:8} {key[1]:9} {key[3]:7} {float(o[5]):6.1f} -> {float(m[5]):6.1f} -> {float(f[5]):6.1f}"
                     f"     {o[10]}/{m[10]}/{f[10]:3}            {o[13]:>5} -> {m[13]:>5} -> {f[13]:>5} {f[14] + ' %)':>8}"
                     f"        {m[-1]}/{f[-1]}")
    (out / "card_compare.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    # 375 × 667 under its own name (month_card_real_render_test.dart).
    screens = {"320": "320 x 568", "375x667": "375 x 667", "375": "375 x 812", "430": "430 x 932"}
    for kind in ("summary", "fresh"):
        cells = [[Image.open(src / f"card_{kind}_{w}_{m}_medium.png") for w in screens] for m in ("light", "dark")]
        grid(cells, [f"{n}, Medium" for n in screens.values()], 0.5).save(out / f"overview_{kind}.jpg", quality=84)
    cells = [[Image.open(src / f"card_summary_320_light_{s}.png") for s in ("small", "medium", "large")]]
    grid(cells, [f"320 x 568, {s}" for s in ("Small", "Medium", "Large")], 0.5).save(
        out / "summary_320_textsizes.jpg", quality=84)


def profile() -> None:
    """Batch 5 step 6 (N33, N34): the shelf and the detail (profile_render_test.dart)."""
    src, out = BUILD / "batch5_profile", OUT / "profile"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("profile_*.jpg"):
        old.unlink()
    widths = (320, 375, 430)
    for case in ("empty", "three", "twelve"):
        cells = [[trim(Image.open(src / f"profile_{case}_{w}_{m}_medium.png")) for w in widths]
                 for m in ("light", "dark")]
        grid(cells, [f"{w} pt, Medium" for w in widths], 0.5).save(out / f"shelf_{case}.jpg", quality=84)
    cells = [[trim(Image.open(src / f"profile_twelve_320_light_{s}.png")) for s in ("small", "medium", "large")]]
    grid(cells, [f"320 pt, {s}, light" for s in ("Small", "Medium", "Large")], 0.5).save(
        out / "shelf_twelve_320_textsizes.jpg", quality=84)
    for which in ("october", "running"):
        cells = [[Image.open(src / f"profile_detail_{which}_{w}_{m}.png") for w in widths]
                 for m in ("light", "dark")]
        grid(cells, [f"{w} pt" for w in widths], 0.4).save(out / f"detail_{which}.jpg", quality=84)
    shutil.copy(src / "profile_numbers.txt", out)


def celebration() -> None:
    """Batch 5 step 5 (N15): the celebration layer (celebration_render_test.dart)."""
    src, out = BUILD / "batch5_celebration", OUT / "celebration"
    out.mkdir(parents=True, exist_ok=True)
    whats = ("welcome", "bronze", "silver", "gold", "silver_ember")
    for mode in ("light", "dark"):
        cells = [[Image.open(src / f"celebration_{w}_375x812_{mode}_medium.png") for w in whats]]
        grid(cells, [f"{w}, 375, {mode}" for w in whats], 0.4).save(out / f"celebration_375_{mode}.jpg", quality=84)
    cells = [[Image.open(src / f"celebration_silver_320x568_light_{s}.png") for s in ("small", "medium", "large")]]
    grid(cells, [f"320 x 568, {s}" for s in ("Small", "Medium", "Large")], 0.5).save(
        out / "celebration_320_textsizes.jpg", quality=84)
    shutil.copy(src / "celebration_numbers.txt", out)


def labels_real() -> None:
    """Batch 5 step 6 (N19): the real label on the real Home
    (label_real_render_test.dart)."""
    src, out = BUILD / "batch5_labels_real", OUT / "labels_real"
    out.mkdir(parents=True, exist_ok=True)
    cells = [[Image.open(src / f"label_{c}_{w}_light_medium.png") for w in (320, 375, 430)] for c, _ in LABELS]
    grid(cells, [f"{w} pt, Medium, light" for w in (320, 375, 430)], 0.5).save(
        out / "labels_light_medium.jpg", quality=84)
    cells = [[Image.open(src / f"label_{c}_320_light_{s}.png") for s in ("small", "medium", "large")]
             for c, _ in LABELS]
    grid(cells, [f"320 pt, {s}, light" for s in ("Small", "Medium", "Large")], 0.5).save(
        out / "labels_320_light_textsizes.jpg", quality=84)
    cells = [[Image.open(src / f"label_{c}_375_dark_medium.png") for c, _ in LABELS]]
    grid(cells, [f"{c} {n}" for c, n in LABELS], 0.5).save(out / "labels_375_dark_medium.jpg", quality=84)
    shutil.copy(src / "save_point_labels_real.txt", out)


def steps() -> None:
    """Batch 5 step 2 (N31, N32): steps_render_test.dart's frames."""
    src, out = BUILD / "batch5_steps", OUT / "steps"
    out.mkdir(parents=True, exist_ok=True)
    names = (("C1", "First Camp"), ("C2", "Halfway Hut"), ("C3", "Mountain Spring"),
             ("C4", "High Camp"), ("C6", "Summit (last step)"))
    cells = [[Image.open(src / f"steps_{w}_{c}_375.png") for w in ("before", "after")] for c, _ in names]
    grid(cells, ["before (even over the whole trail)", "after (N31 pinned, N32 at the flag)"], 0.5).save(
        out / "steps_before_after_375.jpg", quality=84)
    cells = [[Image.open(src / f"summit_{e}_{w}.png") for w in (320, 375, 430)] for e in ("flag", "tip")]
    grid(cells, [f"{w} pt: top ends at the flag, bottom at the tip" for w in (320, 375, 430)], 0.5).save(
        out / "summit_flag_vs_tip.jpg", quality=84)
    # N35: the avatar on the step it passes the C5 signpost (29 of 31).
    Image.open(src / "steps_after_C5_375.png").convert("RGB").save(out / "avatar_at_signpost_375.jpg", quality=86)


if __name__ == "__main__":
    {"sites": sites, "labels": labels, "welcome": welcome, "card": card, "profile": profile,
     "celebration": celebration, "labels_real": labels_real, "steps": steps}[sys.argv[1]]()
