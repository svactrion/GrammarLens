"""Scene Art Stage 2 fix: where the summit flag stood, against C5 and C6.

    build/scene_art_venv/bin/python tool/scene_art/flag_clearings.py

Draws, on green/background_light.png, the flag's box as placed in Stage 2
(beside the trail's end) and the boxes of clearings C5 and C6, and
reports which clearing (if any) the flag's base falls in. Writes
docs/design/scene-art/stage2/fix_flag_clearings.jpg and .txt.
"""

from __future__ import annotations

import json

from PIL import Image, ImageDraw

import trail as T
from extract_trail import font

# Stage 2's flag (stage2/placement.json before the fix): base beside the
# trail's end, 116 px wide at 2172.
OLD_BASE, OLD_WIDTH, FLAG_ASPECT = (0.57645, 0.16302), 0.05341, 1.29688


def main() -> None:
    trail = json.loads((T.OUT / "trail_green.json").read_text())
    bg = Image.open(T.SOURCE / "green/background_light.png").convert("RGB")
    W, H = bg.size
    d = ImageDraw.Draw(bg)
    f = font(34)
    lines = []
    bx, by = OLD_BASE[0] * W, OLD_BASE[1] * H
    fw = OLD_WIDTH * W
    fh = fw * FLAG_ASPECT
    d.rectangle([bx - fw / 2, by - fh, bx + fw / 2, by], outline=(255, 120, 0), width=6)
    d.text((bx + fw / 2 + 10, by - fh), "flag (Stage 2)", fill=(255, 120, 0), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    inside = []
    for i, c in enumerate(trail["clearings"], 1):
        (cx, cy), (bw, bh) = c["center_norm"], c["box_norm"]
        box = [(cx - bw / 2) * W, (cy - bh / 2) * H, (cx + bw / 2) * W, (cy + bh / 2) * H]
        if i in (5, 6):
            d.ellipse(box, outline=(40, 110, 255), width=6)
            d.text((box[2] + 10, box[1]), f"C{i}", fill=(255, 255, 255), font=f, stroke_width=3, stroke_fill=(40, 110, 255))
        if box[0] <= bx <= box[2] and box[1] <= by <= box[3]:
            inside.append(f"C{i}")
        dist = ((bx - cx * W) ** 2 + (by - cy * H) ** 2) ** 0.5
        lines.append(f"C{i} ({c['side']}): centre ({cx:.4f}, {cy:.4f}), box {c['box_px'][0]:.0f} × {c['box_px'][1]:.0f} px; "
                     f"{dist:.0f} px from the flag's base")
    end = trail["polyline"][-1]
    lines.insert(0, f"Stage 2's flag base: ({OLD_BASE[0]:.4f}, {OLD_BASE[1]:.4f}), 95 px right of and 10 px above the "
                    f"trail's end ({end[0]:.4f}, {end[1]:.4f}); in a clearing: {', '.join(inside) or 'none'}")
    crop = bg.crop((int(0.25 * W), int(0.08 * H), int(0.85 * W), int(0.36 * H)))
    crop.resize((crop.width // 2, crop.height // 2), Image.LANCZOS).save(
        T.REPO / "docs/design/scene-art/stage2/fix_flag_clearings.jpg", quality=86)
    (T.REPO / "docs/design/scene-art/stage2/fix_flag_clearings.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
