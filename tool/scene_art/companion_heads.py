"""Fix round 4, item 5: each companion image's head box (SPEC §3.5 v12).

On the device the giraffe's sweat drop fell from far above and to the right
of its head: the props were placed by the image box's corner, the same for
every hero. This measures, for every hero × pose image (the base avatar,
which idle and oops draw, and the six poses), the box of the head from the
image's own pixels and writes `lib/widgets/companion_head_table.dart` for
`CompanionView` to place each prop by the head.

How (ImageMagick only, already used by the capture tools; no Python
packages): the alpha channel is read at 160 × 160 and thresholded at 50 %.
The silhouette's bounding box gives the top of the head (ears and horns
included: a prop above the head clears them). The head's lower edge is the
neck: the first row, between 20 % and 65 % of the silhouette's height, where
the outline is clearly narrower than above it (at most 85 % of the widest
row so far) and widens again below; without one (a chibi body with no neck)
it is half the silhouette. The head's sides are the medians of each row's
leftmost and rightmost pixels over the head's lower two thirds, so ears,
horns and a raised paw do not widen it. A few images need a hand
correction (a sleeping pose's head lies at one side); they are listed in
OVERRIDES with the reason, still in the image's own fractions.

Run from the repository root:

    python3 tool/scene_art/companion_heads.py

It prints each box and rewrites the Dart table (deterministic). Check the
result on the contact sheet
(`FIX4_CAPTURE=1 flutter test test/fix4_props_test.dart`).
"""

import subprocess

HEROES = [
    # (pose name, base avatar index), in picker order.
    ('fox', 14), ('panda', 15), ('koala', 1), ('frog', 5), ('bird', 13),
    ('giraffe', 11), ('cat', 8), ('sloth', 16), ('crab', 7),
]
POSES = ['wave', 'cheer', 'think', 'inspect', 'sad', 'sleep']
N = 160
OUT = 'lib/widgets/companion_head_table.dart'

# Hand corrections, (x0, y0, x1, y1) in fractions of the image, read off a
# 30/50/70 % grid over each image (the contact sheet's check), with why.
_LYING = 'lying down: the head is at one side, the outline is the whole body'
_CRAB = 'a crab: the face is on the body, the raised claws widen the top'
OVERRIDES = {
    'assets/companions/fox_wave.webp': (
        (0.23, 0.07, 0.78, 0.53), 'the raised paw reads as a neck'),
    'assets/companions/fox_sleep.webp': ((0.12, 0.24, 0.66, 0.64), _LYING),
    'assets/companions/panda_sleep.webp': ((0.12, 0.49, 0.56, 0.82), _LYING),
    'assets/companions/koala_sleep.webp': ((0.12, 0.48, 0.75, 0.82), _LYING),
    'assets/companions/bird_sleep.webp': ((0.12, 0.42, 0.62, 0.85), _LYING),
    'assets/companions/cat_sleep.webp': ((0.12, 0.27, 0.58, 0.66), _LYING),
    'assets/companions/sloth_sleep.webp': ((0.12, 0.48, 0.55, 0.82), _LYING),
    'assets/avatars/avatar_07.webp': ((0.18, 0.33, 0.82, 0.70), _CRAB),
    'assets/companions/crab_wave.webp': ((0.22, 0.36, 0.78, 0.75), _CRAB),
    'assets/companions/crab_cheer.webp': ((0.22, 0.37, 0.78, 0.72), _CRAB),
    'assets/companions/crab_think.webp': ((0.15, 0.24, 0.72, 0.72), _CRAB),
    'assets/companions/crab_inspect.webp': ((0.22, 0.35, 0.70, 0.72), _CRAB),
}


def alpha(path):
    data = subprocess.check_output([
        'magick', path, '-alpha', 'extract', '-resize', f'{N}x{N}!',
        '-depth', '8', 'gray:-'])
    return [[data[y * N + x] >= 128 for x in range(N)] for y in range(N)]


def median(values):
    s = sorted(values)
    return s[len(s) // 2]


def head_box(path):
    m = alpha(path)
    rows = [(y, [x for x in range(N) if m[y][x]]) for y in range(N)]
    rows = [(y, xs) for y, xs in rows if xs]
    y0, y1 = rows[0][0], rows[-1][0]
    height = y1 - y0 + 1
    extent = {y: (xs[0], xs[-1]) for y, xs in rows}
    width = {y: extent[y][1] - extent[y][0] + 1 for y in extent}
    # The neck: the narrowest row between 30 % and 70 % of the height, when
    # it is clearly narrower than the head above it (from 12 %, under the
    # ears and horns) and the body below widens again.
    lo, hi = y0 + int(0.3 * height), y0 + int(0.7 * height)
    candidates = [y for y in range(lo, hi + 1) if y in width]
    neck = None
    if candidates:
        y_min = min(candidates, key=lambda y: (width[y], y))
        above = [width[y] for y in range(y0 + int(0.12 * height), y_min)
                 if y in width]
        below = [width[y] for y in range(y_min + 1, y1 + 1) if y in width]
        if (above and below and width[y_min] <= max(above) * 0.9
                and max(below) >= width[y_min] * 1.05):
            neck = y_min
    bottom = neck if neck is not None else y0 + height // 2
    band = [y for y in range(y0 + (bottom - y0) // 3, bottom + 1) if y in extent]
    left = median([extent[y][0] for y in band])
    right = median([extent[y][1] for y in band])
    return (left / N, y0 / N, (right + 1) / N, (bottom + 1) / N), neck is not None


def main():
    lines = []
    for name, index in HEROES:
        images = [f'assets/avatars/avatar_{index:02d}.webp'] + [
            f'assets/companions/{name}_{pose}.webp' for pose in POSES]
        for path in images:
            box, neck = head_box(path)
            if path in OVERRIDES:
                box, why = OVERRIDES[path]
                print(f'{path}: override {box} ({why})')
            else:
                print(f'{path}: {tuple(round(v, 3) for v in box)}'
                      f'{"" if neck else " (no neck: half)"}')
            lines.append(
                f"  '{path}': ({box[0]:.3f}, {box[1]:.3f}, "
                f"{box[2]:.3f}, {box[3]:.3f}),")
    with open(OUT, 'w') as f:
        f.write('// GENERATED by tool/scene_art/companion_heads.py; do not edit.\n')
        f.write('// Each companion image\'s head box (left, top, right, bottom) in\n')
        f.write('// fractions of the image (SPEC §3.5 v12, fix round 4 item 5).\n\n')
        f.write('const Map<String, (double, double, double, double)> '
                'companionHeadBox = {\n')
        f.write('\n'.join(lines) + '\n};\n')
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main()
