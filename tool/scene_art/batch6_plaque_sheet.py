"""Batch 6 Batch 0, step 2: the plaque before and after its corners were
rounded, on the real Home (day 15 of October 2026, Medium text).

Before (the commit before the change, ac6c900) and after, each rendered by
the real-Home tool into its own folder:

    DESIGN_MEASURE_OUT=build/design_measure/batch6_plaque_before \\
        DESIGN_MEASURE_SCREENS=320,375,430 DESIGN_MEASURE_DAYS=15 \\
        flutter test tool/design_measure/scene_art/home_render_test.dart
    (the same with batch6_plaque_after on the commit with the change)
    build/scene_art_venv/bin/python tool/scene_art/batch6_plaque_sheet.py

With the argument "shares" (Batch 6 step 2: 0.4 → 0.7), instead compares
plaqueRadiusShare 0.4 / 0.7 / 1.0 at 375 pt, light and dark:

    for s in 0.4 0.7 1.0; do DESIGN_MEASURE_OUT=build/design_measure/batch6_plaque_share \
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=15 DESIGN_MEASURE_PLAQUE_SHARE=$s \
        flutter test tool/design_measure/scene_art/home_render_test.dart; done
    build/scene_art_venv/bin/python tool/scene_art/batch6_plaque_sheet.py shares

writing docs/design/batch6/plaque/plaque_shares.jpg.

Otherwise writes docs/design/batch6/plaque/plaque_before_after.jpg (the plaque cut
out at 3x, before | after, per screen and mode) and cards_before_after.jpg
(the whole climb card at 1x).
"""

from __future__ import annotations

import json
import sys

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

SRC = T.REPO / "build/design_measure"
DST = T.REPO / "docs/design/batch6/plaque"
SCREENS = [320, 375, 430]
MODES = ["light", "dark"]
PAD = 24  # 8 pt at 3x around the plaque, the card cut's own margin


def load(state: str, screen: int, mode: str) -> tuple[Image.Image, list[float]]:
    name = f"home_{screen}_{mode}_day15"
    folder = SRC / f"batch6_plaque_{state}"
    box = json.loads((folder / f"{name}.json").read_text())["plaque"]
    return Image.open(folder / f"{name}.png").convert("RGB"), box


def sheet(rows: list[tuple[str, list[Image.Image]]], heads: list[str]) -> Image.Image:
    gap, head = 12, 26
    cw = max(im.width for _, ims in rows for im in ims)
    rh = [max(im.height for im in ims) + head for _, ims in rows]
    out = Image.new("RGB", (2 * cw + 3 * gap, sum(rh) + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(out)
    y = gap
    for (label, ims), h in zip(rows, rh):
        for i, im in enumerate(ims):
            x = gap + i * (cw + gap)
            d.text((x, y), f"{label} · {heads[i]}", fill="black", font=font(18))
            out.paste(im, (x, y + head))
        y += h + gap
    return out


def shares() -> None:
    folder = SRC / "batch6_plaque_share"
    rows = []
    for mode in MODES:
        crops = []
        for share in ("0.4", "0.7", "1.0"):
            name = f"home_375_{mode}_day15_plaque{share}"
            box = json.loads((folder / f"{name}.json").read_text())["plaque"]
            im = Image.open(folder / f"{name}.png").convert("RGB")
            crops.append(im.crop((int(box[0]) - PAD, int(box[1]) - PAD, int(box[2]) + PAD, int(box[3]) + PAD)))
        rows.append((f"375 pt · {mode}", crops))
    gap, head = 12, 26
    cw = max(im.width for _, ims in rows for im in ims)
    rh = max(im.height for _, ims in rows for im in ims) + head
    out = Image.new("RGB", (3 * cw + 4 * gap, len(rows) * rh + (len(rows) + 1) * gap), "white")
    d = ImageDraw.Draw(out)
    for r, (label, ims) in enumerate(rows):
        y = gap + r * (rh + gap)
        for i, (im, share) in enumerate(zip(ims, ("0.4 (8 pt)", "0.7 (14 pt)", "1.0 (20 pt asked)"))):
            x = gap + i * (cw + gap)
            d.text((x, y), f"{label} · share {share}", fill="black", font=font(18))
            out.paste(im, (x, y + head))
    out.save(DST / "plaque_shares.jpg", quality=90)


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "shares":
        shares()
        return
    DST.mkdir(parents=True, exist_ok=True)
    plaques, cards = [], []
    for screen in SCREENS:
        for mode in MODES:
            crops, whole = [], []
            for state in ("before", "after"):
                im, b = load(state, screen, mode)
                crops.append(im.crop((int(b[0]) - PAD, int(b[1]) - PAD, int(b[2]) + PAD, int(b[3]) + PAD)))
                whole.append(im.resize((im.width // 3, im.height // 3), Image.LANCZOS))
            plaques.append((f"{screen} pt · {mode}", crops))
            cards.append((f"{screen} pt · {mode}", whole))
    heads = ["before", "after"]
    sheet(plaques, heads).save(DST / "plaque_before_after.jpg", quality=90)
    sheet(cards, heads).save(DST / "cards_before_after.jpg", quality=88)


if __name__ == "__main__":
    main()
