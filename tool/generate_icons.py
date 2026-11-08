#!/usr/bin/env python3
"""Draws the app icon and the splash screen image in our steampunk style.

Run from the project root (needs Pillow and numpy):

    pip install --break-system-packages pillow numpy
    python3 tool/generate_icons.py

What is created in android/app/src/main/res:
  mipmap-*/ic_launcher.png              the plain icon (Android before 8.0)
  mipmap-*/ic_launcher_foreground.png   the foreground layer of the adaptive icon (Android 8.0+)
  drawable-xxhdpi/splash_icon.png       the static splash image (Android before 12)
  drawable/splash_icon_vector.xml       the vector splash emblem (a chain of 7 gears)
  drawable/splash_icon_animated.xml     its animation: the gears rotate (Android 12+)

The app icon: three meshed brass gears, with a hub carrying the school's 42
mark on the big one. The drawing has not changed since iteration 3, only the
colors were updated to the current palette (walnut instead of emerald, see
lib/ui/steampunk/steampunk_theme.dart).

Splash: a chain of seven gears of four sizes, the same as GearEmblem in
lib/ui/steampunk/gears.dart (the layout is taken from tool/emblem_layout.py).

The 42 mark is taken from the file tool/42_logo.svg (provided by the project
owner) and drawn as it is: the polygons from the file, without changes.
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emblem_layout  # noqa: E402  (gear chain layout)

RES = os.path.join('android', 'app', 'src', 'main', 'res')

BRASS_LIGHT = (0xE6, 0xC8, 0x78)
BRASS = (0xC8, 0xA0, 0x4A)
COPPER = (0xB8, 0x73, 0x33)
# The palette as in steampunk_theme.dart (iteration 5b): walnut instead of emerald.
WALNUT = (0x2A, 0x1B, 0x12)
WALNUT_DEEP = (0x1B, 0x11, 0x0B)
LEATHER_DEEP = (0x17, 0x0E, 0x09)

LOGO_SVG = os.path.join('tool', '42_logo.svg')

# Duration of one pass of the splash animation, in seconds. The rotation speed
# does not depend on it (the big gear makes 83 degrees per second).
ANIM_SECONDS = 60


def load_logo():
    """The polygons of the mark from the SVG (the points attributes) and their bounds."""
    with open(LOGO_SVG, encoding='utf-8') as f:
        svg = f.read()
    polys = []
    for match in re.finditer(r'points="([^"]*)"', svg):
        nums = [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', match.group(1))]
        polys.append(list(zip(nums[0::2], nums[1::2])))
    xs = [p[0] for poly in polys for p in poly]
    ys = [p[1] for poly in polys for p in poly]
    bounds = (min(xs), min(ys), max(xs), max(ys))
    return polys, bounds


# (center x, center y, radius, tooth count, rotation) in relative units 0..1:
# the same numbers as in GearEmblem.
GEARS = [  # the ICON drawing (unchanged)
    (0.42, 0.52, 0.34, 14, 0.0),
    (0.80, 0.28, 0.17, 8, math.pi / 8),
    (0.76, 0.80, 0.14, 7, math.pi / 7),
]


def gear_points(cx, cy, radius, teeth, rotation):
    step = 2 * math.pi / teeth
    root = radius * 0.80
    pts = []
    for i in range(teeth):
        a = rotation + i * step
        for angle, r in ((a - step * 0.30, root), (a - step * 0.17, radius),
                         (a + step * 0.17, radius), (a + step * 0.30, root)):
            pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    return pts


def gradient(size):
    """A diagonal gradient light brass -> brass -> copper."""
    y, x = np.mgrid[0:size, 0:size]
    t = (x + y) / (2.0 * (size - 1))
    stops = [(0.0, BRASS_LIGHT), (0.5, BRASS), (1.0, COPPER)]
    out = np.zeros((size, size, 3), dtype=np.float32)
    for channel in range(3):
        out[:, :, channel] = np.interp(
            t, [s[0] for s in stops], [s[1][channel] for s in stops])
    return Image.fromarray(out.astype(np.uint8), 'RGB')


def draw_logo(draw, center, width):
    """Draws the 42 mark in light brass: the center of its bounds at center, the width equal to width."""
    polys, (x0, y0, x1, y1) = load_logo()
    scale = width / (x1 - x0)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    for poly in polys:
        draw.polygon([(center[0] + (x - mx) * scale, center[1] + (y - my) * scale)
                      for x, y in poly], fill=BRASS_LIGHT + (255,))


def chain_gears():
    """A chain of seven gears for the splash: (cx, cy, r, teeth, rotation)."""
    placed = emblem_layout.place(emblem_layout.CHILDREN)
    return placed, [(g['c'][0], g['c'][1], g['r'], g['z'], g['phase']) for g in placed]


def render(size, radius_frac, background=None, gears=None):
    """Draws the emblem so that the farthest point lies at a distance of
    radius_frac * size from the center of the canvas (this is needed so the
    emblem is not cut off by the launcher's round mask or the splash screen)."""
    ss = 4 if size <= 512 else 3
    big = size * ss

    gears = gears or GEARS
    polys = [gear_points(*g) for g in gears]
    all_pts = [p for poly in polys for p in poly]
    xs, ys = [p[0] for p in all_pts], [p[1] for p in all_pts]
    cx0, cy0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    far = max(math.hypot(x - cx0, y - cy0) for x, y in all_pts)
    scale = radius_frac * big / far

    def tr(p):
        return (big / 2 + (p[0] - cx0) * scale, big / 2 + (p[1] - cy0) * scale)

    base = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    if background is not None:
        base.paste(Image.new('RGBA', (big, big), background + (255,)))
    grad = gradient(big)
    edge_w = max(2, int(big * 0.006))

    for index, (gear, poly) in enumerate(zip(gears, polys)):
        cx, cy, radius, teeth, _ = gear
        pts = [tr(p) for p in poly]
        cc = tr((cx, cy))
        r_px = radius * scale

        mask = Image.new('L', (big, big), 0)
        md = ImageDraw.Draw(mask)
        md.polygon(pts, fill=255)
        if index != 0:  # the small gears have a hole (evenOdd, as in the app)
            hole = r_px * 0.32
            md.ellipse([cc[0] - hole, cc[1] - hole, cc[0] + hole, cc[1] + hole], fill=0)
        base.paste(grad, (0, 0), mask)

        d = ImageDraw.Draw(base)
        d.line(pts + [pts[0]], fill=LEATHER_DEEP + (255,), width=edge_w, joint='curve')

        if index == 0:
            # The hub: a dark disc with a brass rim and the digits 42.
            hub = r_px * 0.66
            d.ellipse([cc[0] - hub, cc[1] - hub, cc[0] + hub, cc[1] + hub],
                      fill=WALNUT_DEEP + (255,), outline=BRASS + (255,),
                      width=max(2, int(r_px * 0.06)))
            draw_logo(d, cc, hub * 1.42)
        else:
            # A bolt in the hole: a copper head and a slanted slot.
            bolt = r_px * 0.22
            d.ellipse([cc[0] - bolt, cc[1] - bolt, cc[0] + bolt, cc[1] + bolt],
                      fill=COPPER + (255,), outline=LEATHER_DEEP + (255,),
                      width=max(1, int(r_px * 0.02)))
            dx, dy = math.cos(0.6) * bolt * 0.65, math.sin(0.6) * bolt * 0.65
            d.line([cc[0] - dx, cc[1] - dy, cc[0] + dx, cc[1] + dy],
                   fill=LEATHER_DEEP + (255,), width=max(1, int(bolt * 0.18)))

    return base.resize((size, size), Image.LANCZOS)


def fmt(v):
    """A number for XML: two digits after the decimal point, without trailing zeros."""
    return ('%.2f' % v).rstrip('0').rstrip('.')


def circle_path(cx, cy, r):
    """The outline of a circle in pathData: two arcs."""
    return (f'M{fmt(cx - r)},{fmt(cy)} a{fmt(r)},{fmt(r)} 0 1,0 {fmt(2 * r)},0 '
            f'a{fmt(r)},{fmt(r)} 0 1,0 {fmt(-2 * r)},0 Z')


def hex_color(rgb):
    return '#%02X%02X%02X' % rgb


def write_animated_splash(placed, chain):
    """The vector splash emblem and its animation for Android 12+.

    The idea: each gear is a <group> with its own pivot at the center;
    AnimatedVectorDrawable rotates the groups. The rotation angle of a gear =
    gear ratio × the angle of the big one, so the meshing is never broken at
    any moment. The 42 mark lies in a separate group without animation.

    WHY THERE IS NO LOOPING. The animation used to last 1 s and repeat: the big
    gear turned by three tooth steps, the others by three of their own teeth,
    so the TEETH at the end of the cycle matched the start. But the small gears
    have a bolt with a slot (a screwdriver cut), and it matches the initial
    position only when turned by a whole number of revolutions (more exactly,
    by 180 degrees). Three teeth are 216 degrees for a gear with 5 teeth, 154
    for 7, 120 for 9: at the seam of the repeats the slot "jumped". So now
    there is ONE long pass (ANIM_SECONDS) without repeating: the rotation
    speed is the same, and there is no jump, because there is no reset to the
    start at all (the splash is visible for seconds, not for a minute).
    """
    viewport = 288.0
    radius_frac = 0.30
    polys = [gear_points(*g) for g in chain]
    pts = [p for poly in polys for p in poly]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    cx0, cy0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    far = max(math.hypot(x - cx0, y - cy0) for x, y in pts)
    scale = radius_frac * viewport / far

    def tr(p):
        return (viewport / 2 + (p[0] - cx0) * scale, viewport / 2 + (p[1] - cy0) * scale)

    ns = ('xmlns:android="http://schemas.android.com/apk/res/android" '
          'xmlns:aapt="http://schemas.android.com/aapt"')
    stroke = hex_color(LEATHER_DEEP)
    out = ['<?xml version="1.0" encoding="utf-8"?>',
           '<!-- GENERATED by tool/generate_icons.py, do not edit by hand. Vector splash emblem:',
           '     a chain of seven gears; the animation is in splash_icon_animated.xml. -->',
           f'<vector {ns}',
           f'    android:width="{fmt(viewport)}dp" android:height="{fmt(viewport)}dp"',
           f'    android:viewportWidth="{fmt(viewport)}" android:viewportHeight="{fmt(viewport)}">']
    for index, (gear, poly) in enumerate(zip(chain, polys)):
        cx, cy, radius, teeth, _ = gear
        c = tr((cx, cy))
        r_px = radius * scale
        d = 'M' + ' L'.join(f'{fmt(x)},{fmt(y)}' for x, y in (tr(p) for p in poly)) + ' Z'
        if index != 0:
            d += ' ' + circle_path(c[0], c[1], r_px * 0.36)  # hole (evenOdd)
        out += [f'    <group android:name="gear{index}" android:pivotX="{fmt(c[0])}" '
                f'android:pivotY="{fmt(c[1])}">',
                f'        <path android:pathData="{d}" android:fillType="evenOdd">',
                '            <aapt:attr name="android:fillColor">',
                f'                <gradient android:type="radial" android:centerX="{fmt(c[0])}" '
                f'android:centerY="{fmt(c[1])}" android:gradientRadius="{fmt(r_px)}">',
                f'                    <item android:offset="0" android:color="{hex_color(BRASS_LIGHT)}" />',
                f'                    <item android:offset="0.6" android:color="{hex_color(BRASS)}" />',
                f'                    <item android:offset="1" android:color="{hex_color(COPPER)}" />',
                '                </gradient>',
                '            </aapt:attr>',
                '        </path>',
                f'        <path android:pathData="{d}" android:fillType="evenOdd" '
                f'android:fillColor="#00000000" android:strokeColor="{stroke}" '
                f'android:strokeWidth="{fmt(max(1.0, r_px * 0.03))}" />']
        if index != 0:  # a bolt in the hole: a copper head and a slanted slot
            bolt = r_px * 0.27
            dx, dy = math.cos(0.6) * bolt * 0.65, math.sin(0.6) * bolt * 0.65
            out += [f'        <path android:pathData="{circle_path(c[0], c[1], bolt)}" '
                    f'android:fillColor="{hex_color(COPPER)}" android:strokeColor="{stroke}" '
                    'android:strokeWidth="0.8" />',
                    f'        <path android:pathData="M{fmt(c[0] - dx)},{fmt(c[1] - dy)} '
                    f'L{fmt(c[0] + dx)},{fmt(c[1] + dy)}" android:strokeColor="{stroke}" '
                    f'android:strokeWidth="{fmt(max(0.8, bolt * 0.18))}" android:strokeLineCap="round" />']
        out.append('    </group>')

    # The hub with the 42 mark: no animation, on top of the big gear.
    big = tr((chain[0][0], chain[0][1]))
    hub = chain[0][2] * scale * 0.66
    out += ['    <group android:name="hub">',
            f'        <path android:pathData="{circle_path(big[0], big[1], hub)}" '
            f'android:fillColor="{hex_color(WALNUT_DEEP)}" android:strokeColor="{hex_color(BRASS)}" '
            f'android:strokeWidth="{fmt(max(1.2, hub * 0.09))}" />']
    polys42, (x0, y0, x1, y1) = load_logo()
    k = hub * 1.42 / (x1 - x0)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    for poly in polys42:
        d = 'M' + ' L'.join(f'{fmt(big[0] + (x - mx) * k)},{fmt(big[1] + (y - my) * k)}'
                            for x, y in poly) + ' Z'
        out.append(f'        <path android:pathData="{d}" android:fillColor="{hex_color(BRASS_LIGHT)}" />')
    out += ['    </group>', '</vector>', '']
    path = os.path.join(RES, 'drawable', 'splash_icon_vector.xml')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))
    print('записано', path)

    # The animation: one long pass, linear, without repeating (see the docstring).
    step = 3 * 360.0 / chain[0][3]  # degrees per second for the big one (three teeth per second)
    anim = ['<?xml version="1.0" encoding="utf-8"?>',
            '<!-- GENERATED by tool/generate_icons.py, do not edit by hand. Animated splash icon',
            '     for Android 12+: every gear rotates with the gear ratio of the chain. -->',
            f'<animated-vector {ns}',
            '    android:drawable="@drawable/splash_icon_vector">']
    for index, g in enumerate(placed):
        angle = g['ratio'] * step * ANIM_SECONDS
        anim += [f'    <target android:name="gear{index}">',
                 '        <aapt:attr name="android:animation">',
                 '            <objectAnimator android:propertyName="rotation" '
                 f'android:valueFrom="0" android:valueTo="{fmt(angle)}" '
                 f'android:duration="{ANIM_SECONDS * 1000}" android:interpolator="@android:interpolator/linear" />',
                 '        </aapt:attr>',
                 '    </target>']
    anim += ['</animated-vector>', '']
    path = os.path.join(RES, 'drawable', 'splash_icon_animated.xml')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(anim))
    print('записано', path)


def rounded(img, radius_frac=0.2):
    mask = Image.new('L', img.size, 0)
    s = img.size[0]
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1],
                                           radius=int(s * radius_frac), fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def save(img, *parts):
    path = os.path.join(RES, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print('записано', path, img.size)


def main():
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}

    for density, px in legacy.items():
        icon = render(px, 0.40, background=WALNUT)
        # a thin brass border along the edge
        ImageDraw.Draw(icon).rounded_rectangle(
            [0, 0, px - 1, px - 1], radius=int(px * 0.2),
            outline=BRASS + (255,), width=max(1, px // 48))
        save(rounded(icon), f'mipmap-{density}', 'ic_launcher.png')

    for density, px in adaptive.items():
        # the safe zone of the adaptive icon: a circle with a diameter of 66% of the canvas
        save(render(px, 0.30), f'mipmap-{density}', 'ic_launcher_foreground.png')

    # splash: 288 dp * 3 = 864 px; the visible circle is 192 dp = 576 px (radius 1/3 of the canvas).
    # The static image for Android before 12: a chain of seven gears.
    placed, chain = chain_gears()
    save(render(864, 0.30, gears=chain), 'drawable-xxhdpi', 'splash_icon.png')
    write_animated_splash(placed, chain)


if __name__ == '__main__':
    main()
