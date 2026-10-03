"""App Store screenshots (1.1.0 release): frames the raw simulator captures
in the style of the 1.0.0 set and writes an overview.

    build/scene_art_venv/bin/python tool/screenshots/frame.py

Reads build/screenshots/raw/<device>/NN-<name>.png (capture.sh; raw
captures are not kept in the repository, P8) and tool/screenshots/captions.json; writes
docs/design/release-1.1.0/screenshots/<device>/NN-<name>.png at the raw
capture's own size (the App Store size: iPhone 6.9" 1320 x 2868, iPad 13"
2064 x 2752) and overview.jpg (every frame, reduced).

The 1.0.0 set's own framing tool is not in the repository and was not
found on this Mac (only two earlier iterations, which draw a different
style; docs/design/release-1.1.0/screenshots/README.md). This rebuilds
its style from measurements of the eight committed images
(screenshots/1.0.0/, 600 x 1298): every number below is in that
600-wide reference and scaled to the canvas.
- Background: a vertical gradient, (250, 243, 236) at the top to
  (246, 232, 217) at the bottom.
- An orange dash (254, 133, 45), 34 x 5, centred, 30 above the title.
- The title: one line, or two when wider than 456; colour (42, 26, 14);
  a line 36 tall, two lines 52.5 apart; the title block centred at 136.
  Typeface: the 1.0.0 titles look like Nunito (rounded); the repository
  has only the app's Nunito Sans, used here at weight 800 (not the same
  face: to be decided).
- The device: screen 446 x 969 at (77, 266) on the iPhone, corner radius
  55; a black bezel 9.5 wide and a grey rim 4 wide around it; side
  buttons; a soft shadow. The simulator capture has no Dynamic Island, so
  the island is drawn, as in 1.0.0. On the iPad the frame keeps the same
  top, bottom, bezel and rim, with the iPad's 3:4 screen, its smaller
  corner radius and no island.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
SHOTS = REPO / "docs/design/release-1.1.0/screenshots"
RAW = REPO / "build/screenshots/raw"
FONT = REPO / "assets/fonts/NunitoSans-Variable.ttf"
CAPTIONS = json.loads((Path(__file__).parent / "captions.json").read_text())

REF_W, REF_H = 600.0, 1298.0
BG_TOP, BG_BOTTOM = (250, 243, 236), (246, 232, 217)
DASH = (254, 133, 45)
INK = (42, 26, 14)
BEZEL = (12, 12, 14)
RIM_OUT, RIM_IN = (155, 158, 164), (117, 120, 125)
SHADOW = (64, 52, 39)


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([800])
    return f


def gradient(w: int, h: int) -> Image.Image:
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return col.resize((w, h))


def title_lines(text: str, f: ImageFont.FreeTypeFont, max_w: float) -> list[str]:
    """One line if it fits, else the most even two-line split."""
    if "\n" in text:
        return text.split("\n")
    if f.getlength(text) <= max_w:
        return [text]
    words = text.split()
    best = min(range(1, len(words)),
               key=lambda i: max(f.getlength(" ".join(words[:i])), f.getlength(" ".join(words[i:]))))
    return [" ".join(words[:best]), " ".join(words[best:])]


def fit_font(height: float) -> ImageFont.FreeTypeFont:
    """The size whose 'Your climb, your streak' ink is [height] tall, as in 1.0.0."""
    size = 10
    while True:
        box = font(size + 1).getbbox("Your climb, your streak")
        if box[3] - box[1] > height:
            return font(size)
        size += 1


def frame(raw: Path, caption: str, device: str) -> Image.Image:
    shot = Image.open(raw).convert("RGB")
    W, H = shot.size
    sx, sy = W / REF_W, H / REF_H
    s = min(sx, sy)  # text and strokes: the canvas's tighter axis
    out = gradient(W, H)
    d = ImageDraw.Draw(out)

    # Title and dash.
    f = fit_font(36 * s)
    lines = title_lines(caption, f, 456 * sx if device == "iphone" else 456 * s * 1.4)
    pitch = 52.5 * s
    block_h = 36 * s + pitch * (len(lines) - 1)
    top = 136 * sy - block_h / 2
    for i, line in enumerate(lines):
        box = f.getbbox(line)
        x = (W - (box[2] - box[0])) / 2 - box[0]
        y = top + i * pitch - box[1]
        d.text((x, y), line, font=f, fill=INK)
    dash_w, dash_h = 34 * s, 5 * s
    dash_y = top - 30 * s - dash_h
    d.rounded_rectangle(((W - dash_w) / 2, dash_y, (W + dash_w) / 2, dash_y + dash_h),
                        radius=dash_h / 2, fill=DASH)

    # The device: the screen's box, then bezel and rim around it.
    scr_top, scr_bottom = 266 * sy, 1235 * sy
    scr_h = scr_bottom - scr_top
    scr_w = scr_h * W / H
    scr_left = (W - scr_w) / 2
    radius = (55 / 446 if device == "iphone" else 0.045) * scr_w
    bezel, rim = 9.5 * s, 4 * s
    screen = (scr_left, scr_top, scr_left + scr_w, scr_bottom)

    def grow(box, by):
        return (box[0] - by, box[1] - by, box[2] + by, box[3] + by)

    body = grow(screen, bezel + rim)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (body[0], body[1] + 16 * s, body[2], body[3] + 16 * s), radius=radius + bezel + rim, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18 * s))
    out.paste(Image.new("RGB", (W, H), SHADOW), (0, 0), shadow)
    d = ImageDraw.Draw(out)

    if device == "iphone":
        # Side buttons (1.0.0: action, volume up and down on the left;
        # power and camera control on the right), 3 wide outside the rim.
        for y0, y1 in ((449, 481), (505, 565), (580, 640)):
            d.rounded_rectangle((body[0] - 3 * s, y0 * sy, body[0] + 2 * s, y1 * sy), radius=2 * s, fill=RIM_IN)
        for y0, y1 in ((533, 625), (836, 887)):
            d.rounded_rectangle((body[2] - 2 * s, y0 * sy, body[2] + 3 * s, y1 * sy), radius=2 * s, fill=RIM_IN)
    d.rounded_rectangle(body, radius=radius + bezel + rim, fill=RIM_OUT)
    d.rounded_rectangle(grow(screen, bezel + rim * 0.4), radius=radius + bezel + rim * 0.4, fill=RIM_IN)
    d.rounded_rectangle(grow(screen, bezel), radius=radius + bezel, fill=BEZEL)

    inner = shot.resize((round(scr_w), round(scr_h)), Image.LANCZOS)
    mask = Image.new("L", inner.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), radius=radius, fill=255)
    out.paste(inner, (round(scr_left), round(scr_top)), mask)

    if device == "iphone":
        # The Dynamic Island of an iPhone 17 Pro Max: 126 x 37 pt, 11 pt
        # from the top of its 440 x 956 pt screen.
        k = scr_w / 440
        iw, ih, it = 126 * k, 37 * k, 11 * k
        cx = scr_left + scr_w / 2
        d.rounded_rectangle((cx - iw / 2, scr_top + it, cx + iw / 2, scr_top + it + ih), radius=ih / 2, fill=(0, 0, 0))
    return out


def overview(paths: dict[str, list[Path]]) -> Image.Image:
    rows = []
    for device in ("iphone", "ipad"):
        ims = [Image.open(p) for p in paths.get(device, [])]
        if not ims:
            continue
        h = 560
        ims = [im.resize((round(im.width * h / im.height), h), Image.LANCZOS) for im in ims]
        gap = 16
        row = Image.new("RGB", (sum(i.width for i in ims) + gap * (len(ims) + 1), h + 2 * gap), (231, 225, 220))
        x = gap
        for im in ims:
            row.paste(im.convert("RGB"), (x, gap))
            x += im.width + gap
        rows.append(row)
    W = max(r.width for r in rows)
    out = Image.new("RGB", (W, sum(r.height for r in rows)), (231, 225, 220))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    return out


def main() -> None:
    written: dict[str, list[Path]] = {}
    for device in ("iphone", "ipad"):
        raws = sorted((RAW / device).glob("*.png"))
        if not raws:
            continue
        (SHOTS / device).mkdir(parents=True, exist_ok=True)
        # Frames from an earlier order or naming do not linger.
        for old in (SHOTS / device).glob("*.png"):
            old.unlink()
        for raw in raws:
            name = raw.stem
            out = SHOTS / device / f"{name}.png"
            frame(raw, CAPTIONS[name.split("-", 1)[1]], device).save(out, optimize=True)
            written.setdefault(device, []).append(out)
            print(out.relative_to(REPO))
    overview(written).save(SHOTS / "overview.jpg", quality=85)
    print((SHOTS / "overview.jpg").relative_to(REPO))


if __name__ == "__main__":
    main()
