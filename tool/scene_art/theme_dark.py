"""Batch 4, step 3: G6's dark-mode filter per theme, at the chosen strength
(0.5), measured like Green's (dark_strength.py).

    for m in 2026-10 2026-11 2026-12 2027-01; do
      # 30-day November: day 19 has the fountain and the campfire unreached
      DESIGN_MEASURE_OUT=build/design_measure/scene_art_themes \\
        DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=<19 or 20>,<last> \\
        DESIGN_MEASURE_MODES=dark DESIGN_MEASURE_MONTH=$m \\
        flutter test tool/design_measure/scene_art/home_render_test.dart
    done
    build/scene_art_venv/bin/python tool/scene_art/theme_dark.py

For each theme (its month), the mean L* of each save point's own pixels on
the last day (all reached) against the ground around it, and the
fountain's and campfire's reached − unreached difference (the early day,
when both are unreached). Flags a theme whose difference is under half of
Green's. Writes docs/design/scene-art/batch4/dark_filter.txt.
"""

from __future__ import annotations

import json

import trail as T
from dark_strength import measure

SRC = T.REPO / "build/design_measure/scene_art_themes"
THEMES = (("green_slope", "2026-10", 20, 31), ("ember_peak", "2026-11", 19, 30),
          ("glacier_peak", "2026-12", 20, 31), ("red_canyon", "2027-01", 20, 31))
OBJECTS = ("tent", "cabin", "fountain", "campfire")


def main() -> None:
    gains = json.loads((T.REPO / "docs/design/scene-art/stage2/objects.json").read_text())["dark_gain"]
    rows = {}
    for theme, month, early, last in THEMES:
        def load(day):
            stem = SRC / f"home_375_dark_day{day}_{month}"
            return measure(f"{stem}.png", json.loads(open(f"{stem}.json").read()))
        rows[theme] = (load(early), load(last))
    green_early, green_last = rows["green_slope"]
    lines = ["G6 per theme, dark mode, strength 0.5, real Home at 375 pt: mean L* of each object's own",
             "pixels; 'vs ground' on the last day (all reached); 'reached − unreached' for the fountain",
             "and the campfire (unreached on the early day). A theme is flagged when a difference is",
             "under half of Green's.", ""]
    for theme, month, early, last in THEMES:
        e, l = rows[theme]
        g = gains[theme]
        lines.append(f"{theme} ({month}, days {early} and {last}); gain R {g[0]:.4f} G {g[1]:.4f} B {g[2]:.4f}")
        for name in OBJECTS:
            if name not in l:
                lines.append(f"  {name:9s} not wholly in the window on day {last}")
                continue
            row = f"  {name:9s} vs ground {l[name]['object_L'] - l[name]['ground_L']:+5.1f}"
            if name in ("fountain", "campfire") and name in e:
                diff = l[name]["object_L"] - e[name]["object_L"]
                gd = green_last[name]["object_L"] - green_early[name]["object_L"]
                flag = "  <- under half of Green's" if theme != "green_slope" and diff < gd / 2 else ""
                row += f" | reached − unreached {diff:+5.1f} (Green {gd:+5.1f}){flag}"
            lines.append(row)
        lines.append("")
    out = T.REPO / "docs/design/scene-art/batch4/dark_filter.txt"
    out.write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
