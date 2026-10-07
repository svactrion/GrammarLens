"""README and case-study images (1.2.0), from the raw captures and the
framed store set.

    build/scene_art_venv/bin/python tool/screenshots/assets.py

Run after capture.sh and frame.py. Writes, under screenshots/1.2.0/:

readme/
  hero.png        three framed iPhones (Home, Result, Question) on the
                  store set's cream gradient, 1800 x 1100;
  04-review.png, 05-weak-spot.png, 07-collection.png, 08-goal.png
                  the store frames at 600 x 1298 (06 stays out while it is
                  on hold).

case-study/       for ahmettayfur.com's GrammarLens page. Its current
                  images are raw app screenshots at 600 x 1298 webp, so
                  these are too, from the unframed captures, under the
                  same names:
  daily-test-explanation, day0-1-test, day0-2-result, day0-3-climb,
  day0-4-paywall, practice-offer-card
                  and new ones: onboarding-goal, home-glacier,
                  weak-spot-premium;
  compare-home-free-premium, compare-review-free-premium,
  compare-home-1.0.0-1.2.0, compare-paywall-1.0.0-1.2.0
                  two screens side by side with a label over each,
                  1260 x 1398 webp;
  og-candidate.png
                  1672 x 941, the size of the site's grammarlens-og.png.

The 1.0.0 side of the comparisons is read from the site repository's
current case-study images (~/projects/ahmettayfur, read only, never
written). Its Home greets the owner by his real name: the name is
blurred, as no image here carries personal data.
Every image is written as RGB (no alpha).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
RAW = REPO / "build/screenshots/1.2.0/raw/iphone"
STORE = REPO / "screenshots/1.2.0/store/iphone"
OUT = REPO / "screenshots/1.2.0"
SITE = Path.home() / "projects/ahmettayfur/public/img/case-study/grammarlens"
FONT = REPO / "assets/fonts/NunitoSans-Variable.ttf"

BG_TOP, BG_BOTTOM = (250, 243, 236), (246, 232, 217)
INK = (42, 26, 14)
MUTED = (110, 96, 84)
ORANGE = (254, 133, 45)
CASE_W, CASE_H = 600, 1298

# Case-study image <- raw capture.
CASE = {
    "daily-test-explanation": "01-result",
    "day0-1-test": "day0-1-test",
    "day0-2-result": "day0-2-result",
    "day0-3-climb": "day0-3-climb",
    "day0-4-paywall": "day0-4-paywall",
    "practice-offer-card": "review-practice-used",
    "onboarding-goal": "08-goal",
    "home-glacier": "02-home",
    "weak-spot-premium": "05-weak-spot-premium",
}

# The owner's name in the site's 1.0.0 Home (600 x 1298): "Ahmet" in
# "Good evening, Ahmet", measured on the image, with a margin.
V1_NAME_BOX = (262, 190, 386, 238)


def font(size: int, weight: int = 800) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([weight])
    return f


def gradient(w: int, h: int) -> Image.Image:
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return col.resize((w, h))


def case_size(im: Image.Image) -> Image.Image:
    return im.convert("RGB").resize((CASE_W, CASE_H), Image.LANCZOS)


def phone(store_png: Path) -> Image.Image:
    """The device cut out of a framed store image along its own outline
    (RGBA), with frame.py's geometry: the screen at 266-1235 of a 1298
    tall reference, centred, bezel 9.5 and rim 4 around it, side buttons 3
    outside the rim. Its background and shadow are left behind, so it can
    sit on any background."""
    im = Image.open(store_png).convert("RGB")
    W, H = im.size
    sx, sy = W / 600, H / 1298
    s = min(sx, sy)
    top, bottom = 266 * sy, 1235 * sy
    scr_w = (bottom - top) * W / H
    left = (W - scr_w) / 2
    grow = (9.5 + 4) * s
    radius = 55 / 446 * scr_w + grow
    body = (left - grow, top - grow, left + scr_w + grow, bottom + grow)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(body, radius=radius, fill=255)
    for y0, y1 in ((449, 481), (505, 565), (580, 640)):
        d.rounded_rectangle((body[0] - 3 * s, y0 * sy, body[0] + 2 * s, y1 * sy), radius=2 * s, fill=255)
    for y0, y1 in ((533, 625), (836, 887)):
        d.rounded_rectangle((body[2] - 2 * s, y0 * sy, body[2] + 3 * s, y1 * sy), radius=2 * s, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    box = (int(body[0] - 4 * s), int(body[1]), int(body[2] + 4 * s) + 1, int(body[3]) + 1)
    return out.crop(box)


def place(canvas: Image.Image, device: Image.Image, h: int, cx: int, top: int) -> None:
    """[device] scaled to [h] tall, centred on [cx], with a soft shadow."""
    p = device.resize((round(device.width * h / device.height), h), Image.LANCZOS)
    x = cx - p.width // 2
    shadow = Image.new("L", canvas.size, 0)
    alpha = p.getchannel("A").point(lambda a: a * 100 // 255)
    shadow.paste(alpha, (x, top + h // 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(h / 45))
    canvas.paste(Image.new("RGB", canvas.size, (64, 52, 39)), (0, 0), shadow)
    canvas.paste(p, (x, top), p)


def hero() -> Image.Image:
    W, H = 1800, 1100
    out = gradient(W, H)
    place(out, phone(STORE / "01-result.png"), 900, 470, 130)
    place(out, phone(STORE / "03-question.png"), 900, W - 470, 130)
    place(out, phone(STORE / "02-home.png"), 1000, W // 2, 50)
    return out


def labelled_pair(left: Image.Image, right: Image.Image, labels: tuple[str, str]) -> Image.Image:
    gap, pad, band = 20, 20, 80
    W = 2 * CASE_W + gap + 2 * pad
    H = CASE_H + band + pad
    out = Image.new("RGB", (W, H), BG_TOP)
    d = ImageDraw.Draw(out)
    f = font(40)
    for i, (im, text) in enumerate(zip((left, right), labels)):
        x = pad + i * (CASE_W + gap)
        box = f.getbbox(text)
        d.text((x + (CASE_W - (box[2] - box[0])) / 2 - box[0], (band - (box[3] - box[1])) / 2 - box[1]),
               text, font=f, fill=INK)
        out.paste(case_size(im), (x, band))
    return out


def blur_box(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    im = im.convert("RGB")
    region = im.crop(box).filter(ImageFilter.GaussianBlur(9))
    im.paste(region, box[:2])
    return im


def og() -> Image.Image:
    """1672 x 941: the wordmark, a line, three framed iPhones."""
    W, H = 1672, 941
    out = gradient(W, H)
    d = ImageDraw.Draw(out)
    x = 96
    wm = font(110, 900)
    d.text((x, 250), "Grammar", font=wm, fill=INK)
    d.text((x + wm.getlength("Grammar"), 250), "Lens", font=wm, fill=ORANGE)
    d.rounded_rectangle((x, 410, x + 64, 420), radius=5, fill=ORANGE)
    head = font(52, 800)
    for i, line in enumerate(("Your personal", "grammar coach")):
        d.text((x, 450 + i * 66), line, font=head, fill=INK)
    body = font(30, 500)
    for i, line in enumerate(("A daily test, every answer explained,",
                              "and a mountain to climb each month.")):
        d.text((x, 610 + i * 44), line, font=body, fill=MUTED)
    # The side phones end inside the canvas, 30 px from the right edge.
    place(out, phone(STORE / "01-result.png"), 660, 1090, 170)
    place(out, phone(STORE / "03-question.png"), 660, 1470, 170)
    place(out, phone(STORE / "02-home.png"), 780, 1280, 80)
    return out


def save(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im = im.convert("RGB")
    if path.suffix == ".webp":
        im.save(path, quality=90, method=6)
    else:
        im.save(path, optimize=True)
    print(path.relative_to(REPO), im.size)


def main() -> None:
    save(hero(), OUT / "readme/hero.png")
    for name in ("04-review", "05-weak-spot", "07-collection", "08-goal"):
        im = Image.open(STORE / f"{name}.png")
        save(im.resize((CASE_W, CASE_H), Image.LANCZOS), OUT / f"readme/{name}.png")

    case = OUT / "case-study"
    for name, raw in CASE.items():
        save(case_size(Image.open(RAW / f"{raw}.png")), case / f"{name}.webp")
    raw = lambda n: Image.open(RAW / f"{n}.png")
    save(labelled_pair(raw("home-free"), raw("home-premium"), ("Free", "Premium")),
         case / "compare-home-free-premium.webp")
    save(labelled_pair(raw("04-review"), raw("06-review-premium"), ("Free", "Premium")),
         case / "compare-review-free-premium.webp")
    v1_home = blur_box(Image.open(SITE / "day0-3-climb.webp"), V1_NAME_BOX)
    save(labelled_pair(v1_home, raw("02-home"), ("1.0.0", "1.2.0")),
         case / "compare-home-1.0.0-1.2.0.webp")
    v1_paywall = Image.open(SITE / "day0-4-paywall.webp")
    save(labelled_pair(v1_paywall, raw("paywall-annual"), ("1.0.0", "1.2.0")),
         case / "compare-paywall-1.0.0-1.2.0.webp")
    save(og(), case / "og-candidate.png")


if __name__ == "__main__":
    main()
