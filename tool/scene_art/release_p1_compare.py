"""P1 (1.1.0 release): the iPhone renders before and after the iPad content
width must be identical, pixel for pixel.

    build/scene_art_venv/bin/python tool/scene_art/release_p1_compare.py \\
        build/design_measure/p1_before build/design_measure/p1_after

Compares every PNG under the first folder with the same path under the
second: size and every pixel's RGBA. Prints one line per differing or
missing image and a summary, writes the summary to <after>/compare.txt and
exits non-zero if anything differs.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image


def main(before: Path, after: Path) -> int:
    same = differ = missing = 0
    lines = []
    for b in sorted(before.rglob("*.png")):
        rel = b.relative_to(before)
        a = after / rel
        if not a.exists():
            missing += 1
            lines.append(f"missing after: {rel}")
            continue
        x = np.asarray(Image.open(b).convert("RGBA"))
        y = np.asarray(Image.open(a).convert("RGBA"))
        if x.shape != y.shape:
            differ += 1
            lines.append(f"size differs: {rel} {x.shape} -> {y.shape}")
            continue
        d = np.abs(x.astype(int) - y.astype(int)).max(axis=2)
        n = int((d > 0).sum())
        if n:
            differ += 1
            lines.append(f"pixels differ: {rel}: {n} px, largest channel difference {int(d.max())}")
        else:
            same += 1
    total = same + differ + missing
    lines.append(f"{total} images: {same} identical, {differ} differ, {missing} missing after")
    (after / "compare.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0 if differ == 0 and missing == 0 else 1


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), Path(sys.argv[2])))
