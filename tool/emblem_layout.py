#!/usr/bin/env python3
"""Check and search for the layout of the emblem gears (`placeEmblemGears` in gears.dart).

Run:
    python3 tool/emblem_layout.py            # check the current layout and draw tool/emblem_preview.png
    python3 tool/emblem_layout.py search N   # try N random layouts and print the best ones

Needs Pillow and numpy (pip install pillow numpy).

What is checked (the same as the Flutter tests do, plus a raster check):
  - all gears are inside the 1x1 square with a 0.02 margin;
  - unmeshed pairs do not touch (a gap of at least 0.02);
  - for every meshed pair the teeth do not intersect at any moment of the
    rotation (the outlines are drawn into a raster, shared pixels are counted).
The formulas are the same as in gears.dart: the distance between axes, the phase from the condition
"parent tooth fraction + child tooth fraction = 0.5", speed = -parent speed * parent teeth / teeth.
"""
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

BIG = (0.347, 0.585, 0.26, 13)  # center x, y, radius, teeth (as in gears.dart)
# (parent index, angle from the parent in degrees, radius, teeth): as in gears.dart
CHILDREN = [
    (0, -15.6, 0.19, 9),
    (1, 88.9, 0.14, 7),
    (1, -78.9, 0.14, 7),
    (3, 179.8, 0.14, 7),
    (4, -170.6, 0.10, 5),
    (0, 123.6, 0.10, 5),
]
OMEGA = 2 * math.pi / 36  # the big one makes a revolution in 36 seconds


def mesh_distance(R, r):
    """Distance between axes: the tooth tip almost touches the gap (the gap is at 0.8 of the radius)."""
    return max(R + 0.8 * r, r + 0.8 * R) + 0.01


def place(children, big=BIG):
    gears = [dict(c=(big[0], big[1]), r=big[2], z=big[3], parent=-1, phase=0.0, ratio=1.0)]
    for parent, deg, r, z in children:
        P = gears[parent]
        a = math.radians(deg)
        d = mesh_distance(P['r'], r)
        c = (P['c'][0] + math.cos(a) * d, P['c'][1] + math.sin(a) * d)
        frac = (a - P['phase']) * P['z'] / (2 * math.pi)
        phase = a + math.pi - (0.5 - frac) * 2 * math.pi / z
        gears.append(dict(c=c, r=r, z=z, parent=parent, phase=phase,
                          ratio=-P['ratio'] * P['z'] / z))
    return gears


def polygon(g, t, scale):
    theta = g['phase'] + g['ratio'] * OMEGA * t
    cx, cy, r, step = g['c'][0] * scale, g['c'][1] * scale, g['r'] * scale, 2 * math.pi / g['z']
    pts = []
    for i in range(g['z']):
        a = theta + i * step
        for da, k in ((-0.30, 0.8), (-0.17, 1), (0.17, 1), (0.30, 0.8)):
            pts.append((cx + math.cos(a + da * step) * r * k, cy + math.sin(a + da * step) * r * k))
    return pts


def mask(g, t, scale):
    m = Image.new('L', (scale, scale), 0)
    ImageDraw.Draw(m).polygon(polygon(g, t, scale), fill=255)
    return np.asarray(m) > 0


def check(gears, verbose=True):
    ok = True
    for i, g in enumerate(gears):
        x0, x1 = g['c'][0] - g['r'], g['c'][0] + g['r']
        y0, y1 = g['c'][1] - g['r'], g['c'][1] + g['r']
        if min(x0, y0) < 0.02 or max(x1, y1) > 0.98:
            ok = False
            print(f'gear {i} sticks out of the field:', x0, x1, y0, y1)
    gap = 1.0
    for i in range(len(gears)):
        for j in range(i + 1, len(gears)):
            if gears[j]['parent'] == i:
                continue
            gap = min(gap, math.dist(gears[i]['c'], gears[j]['c']) - gears[i]['r'] - gears[j]['r'])
    if gap < 0.02:
        ok = False
    worst = 0
    for t in (0, 1.7, 9.3, 20, 50.5, 123.4):
        masks = [mask(g, t, 900) for g in gears]
        for i, g in enumerate(gears[1:], 1):
            worst = max(worst, int((masks[i] & masks[g['parent']]).sum()))
    if worst:
        ok = False
    if verbose:
        print(f'minimum gap between unmeshed gears: {gap:.3f}')
        print(f'largest overlap of meshed pairs (pixels): {worst}')
        print('RESULT:', 'all good' if ok else 'THERE ARE PROBLEMS')
    return ok


def preview(gears, path):
    s = 480
    im = Image.new('RGB', (s, s), (23, 14, 9))
    d = ImageDraw.Draw(im)
    for g in gears:
        d.polygon(polygon(g, 0, s), fill=(200, 160, 74), outline=(23, 14, 9))
        cx, cy, r = g['c'][0] * s, g['c'][1] * s, g['r'] * s
        hole = 0 if g['parent'] < 0 else 0.36 * r
        if hole:
            d.ellipse([cx - hole, cy - hole, cx + hole, cy + hole], fill=(23, 14, 9))
    im.save(path)


def search(trials, sizes=((0.19, 9), (0.14, 7), (0.10, 5))):
    """Random search: we add gears to random parents at a random angle."""
    best = []
    for seed in range(trials):
        rnd = random.Random(seed)
        big = (rnd.uniform(0.33, 0.47), rnd.uniform(0.40, 0.60), BIG[2], BIG[3])
        children, gears = [], place([], big)
        for _ in range(400):
            if len(gears) >= 7:
                break
            p = rnd.randrange(len(gears))
            r, z = rnd.choice(sizes)
            a = rnd.uniform(-180, 180)
            trial = place(children + [(p, round(a, 1), r, z)], big)
            new = trial[-1]
            if new['c'][0] - r < 0.02 or new['c'][0] + r > 0.98 or new['c'][1] - r < 0.02 or new['c'][1] + r > 0.98:
                continue
            if any(math.dist(g['c'], new['c']) < g['r'] + r + 0.025 for k, g in enumerate(gears) if k != p):
                continue
            children.append((p, round(a, 1), r, z))
            gears = trial
        if len(gears) == 7 and len({g['r'] for g in gears}) == 4:
            best.append((sum(g['r'] ** 2 for g in gears), seed, children, big))
    best.sort(key=lambda t: -t[0])
    for area, seed, children, big in best[:5]:
        print(f'seed={seed} area={area:.3f} big=({big[0]:.3f}, {big[1]:.3f})')
        for c in children:
            print('   ', c)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'search':
        search(int(sys.argv[2]) if len(sys.argv) > 2 else 20000)
    else:
        gears = place(CHILDREN)
        ok = check(gears)
        preview(gears, 'tool/emblem_preview.png')
        print('image: tool/emblem_preview.png')
        sys.exit(0 if ok else 1)
