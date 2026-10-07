"""App Store screenshots (1.2.0): frames the raw simulator captures in
the style of the 1.0.0 and 1.1.0 sets, flattens the subscription review
captures, and writes an overview.

    build/scene_art_venv/bin/python tool/screenshots/frame.py

Reads build/screenshots/1.2.0/raw/<device>/<name>.png (capture.sh; raw
captures are not kept in the repository) and tool/screenshots/captions.json;
writes, under screenshots/1.2.0/:
- store/iphone/: the eight store frames at 1284 x 2778 (App Store 6.5");
  06 (Premium Review, Suggested Focus) approved by the owner after the
  device check (2026-10-07);
- store/ipad/: the five store frames at 2064 x 2752 (App Store 13");
- subscription-review/: annual.png and monthly.png, the raw paywall
  captures flattened to RGB, no frame;
- overview.jpg: every store frame, reduced.
Every PNG is written as RGB: the simulator's captures carry an alpha
channel, which App Store Connect does not accept.

The frame (1.1.0, kept):
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
  buttons; a soft shadow. The simulator capture has no notch, so the
  iPhone 14 Plus's notch is drawn (1.1.0 drew a 17 Pro Max's Dynamic
  Island). On the iPad the frame keeps the same
  top, bottom, bezel and rim, with the iPad's 3:4 screen, its smaller
  corner radius and no notch. iPadOS 26 draws a window resize handle in
  the iPad capture's bottom-right corner (the app opens as a resizable
  window); it is system chrome, not the app, and is painted over with the
  colour beside it (owner, Batch 3).
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "screenshots/1.2.0"
RAW = REPO / "build/screenshots/1.2.0/raw"
FONT = REPO / "assets/fonts/NunitoSans-Variable.ttf"
CAPTIONS = json.loads((Path(__file__).parent / "captions.json").read_text())

# The store sets: (raw name, caption key, output name), in the owner's
# order (1.2.0, Batch 1).
STORE = {
    "iphone": [
        ("01-result", "result", "01-result"),
        ("02-home", "home", "02-home"),
        ("03-question", "question", "03-question"),
        ("04-review", "review", "04-review"),
        ("05-weak-spot", "weak-spot", "05-weak-spot"),
        ("06-review-premium", "review-premium", "06-review-premium"),
        ("07-collection", "collection", "07-collection"),
        ("08-goal", "goal", "08-goal"),
    ],
    "ipad": [
        ("01-result", "result", "01-result"),
        ("02-home", "home", "02-home"),
        ("03-question", "question", "03-question"),
        ("04-review", "review", "04-review"),
        ("07-collection", "collection", "05-collection"),
    ],
}
SUBSCRIPTION_REVIEW = [("paywall-annual", "annual"), ("paywall-monthly", "monthly")]

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


def clear_resize_handle(shot: Image.Image) -> Image.Image:
    """Paints over iPadOS 26's window resize handle: a grey arc about 46 px
    across, from (W-54, H-8) to (W-8, H-54). Its core is a mid grey
    (neutral, 90-205: not the keyboard's own grey, about 222, not a black
    icon, not the warm page), in the corner triangle the arc lies in; the
    mask is that core grown by 2 px, to take in the anti-aliased edge. Each
    masked pixel takes the mean of the first unmasked pixels to its left
    and above it."""
    W, H = shot.size
    n = 64
    corner = shot.crop((W - n, H - n, W, H))
    core = Image.new("L", corner.size, 0)
    for x in range(n):
        for y in range(n):
            p = corner.getpixel((x, y))
            if x + y >= 56 and max(p) - min(p) <= 8 and 90 <= max(p) < 205:
                core.putpixel((x, y), 255)
    mask = core.filter(ImageFilter.MaxFilter(5))
    out = shot.copy()
    px = out.load()

    def first_clear(x: int, y: int, dx: int, dy: int) -> tuple[int, ...]:
        while 0 <= x < n and 0 <= y < n and mask.getpixel((x, y)):
            x, y = x + dx, y + dy
        return shot.getpixel((W - n + x, H - n + y))

    for x in range(n):
        for y in range(n):
            if mask.getpixel((x, y)):
                a, b = first_clear(x, y, -1, 0), first_clear(x, y, 0, -1)
                px[W - n + x, H - n + y] = tuple((p + q) // 2 for p, q in zip(a, b))
    return out


def draw_notch(out: Image.Image, scr_left: float, scr_top: float, scr_w: float) -> None:
    """The notch of an iPhone 14 Plus, on its 428 x 926 pt screen: 161 x 32
    pt, centred (the 13/14 notch, 26.8 mm on a 71.3 mm wide screen). Its
    top is the screen's top edge, flat, so nothing reaches past the bezel;
    its lower corners are rounded (19 pt) and it meets the top edge in
    small concave fillets (6 pt). Clear of the status bar: the time ends at
    77 pt, the icons start at 324 pt, the notch spans 133.5-294.5 pt.
    Apple publishes no exact outline; this is drawn to the device's
    proportions. Drawn 4x and reduced, for smooth edges."""
    k = scr_w / 428
    nw, nh, rb, re = 161 * k, 32 * k, 19 * k, 6 * k
    x0 = scr_left + (scr_w - nw) / 2
    pad = re + 2
    # From 2 px above the edge (inside the bezel, which is about 20 px
    # thick): the screen is pasted at a rounded position, and a notch that
    # started exactly at the edge left a 1 px line of the screen above it.
    left, top = int(x0 - pad), int(scr_top) - 2
    w, h = int(nw + 2 * pad) + 2, int(nh) + 4
    ss = 4
    m = Image.new("L", (w * ss, h * ss), 0)
    md = ImageDraw.Draw(m)
    ox, oy = (x0 - left) * ss, (scr_top - top) * ss
    # The body, its top corners pushed above the edge (cut off below).
    md.rounded_rectangle((ox, oy - rb * ss, ox + nw * ss, oy + nh * ss), radius=rb * ss, fill=255)
    # The fillets: a square at each top corner less a circle.
    for side in (-1, 1):
        ex = ox if side == -1 else ox + nw * ss
        sq = (ex - re * ss, oy, ex, oy + re * ss) if side == -1 else (ex, oy, ex + re * ss, oy + re * ss)
        md.rectangle(sq, fill=255)
        cxe = ex - re * ss if side == -1 else ex + re * ss
        md.ellipse((cxe - re * ss, oy, cxe + re * ss, oy + 2 * re * ss), fill=0)
    # Nothing more than 2 px above the screen's top edge.
    md.rectangle((0, 0, w * ss, oy - 2 * ss), fill=0)
    # The 2 px above the edge, over the notch and its fillets.
    md.rectangle((ox - re * ss, oy - 2 * ss, ox + (nw + re) * ss, oy), fill=255)
    m = m.resize((w, h), Image.LANCZOS)
    out.paste(Image.new("RGB", (w, h), BEZEL), (left, top), m)


def frame(raw: Path, caption: str, device: str) -> Image.Image:
    shot = Image.open(raw).convert("RGB")
    if device == "ipad":
        shot = clear_resize_handle(shot)
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
        draw_notch(out, scr_left, scr_top, scr_w)
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
    for device, frames in STORE.items():
        folder = OUT / "store" / device
        folder.mkdir(parents=True, exist_ok=True)
        # Frames from an earlier order or naming do not linger.
        for old in folder.glob("*.png"):
            old.unlink()
        for raw_name, key, name in frames:
            raw = RAW / device / f"{raw_name}.png"
            out = folder / f"{name}.png"
            frame(raw, CAPTIONS[key], device).convert("RGB").save(out, optimize=True)
            written.setdefault(device, []).append(out)
            print(out.relative_to(REPO))
    review = OUT / "subscription-review"
    review.mkdir(parents=True, exist_ok=True)
    for raw_name, name in SUBSCRIPTION_REVIEW:
        out = review / f"{name}.png"
        Image.open(RAW / "iphone" / f"{raw_name}.png").convert("RGB").save(out, optimize=True)
        print(out.relative_to(REPO))
    overview(written).save(OUT / "overview.jpg", quality=85)
    print((OUT / "overview.jpg").relative_to(REPO))


if __name__ == "__main__":
    main()
