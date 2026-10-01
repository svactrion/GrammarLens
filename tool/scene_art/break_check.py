"""Deliberate-break run for check_theme.py: three altered copies of
green/background_dark.png, written to a temporary directory (the sources are
never touched), must each FAIL.

    build/scene_art_venv/bin/python tool/scene_art/break_check.py

  shift_8px    moved 8 px right (the flag limit catches it)
  shift_20px   moved 20 px right
  scale_1.5pct enlarged 1.5 % about the center, cropped back

Writes docs/design/scene-art/batch0/theme_check_break.txt. Exit code 1 if
any copy passes.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

import trail as T


def main() -> int:
    src = Image.open(T.SOURCE / "green/background_dark.png").convert("RGB")
    w, h = src.size
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for dx in (8, 20):
            out = Image.new("RGB", (w, h))
            out.paste(src.crop((0, 0, w - dx, h)), (dx, 0))
            out.paste(src.crop((0, 0, 1, h)).resize((dx, h)), (0, 0))  # repeat the edge
            out.save(tmp / f"shift_{dx}px.png")
        big = src.resize((round(w * 1.015), round(h * 1.015)), Image.LANCZOS)
        x0, y0 = (big.width - w) // 2, (big.height - h) // 2
        big.crop((x0, y0, x0 + w, y0 + h)).save(tmp / "scale_1.5pct.png")
        names = ["shift_8px.png", "shift_20px.png", "scale_1.5pct.png"]
        run = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("check_theme.py"))]
            + [str(tmp / n) for n in names],
            env={**os.environ, "SCENE_ART_OUT": str(tmp / "out")},
            capture_output=True, text=True, check=False)
        if "Traceback" in run.stderr:
            sys.stderr.write(run.stderr)
            return 2
        text = run.stdout.replace(str(tmp) + "/", "")
    verdicts = [l for l in text.splitlines() if "to the reference)" in l]
    ok = len(verdicts) == 3 and all(v.endswith("FAIL") for v in verdicts)
    T.OUT.mkdir(parents=True, exist_ok=True)
    (T.OUT / "theme_check_break.txt").write_text(
        "Deliberate break: each altered copy must FAIL.\n"
        + ("RESULT: all three FAIL, as they must\n" if ok else "RESULT: a copy PASSED, the check is too loose\n")
        + "\n" + "\n".join(l for l in text.splitlines() if "worst body point" not in l) + "\n")
    print(text)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
