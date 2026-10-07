"""Deliberate-break run for check_theme.py: altered copies of a theme image,
made in memory (the sources are never touched), must each FAIL.

    build/scene_art_venv/bin/python tool/scene_art/break_check.py [<image> ...]

For green/background_dark.png, and any further image given (relative to
docs/design/scene-art/source/ or absolute):
  shift_8px    moved 8 px right (the flag limit catches it)
  shift_20px   moved 20 px right
  scale_1.5pct enlarged 1.5 % about the centre, cropped back
  C3_covered   clearing C3 painted over with the cliff below it (the
               clearing check's case: a theme that lost a clearing)

Writes theme_check_break.txt next to theme_check.txt (SCENE_ART_OUT or
docs/design/scene-art/batch0/). Exit code 1 if any copy passes.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

import check_theme as C
import trail as T


def broken(path: Path, ref: C.Reference) -> list[tuple[str, Image.Image]]:
    src = Image.open(path).convert("RGB")
    w, h = src.size
    out = []
    for dx in (8, 20):
        im = Image.new("RGB", (w, h))
        im.paste(src.crop((0, 0, w - dx, h)), (dx, 0))
        im.paste(src.crop((0, 0, 1, h)).resize((dx, h)), (0, 0))  # repeat the edge
        out.append((f"shift_{dx}px", im))
    big = src.resize((round(w * 1.015), round(h * 1.015)), Image.LANCZOS)
    x0, y0 = (big.width - w) // 2, (big.height - h) // 2
    out.append(("scale_1.5pct", big.crop((x0, y0, x0 + w, y0 + h))))
    (cx, cy), (bw, bh) = ref.clearings[2]["center_px"], ref.clearings[2]["box_px"]
    box = (int(cx - bw / 2), int(cy - bh / 2), int(cx + bw / 2), int(cy + bh / 2))
    covered = src.copy()
    covered.paste(src.crop((box[0], box[1] + 220, box[2], box[3] + 220)), box[:2])
    out.append(("C3_covered", covered))
    return out


def main(argv: list[str]) -> int:
    bases = [T.SOURCE / "green/background_dark.png"] + [
        Path(a) if Path(a).is_absolute() else T.SOURCE / a for a in argv]
    ref = C.Reference()
    verdicts, body = [], []
    for base in bases:
        stem = f"{base.parent.name}/{base.stem}"
        for kind, im in broken(base, ref):
            r = C.check(ref, im)
            verdicts.append(r["ok"])
            body += C.describe(f"{stem} {kind}", r) + [""]
    ok = not any(verdicts)
    lines = ["Deliberate break: each altered copy must FAIL.",
             "RESULT: every copy FAILS, as it must" if ok else "RESULT: a copy PASSED, the check is too loose",
             ""] + body
    T.OUT.mkdir(parents=True, exist_ok=True)
    (T.OUT / "theme_check_break.txt").write_text("\n".join(lines))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
