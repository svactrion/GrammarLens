"""Scene Art Batch 0, step 3: framing and scale of the illustrated scene in
the Home card's window. Renders and numbers only; no product code.

    build/scene_art_venv/bin/python tool/scene_art/framing.py

Options (at the card widths of 320, 375 and 430 pt screens):
  K-a      the image fits the card's width; the camera follows the avatar
           vertically
  K-b 1.3  fitted to the width, then zoomed 1.3x; the camera follows the
           avatar on both axes
  K-b 1.6  the same at 1.6x
  K-c      the whole image fits the window's height; bands at the sides

Writes framing_numbers.txt, framing_<screen>.jpg (one sheet per screen
width: day 3, day 25, the whole mountain) and framing_overview.jpg (375 pt).
"""

from __future__ import annotations

import json
import warnings

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import trail as T
from trail import horizontal_chord
from extract_trail import font

warnings.filterwarnings("ignore", category=RuntimeWarning)

# --- The Home card today (lib/widgets/monthly_climb/, tool/design_measure) --
WINDOW_H = 350.0  # ClimbCamera.windowHeight
PAWN_AT = 0.72  # ClimbCamera.pawnAt: the avatar at 72 % of the window
SCREENS = (320, 375, 430)


def card_width(screen: float) -> float:
    """tool/design_measure/layouts.dart cardWidth: the window is the card's
    full width (the frame is a foreground border)."""
    return screen - 2 * min(max(screen * 0.045, 16), 28)


# Today's avatar (F1): AvatarTile radius 29 scene units x 350/480 pt per
# unit = a 42.3 pt tile. Its ground shadow is 1.3 x radius = 0.65 of the
# tile (avatar_tile.dart): the avatar's footprint. Measured on the 16
# bundled avatars, the widest body is 0.894 of the tile (avatar_03).
AVATAR_TODAY = 2 * 29 * 350 / 480
SHADOW_SHARE = 0.65
BODY_SHARE = 0.894
# Feet sit on the step: AvatarTile's box top is 55/58 of its side above the
# step (monthly_mountain.dart), so the box bottom is 3/58 below it.
AVATAR_TOP = 55 / 58

# Today's step pill: 18 scene units long (ClimbRoute.stepMarkerSize) at
# 350/480 pt per unit, 13.1 pt; the gap between neighbours is centre
# distance minus that, if pills are kept (an open question, report §5).
PILL_LEN = 18 * 350 / 480

# The summit: the top of the snow cap, marked by hand on
# green/background_light.png (the snow joins the sky in any colour mask).
PEAK = (0.5087, 0.1133)

# The month and step chips cover about the top 48 pt of the window
# (plaque half-height + 6 pt + chip; climb_card.dart). Approximate.
CHIP_BAND = 48.0

OPTIONS = (("K-a", "width", 1.0), ("K-b 1.3", "width", 1.3),
           ("K-b 1.6", "width", 1.6), ("K-c", "height", 1.0))


class Frame:
    def __init__(self, kind: str, zoom: float, card_w: float, img: tuple[int, int]):
        self.card_w, self.img = card_w, img
        w, h = img
        self.s = (card_w / w if kind == "width" else WINDOW_H / h) * zoom  # pt per px
        self.vis_w = min(w, card_w / self.s)  # px of image across the window
        self.vis_h = min(h, WINDOW_H / self.s)
        self.left_pt = max(0.0, (card_w - w * self.s) / 2)  # K-c side band

    def offset(self, p) -> tuple[float, float]:
        """Image px at the window's top left with the avatar at [p]."""
        w, h = self.img
        ox = min(max(p[0] - self.vis_w / 2, 0), w - self.vis_w)
        oy = min(max(p[1] - PAWN_AT * self.vis_h, 0), h - self.vis_h)
        return ox, oy

    def to_pt(self, p, off) -> tuple[float, float]:
        return (self.left_pt + (p[0] - off[0]) * self.s, (p[1] - off[1]) * self.s)

    def visible(self, p, off, top_margin=0.0) -> bool:
        x, y = self.to_pt(p, off)
        return 0 <= x <= self.card_w and top_margin <= y <= WINDOW_H


def avatar_sprite() -> Image.Image:
    return Image.open(T.REPO / "assets/avatars/avatar_01.webp").convert("RGBA")


def render(bg: Image.Image, f: Frame, day_pt, avatar_pt: float, sprite, scale=2,
           steps_pt=None, label: str = "") -> Image.Image:
    """The 350 pt window at [scale] px per pt: background, avatar (ground
    shadow and sprite), rounded corners and the card's outline."""
    W, H = round(f.card_w * scale), round(WINDOW_H * scale)
    canvas = Image.new("RGB", (W, H), (236, 238, 232))
    off = day_pt["off"]
    k = f.s * scale
    crop = bg.crop((int(off[0]), int(off[1]),
                    int(np.ceil(off[0] + f.vis_w)), int(np.ceil(off[1] + f.vis_h))))
    crop = crop.resize((round(crop.width * k), round(crop.height * k)), Image.LANCZOS)
    canvas.paste(crop, (round(f.left_pt * scale), 0))
    d = ImageDraw.Draw(canvas, "RGBA")
    if steps_pt:
        for x, y in steps_pt:
            d.ellipse([x * scale - 3, y * scale - 3, x * scale + 3, y * scale + 3], fill=(255, 210, 0, 220), outline=(0, 0, 0, 200))
    side = avatar_pt * scale
    x, y = day_pt["pt"][0] * scale, day_pt["pt"][1] * scale
    sh_w, sh_h = SHADOW_SHARE * side, 0.16 * side
    shadow = Image.new("RGBA", (round(sh_w * 2), round(sh_h * 4)), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([sh_w / 2, sh_h * 1.5, sh_w * 1.5, sh_h * 2.5], fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(side * 0.08))
    top = y - AVATAR_TOP * side
    canvas.paste(shadow, (round(x - sh_w), round(top + side * 0.88 - sh_h * 2)), shadow)
    spr = sprite.resize((max(1, round(side)), max(1, round(side))), Image.LANCZOS)
    canvas.paste(spr, (round(x - side / 2), round(top)), spr)
    # Rounded corners (radius 20 pt) and the outline.
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], 20 * scale, fill=255)
    out = Image.new("RGB", (W, H), (255, 255, 255))
    out.paste(canvas, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([0, 0, W - 1, H - 1], 20 * scale, outline=(150, 150, 150), width=2)
    if label:
        ImageDraw.Draw(out).text((10 * scale, H - 18 * scale), label, fill=(0, 0, 0), font=font(int(11 * scale)),
                                 stroke_width=3, stroke_fill=(255, 255, 255))
    return out


def main() -> None:
    t = T.extract(T.SOURCE / "green/background_light.png")
    w, h = t.size
    peak = (PEAK[0] * w, PEAK[1] * h)
    days = 31
    steps = t.steps(days)
    arc = t.length_px / days
    centre = np.linalg.norm(np.diff(steps, axis=0), axis=1)
    chords = np.array([horizontal_chord(t.mask, p) for p in steps])
    perp = t.width_at(np.linspace(0, t.length_px, days + 1))
    lines = []
    out = lines.append
    out(f"source: {t.image} {w} x {h} px; 31-day month; window {WINDOW_H:g} pt tall, avatar at {PAWN_AT:.0%}")
    out(f"card widths: " + ", ".join(f"{s} pt screen -> {card_width(s):g} pt" for s in SCREENS))
    out(f"trail per day: {arc:.1f} px along the trail; neighbour centres {centre.min():.1f}-{centre.max():.1f} px apart")
    out(f"trail at the 32 step points: horizontal chord min {chords.min():.0f} px (day {int(chords.argmin())}, the summit tip), "
        f"min before the summit {chords[:-1].min():.0f} px (day {int(chords[:-1].argmin())}), median {np.median(chords):.0f}; "
        f"across-the-trail width min {perp.min():.0f}, median {np.median(perp):.0f}")
    out("horizontal chord per day (px): " + " ".join(f"{d}:{c:.0f}" for d, c in enumerate(chords)))
    out(f"avatar today (F1): {AVATAR_TODAY:.1f} pt tile; footprint (ground shadow) {SHADOW_SHARE:.2f} of the tile, widest body {BODY_SHARE:.3f}")
    out(f"step pill today: {PILL_LEN:.1f} pt long (gap = centre distance - pill)")
    out(f"summit peak (hand-marked): px ({peak[0]:.0f}, {peak[1]:.0f}); chip band ~{CHIP_BAND:g} pt")
    out("")
    hdr = ("option", "screen", "pt/px", "visible", "day step", "min gap", "K1", "avatar fit", "peak from", "peak clear from", "3x density")
    out(" | ".join(hdr))
    rows = {}
    bg = Image.open(T.SOURCE / "green/background_light.png").convert("RGB")
    sprite = avatar_sprite()
    for screen in SCREENS:
        cw = card_width(screen)
        for name, kind, zoom in OPTIONS:
            f = Frame(kind, zoom, cw, (w, h))
            vis = (f.vis_w * f.vis_h) / (w * h)
            step_pt = arc * f.s
            gap_centre = centre.min() * f.s
            gap = gap_centre - PILL_LEN
            k1 = step_pt >= 17 and gap >= 5
            # The largest tile whose footprint fits the narrowest chord on
            # the month's steps before the summit, and whose body fits it.
            # The summit (the trail's tip, 63 px) is reported on its own.
            narrow = chords[:-1].min()
            fit_shadow = narrow * f.s / SHADOW_SHARE
            fit_body = narrow * f.s / BODY_SHARE
            fit_summit = chords[-1] * f.s / SHADOW_SHARE
            peak_day = next((d for d in range(days + 1)
                             if all(f.visible(peak, f.offset(steps[e])) for e in range(d, days + 1))), None)
            clear_day = next((d for d in range(days + 1)
                              if all(f.visible(peak, f.offset(steps[e]), CHIP_BAND) for e in range(d, days + 1))), None)
            density = f.s * 3  # device px per image px at 3x
            rows[(screen, name)] = dict(s=f.s, vis=vis, step=step_pt, gap=gap, gap_centre=gap_centre, k1=k1,
                                        fit_shadow=fit_shadow, fit_body=fit_body, fit_summit=fit_summit, peak=peak_day, clear=clear_day,
                                        density=density, need_w=w * density)
            out(" | ".join([
                name, f"{screen}", f"{f.s:.4f}", f"{vis:.0%}", f"{step_pt:.1f} pt", f"{gap:.1f} pt ({gap_centre:.1f} c-c)",
                "pass" if k1 else "FAIL", f"{fit_shadow:.0f} pt (body {fit_body:.0f}; summit {fit_summit:.0f})",
                f"day {peak_day}" if peak_day is not None else "never",
                f"day {clear_day}" if clear_day is not None else "never",
                f"{density:.2f} dev px/img px ({'sharp' if density <= 1 else 'upscaled'}; needs {w * density:.0f} px wide)",
            ]))
    out("")
    out("K1 (320 pt, 31 days: a day's step >= 17 pt and neighbouring markers >= 5 pt apart):")
    for name, _, _ in OPTIONS:
        r = rows[(320, name)]
        out(f"  {name}: step {r['step']:.1f} pt, gap {r['gap']:.1f} pt (pill kept) / {r['gap_centre']:.1f} pt centre to centre"
            f" -> {'PASS' if r['k1'] else 'FAIL'}")
    out("")
    out("avatar fit = the largest tile whose footprint (0.65 of the tile) fits the narrowest horizontal chord on days 0-30;")
    out("'body' = the widest avatar body (0.894) fits it instead; 'summit' = the footprint fits the summit tip (day 31).")
    out("Avatar size used in the renders: min(today's 42.3 pt, avatar fit).")
    (T.OUT / "framing_numbers.txt").write_text("\n".join(lines) + "\n")
    (T.OUT / "framing.json").write_text(json.dumps({f"{k[0]} {k[1]}": {a: (round(float(b), 4) if isinstance(b, (float, np.floating)) else b if b is None or isinstance(b, int) else bool(b)) for a, b in v.items()} for k, v in rows.items()}, indent=1) + "\n")
    print("\n".join(lines))

    # Renders: per screen, rows = options, columns = day 3, day 25, whole.
    fnt = font(26)
    sheets = {}
    for screen in SCREENS:
        cw = card_width(screen)
        tiles = []
        for name, kind, zoom in OPTIONS:
            f = Frame(kind, zoom, cw, (w, h))
            av = min(AVATAR_TODAY, rows[(screen, name)]["fit_shadow"])
            row = []
            for day in (3, 25):
                off = f.offset(steps[day])
                row.append(render(bg, f, {"off": off, "pt": f.to_pt(steps[day], off)}, av, sprite,
                                  label=f"{name} · {screen} pt · day {day}/31 · avatar {av:.0f} pt"))
            tiles.append(row)
        # The whole mountain at the month change: K-c, avatar on day 0.
        f = Frame("height", 1.0, cw, (w, h))
        off = f.offset(steps[0])
        whole = render(bg, f, {"off": off, "pt": f.to_pt(steps[0], off)}, min(AVATAR_TODAY, rows[(screen, 'K-c')]["fit_shadow"]),
                       sprite, steps_pt=[f.to_pt(p, off) for p in steps], label=f"whole mountain · {screen} pt · 31 steps")
        tw, th = tiles[0][0].size
        gap = 16
        sheet = Image.new("RGB", (3 * tw + 4 * gap, 4 * th + 5 * gap + 40), "white")
        ImageDraw.Draw(sheet).text((gap, 8), f"{screen} pt screen, card {cw:g} pt: day 3 | day 25 (rows K-a, K-b 1.3, K-b 1.6, K-c) | whole mountain (month change)",
                                   fill=(0, 0, 0), font=fnt)
        for i, row in enumerate(tiles):
            for j, im in enumerate(row):
                sheet.paste(im, (gap + j * (tw + gap), 40 + gap + i * (th + gap)))
        sheet.paste(whole, (gap + 2 * (tw + gap), 40 + gap))
        sheet.save(T.OUT / f"framing_{screen}.jpg", quality=84)
        sheets[screen] = (tiles, whole)

    # Overview (375 pt): one row per option (day 3, day 25) + the whole mountain.
    tiles, whole = sheets[375]
    tw, th = tiles[0][0].size
    small = lambda im: im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    tw2, th2 = tw // 2, th // 2
    gap = 10
    ov = Image.new("RGB", (5 * tw2 + 6 * gap, 2 * th2 + 3 * gap + 70), "white")
    dr = ImageDraw.Draw(ov)
    dr.text((gap, 6), "Framing at 375 pt (card 341 pt x 350 pt window), 31-day month. Top: day 3. Bottom: day 25.",
            fill=(0, 0, 0), font=font(18))
    dr.text((gap, 30), "Columns: K-a | K-b 1.3x | K-b 1.6x | K-c | whole mountain (month change, all 31 steps)",
            fill=(0, 0, 0), font=font(18))
    for i in range(4):
        for j in range(2):
            ov.paste(small(tiles[i][j]), (gap + i * (tw2 + gap), 60 + gap + j * (th2 + gap)))
    ov.paste(small(whole), (gap + 4 * (tw2 + gap), 60 + gap))
    ov.save(T.OUT / "framing_overview.jpg", quality=86)


if __name__ == "__main__":
    main()
