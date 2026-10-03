"""Batch 5 (N3, N23): the medals as app assets.

    build/scene_art_venv/bin/python tool/medals/export_medal_assets.py
    build/scene_art_venv/bin/python tool/medals/export_medal_assets.py --check

Runs build_medals.py, unchanged, on docs/design/medals/source/ at SIZE px
(into a temporary folder: the composed PNGs are not kept, N3), and writes
each as assets/medals/<name>.webp: lossy WebP quality QUALITY, alpha
lossless (libwebp's default), method 6. 13 files: medal_<theme>_<tier> for
the four theme ids and three tiers, and medal_welcome.

SIZE (N23): 384 px. The largest medal the app draws is the celebration's,
a 112 pt disc, whose square canvas is 112 × 768 / 681.95 = 126 pt, 378 px
at 3x (docs/design/batch5/medal_assets.txt); 384 covers it. A medal above
128 pt would need 512.

--check: makes the 13 again from the current sources and compares them
with the committed assets: the same bytes, or (another libwebp) pixels
within MAX_DIFF. Exit code 1 when one is missing or stale, so a source
changed without a re-export is caught. Writes docs/design/batch5/assets/
medal_check.txt; the export writes medal_export.txt there.
"""

from __future__ import annotations

import io
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "docs/design/medals/source"
ASSETS = REPO / "assets/medals"
OUT = REPO / "docs/design/batch5/assets"
SIZE = 384
QUALITY = 90
MAX_DIFF = 2
THEMES = ("green_slope", "ember_peak", "glacier_peak", "red_canyon")
TIERS = ("gold", "silver", "bronze")
NAMES = [f"medal_{t}_{r}" for t in THEMES for r in TIERS] + ["medal_welcome"]


def make() -> dict[str, bytes]:
    """The 13 WebPs, made now from the sources."""
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([sys.executable, str(Path(__file__).with_name("build_medals.py")),
                        str(SOURCE), tmp, str(SIZE)], check=True, stdout=subprocess.DEVNULL)
        out = {}
        for name in NAMES:
            buf = io.BytesIO()
            Image.open(Path(tmp) / f"{name}.png").convert("RGBA").save(buf, "WEBP", quality=QUALITY, method=6)
            out[name] = buf.getvalue()
        return out


def export() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    made = make()
    lines = [f"Batch 5 N23: the medal assets (tool/medals/export_medal_assets.py): {SIZE} x {SIZE} px, "
             f"WebP q{QUALITY}, alpha lossless, method 6.", ""]
    for name, data in made.items():
        (ASSETS / f"{name}.webp").write_bytes(data)
        lines.append(f"assets/medals/{name}.webp  {len(data):6d} bytes")
    total = sum(len(d) for d in made.values())
    lines += ["", f"13 files, {total} bytes ({total / 1000:.1f} KB)."]
    (OUT / "medal_export.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def check() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    made = make()
    lines = ["Batch 5: the medal assets against their sources (export_medal_assets.py --check)", ""]
    failed = False
    for name, fresh in made.items():
        path = ASSETS / f"{name}.webp"
        rel = path.relative_to(REPO)
        if not path.exists():
            lines.append(f"FAIL {rel}: missing")
            failed = True
            continue
        stored = path.read_bytes()
        if stored == fresh:
            lines.append(f"ok   {rel}: same bytes as the export makes now")
            continue
        a = np.asarray(Image.open(io.BytesIO(fresh)).convert("RGBA"), dtype=np.int16)
        b = np.asarray(Image.open(path).convert("RGBA"), dtype=np.int16)
        diff = int(np.abs(a - b).max()) if a.shape == b.shape else 255
        ok = diff <= MAX_DIFF
        failed |= not ok
        lines.append(f"{'ok  ' if ok else 'FAIL'} {rel}: bytes differ, max pixel difference {diff}")
    extra = sorted(p.name for p in ASSETS.glob("*.webp") if p.stem not in made)
    if extra:
        failed = True
        lines.append(f"FAIL unexpected assets: {', '.join(extra)}")
    (OUT / "medal_check.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 1 if failed else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        sys.exit(check())
    export()
