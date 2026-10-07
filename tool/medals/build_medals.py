"""Builds the GrammarLens medals: 12 monthly medals (4 themes x 3 tiers) and the Welcome badge.

Monthly: tier body + theme mountain (clipped to the body's inner well) + 1/2/3 stars on top.
Welcome: beige body + start-flag mountain + orange ribbon with "WELCOME" (Poppins Bold, SIL OFL 1.1).
Usage: python3 build_medals.py <medal-design dir> <output dir> [size]
Expected inputs:
  mountains/{green,ember,glacier,redcanyon}_mountain_medal.png
  medal-ranks/medal_{gold,silver,bronze}.png   (identical geometry)
  extras/sharp_star.png
  mountains/welcome_mountain_medal.png, medal-ranks/medal_welcome.png,
  extras/ribbon_orange.png, extras/Poppins-Bold.ttf
"""
import math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

THEMES = {"green_slope": "green", "ember_peak": "ember", "glacier_peak": "glacier", "red_canyon": "redcanyon"}
TIERS = {"gold": 3, "silver": 2, "bronze": 1}
CANVAS = 1254                 # source canvas of the body images
CX, CY, WELL_R = 625, 618, 409  # inner well of the body
TOP_GAP = 36                  # gap between the well's top edge and the peak
REF_BOX = (46, 161, 1208, 1139)  # solid bbox of the reference (green) mountain; all mountains share its framing
STAR_SIZE, STAR_RADIUS, STAR_STEP = 235, 495, 28
THEME_DY = {"ember_peak": 75}  # extra downward shift so the smoke above the peak stays visible


def shadow(layer, off, blur, opacity, color=(60, 35, 0)):
    blk = Image.new("RGBA", layer.size, color + (255,))
    blk.putalpha(layer.split()[3].point(lambda v: int(v * opacity)))
    blk = blk.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(blk, off, blk)
    return out


def build(body, mountain, star, n, dy=0):
    size = body.size
    zero = Image.new("L", size, 0)
    well = Image.new("L", size, 0)
    ImageDraw.Draw(well).ellipse((CX - WELL_R, CY - WELL_R, CX + WELL_R, CY + WELL_R), fill=255)
    # mountain: reference box height fills the well; base overflows and is clipped by the well
    scale = (2 * WELL_R) / (REF_BOX[3] - REF_BOX[1])
    m = mountain.resize((round(mountain.width * scale), round(mountain.height * scale)), Image.LANCZOS)
    ref_cx = (REF_BOX[0] + REF_BOX[2]) / 2 * scale
    x = round(CX - ref_cx)
    y = round(CY - WELL_R + TOP_GAP - REF_BOX[1] * scale) + dy
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    lay.paste(m, (x, y), m)
    lay.putalpha(Image.composite(lay.split()[3], zero, well))
    sh = shadow(lay, (8, 14), 12, 0.45)
    sh.putalpha(Image.composite(sh.split()[3], zero, well))
    out = Image.alpha_composite(Image.alpha_composite(body, sh), lay)
    # inner rim shadow so the mountain sits inside the well
    ring = Image.new("L", size, 0)
    ImageDraw.Draw(ring).ellipse((CX - WELL_R - 6, CY - WELL_R - 6, CX + WELL_R + 6, CY + WELL_R + 6), outline=255, width=26)
    ring = Image.composite(ring.filter(ImageFilter.GaussianBlur(11)), zero, well).point(lambda v: int(v * 0.42))
    dark = Image.new("RGBA", size, (50, 28, 0, 255))
    dark.putalpha(ring)
    out = Image.alpha_composite(out, dark)
    # stars on the top rim
    sw = STAR_SIZE
    sh_ = round(star.height * sw / star.width)
    sl = Image.new("RGBA", size, (0, 0, 0, 0))
    for i in range(n):
        ang = 270 + STAR_STEP * (i - (n - 1) / 2)
        s = star.resize((sw, sh_), Image.LANCZOS).rotate(-(ang - 270) * 0.9, resample=Image.BICUBIC, expand=True)
        px = CX + STAR_RADIUS * math.cos(math.radians(ang))
        py = CY + STAR_RADIUS * math.sin(math.radians(ang))
        sl.alpha_composite(s, (round(px - s.width / 2), round(py - s.height / 2)))
    return Image.alpha_composite(Image.alpha_composite(out, shadow(sl, (5, 9), 8, 0.55)), sl)


WELCOME_DY = 12                      # mountain shift so the ribbon clears the peak
RIBBON_WIDTH, RIBBON_TOP = 1190, 2   # ribbon placement on the 1254 canvas
RIBBON_ARC = (1086, 300, 4511)       # text arc on the ribbon source: centre x, mid-line y, radius
TEXT_SIZE, TEXT_TRACK, TEXT_COLOR = 190, 26, (255, 246, 230, 255)


def ribbon_with_text(ribbon, font_path, text="WELCOME"):
    font = ImageFont.truetype(str(font_path), TEXT_SIZE)
    cx, cy0, rt = RIBBON_ARC
    d = ImageDraw.Draw(ribbon)
    adv = [d.textlength(ch, font=font) for ch in text]
    pos = -(sum(adv) + TEXT_TRACK * (len(text) - 1)) / 2
    lay = Image.new("RGBA", ribbon.size, (0, 0, 0, 0))
    for ch, a in zip(text, adv):
        th = (pos + a / 2) / rt
        x, y = cx + rt * math.sin(th), cy0 + rt - rt * math.cos(th)
        g = Image.new("RGBA", (int(a) + 80, TEXT_SIZE + 120), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((g.width / 2, g.height / 2), ch, font=font, fill=TEXT_COLOR, anchor="mm")
        g = g.rotate(-math.degrees(th), resample=Image.BICUBIC)
        lay.alpha_composite(g, (int(x - g.width / 2), int(y - g.height / 2)))
        pos += a + TEXT_TRACK
    return Image.alpha_composite(Image.alpha_composite(ribbon, shadow(lay, (4, 7), 5, 0.5, (150, 60, 0))), lay)


def build_welcome(body, mountain, ribbon, font_path):
    out = build(body, mountain, Image.new("RGBA", (10, 10), (0, 0, 0, 0)), 0, WELCOME_DY)
    r = ribbon_with_text(ribbon.copy(), font_path)
    r = r.resize((RIBBON_WIDTH, round(r.height * RIBBON_WIDTH / r.width)), Image.LANCZOS)
    lay = Image.new("RGBA", out.size, (0, 0, 0, 0))
    lay.alpha_composite(r, (CX - RIBBON_WIDTH // 2, RIBBON_TOP))
    return Image.alpha_composite(Image.alpha_composite(out, shadow(lay, (5, 10), 9, 0.45)), lay)


def crop_alpha(im):
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 40)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 768
    dst.mkdir(parents=True, exist_ok=True)
    star = crop_alpha(Image.open(src / "extras/sharp_star.png").convert("RGBA"))
    for theme, stem in THEMES.items():
        mountain = Image.open(src / f"mountains/{stem}_mountain_medal.png").convert("RGBA")
        assert mountain.size == (CANVAS, CANVAS), mountain.size
        for tier, n in TIERS.items():
            body = Image.open(src / f"medal-ranks/medal_{tier}.png").convert("RGBA")
            assert body.size == (CANVAS, CANVAS), body.size
            build(body, mountain, star, n, THEME_DY.get(theme, 0)).resize((size, size), Image.LANCZOS).save(dst / f"medal_{theme}_{tier}.png")
            print("wrote", f"medal_{theme}_{tier}.png")
    welcome = build_welcome(
        Image.open(src / "medal-ranks/medal_welcome.png").convert("RGBA"),
        Image.open(src / "mountains/welcome_mountain_medal.png").convert("RGBA"),
        Image.open(src / "extras/ribbon_orange.png").convert("RGBA"),
        src / "extras/Poppins-Bold.ttf",
    )
    welcome.resize((size, size), Image.LANCZOS).save(dst / "medal_welcome.png")
    print("wrote medal_welcome.png")


if __name__ == "__main__":
    main()
