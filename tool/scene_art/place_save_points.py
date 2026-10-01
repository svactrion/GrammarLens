"""Scene Art Stage 2: where the save points and the flag stand.

    build/scene_art_venv/bin/python tool/scene_art/place_save_points.py

G9 (owner): within C1–C4, the large objects (cabin, tent) on the largest
clearings, the small ones (campfire, fountain) on the smaller. Batch 0's
placement rule: centred on the clearing, the base 0.25 of the clearing's
height below its centre, the width a ratio of the clearing's width (Batch
0 proposed 1.0).

The ratio per object here: the largest of 1.0, 0.95, 0.9 … whose shape
(alpha > 25, at the 2172 px source scale) does not touch the trail's mask.
At 1.0 the cabin on C1 covered 344 trail pixels and the fountain on C4
44: a clearing narrows below its centre, where the object's base stands,
and the trail's edge bends in there.

ASSIGNMENT: G9 leaves two choices open, which large object takes C1 and
which small one takes C3 (C3 has the larger area, C4 is wider). Every
combination was measured (stage2/placement.json, "alternatives"); this one
keeps every object largest: the tent on C1 at 0.9, the cabin on C2 at
1.0, the fountain on C3 at 1.0, the campfire on C4 at 0.9.

The flag (the summit_flag asset, the month's goal): on clearing C6, the
clearing under the summit, left of bend B6 (Batch 0's verify_trail.jpg),
by the same rule as the save points (largest ratio whose shape stays off
the trail). Stage 2 first stood it beside the trail's end; on the device
it did not fit there (its pole leant on the snow cap's edge and the rocks,
its base on no flat ground; that spot is in no clearing,
stage2/fix_flag_clearings.txt). The first fix put it on C5 by a label
mix-up; the owner meant C6 from the start (2026-10-01).

Writes docs/design/scene-art/stage2/placement.json (read by
tool/climb_table/climb_save_point_generator.dart).
"""

from __future__ import annotations

import itertools
import json

import numpy as np
from PIL import Image

import trail as T

ASSIGNMENT = {1: "tent", 2: "cabin", 3: "fountain", 4: "campfire"}
LARGE, SMALL = ("cabin", "tent"), ("campfire", "fountain")
BASE_DROP = 0.25
# Down to 0.5: on C5 (the first fix) the tall flag's pennant reached the
# bend above and only cleared at 0.55; on C6 it clears at 1.0.
RATIOS = (1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5)
ALPHA = 25
FLAG_CLEARING = 6


def fit(mask, clearing, name, size) -> dict:
    W, H = size
    (cx, cy), (bw, bh) = clearing["center_norm"], clearing["box_norm"]
    src = Image.open(T.REPO / f"assets/climb/objects/{name}.webp").convert("RGBA")
    for ratio in RATIOS:
        wpx = bw * ratio * W
        im = src.resize((round(wpx), round(wpx * src.height / src.width)), Image.LANCZOS)
        a = np.asarray(im)[..., 3] > ALPHA
        left, top = round(cx * W - im.width / 2), round((cy + BASE_DROP * bh) * H - im.height)
        if not (a & mask[top:top + im.height, left:left + im.width]).any():
            return {"ratio": ratio, "width_px": round(wpx, 1)}
    raise SystemExit(f"{name} does not fit its clearing")


def main() -> None:
    t = T.extract(T.SOURCE / "green/background_light.png")
    W, H = t.size
    trail = json.loads((T.OUT / "trail_green.json").read_text())
    clearings = trail["clearings"]
    alternatives = []
    for large, small in itertools.product(itertools.permutations(LARGE), itertools.permutations(SMALL)):
        a = dict(zip((1, 2, 3, 4), large + small))
        fits = {i: fit(t.mask, clearings[i - 1], n, (W, H)) for i, n in a.items()}
        alternatives.append({"assignment": {f"C{i}": n for i, n in a.items()},
                             "width_px": {n: fits[i]["width_px"] for i, n in a.items()},
                             "ratio": {n: fits[i]["ratio"] for i, n in a.items()}})
    points = []
    for i, name in ASSIGNMENT.items():
        c = clearings[i - 1]
        f = fit(t.mask, c, name, (W, H))
        points.append({"clearing": f"C{i}", "object": name, "ratio": f["ratio"],
                       "base_drop": BASE_DROP, "center_norm": c["center_norm"],
                       "box_norm": c["box_norm"], "area_px": c["area_px"]})
    c = clearings[FLAG_CLEARING - 1]
    f = fit(t.mask, c, "summit_flag", (W, H))
    flag = {"clearing": f"C{FLAG_CLEARING}", "object": "summit_flag", "ratio": f["ratio"],
            "base_drop": BASE_DROP, "center_norm": c["center_norm"],
            "box_norm": c["box_norm"], "area_px": c["area_px"]}
    out = {"generator": "tool/scene_art/place_save_points.py", "image_size_px": [W, H],
           "save_points": points, "flag": flag, "alternatives": alternatives}
    path = T.REPO / "docs/design/scene-art/stage2/placement.json"
    path.write_text(json.dumps(out, indent=1) + "\n")
    print(json.dumps({k: out[k] for k in ("save_points", "flag")}, indent=1))
    for alt in alternatives:
        print(alt["assignment"], alt["width_px"])


if __name__ == "__main__":
    main()
