#!/usr/bin/env python3
"""Рисует иконку приложения и картинку для splash screen в нашем стимпанк-стиле.

Запуск из корня проекта (нужны Pillow и numpy):

    pip install --break-system-packages pillow numpy
    python3 tool/generate_icons.py

Что создаётся в android/app/src/main/res:
  mipmap-*/ic_launcher.png              обычная иконка (Android до 8.0)
  mipmap-*/ic_launcher_foreground.png   передний слой адаптивной иконки (Android 8.0+)
  drawable-xxhdpi/splash_icon.png       картинка для splash screen

Эмблема повторяет GearEmblem из lib/ui/steampunk/gears.dart: три сцепленные
латунные шестерёнки, на большой шестерёнке изумрудная ступица со знаком
школы 42. Знак берётся из файла tool/42_logo.svg (его предоставил владелец
проекта) и рисуется как есть: многоугольники из файла, без переделок.
"""
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RES = os.path.join('android', 'app', 'src', 'main', 'res')

BRASS_LIGHT = (0xE6, 0xC8, 0x78)
BRASS = (0xC8, 0xA0, 0x4A)
COPPER = (0xB8, 0x73, 0x33)
EMERALD = (0x0F, 0x2B, 0x21)
EMERALD_DEEP = (0x0A, 0x1F, 0x17)
LEATHER_DEEP = (0x1A, 0x11, 0x0B)

LOGO_SVG = os.path.join('tool', '42_logo.svg')


def load_logo():
    """Многоугольники знака из SVG (атрибуты points) и их габариты."""
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


# (центр x, центр y, радиус, число зубьев, поворот) в условных единицах 0..1:
# те же числа, что в GearEmblem.
GEARS = [
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
    """Диагональный градиент светлая латунь -> латунь -> медь."""
    y, x = np.mgrid[0:size, 0:size]
    t = (x + y) / (2.0 * (size - 1))
    stops = [(0.0, BRASS_LIGHT), (0.5, BRASS), (1.0, COPPER)]
    out = np.zeros((size, size, 3), dtype=np.float32)
    for channel in range(3):
        out[:, :, channel] = np.interp(
            t, [s[0] for s in stops], [s[1][channel] for s in stops])
    return Image.fromarray(out.astype(np.uint8), 'RGB')


def draw_logo(draw, center, width):
    """Рисует знак 42 светлой латунью: центр габаритов в center, ширина width."""
    polys, (x0, y0, x1, y1) = load_logo()
    scale = width / (x1 - x0)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    for poly in polys:
        draw.polygon([(center[0] + (x - mx) * scale, center[1] + (y - my) * scale)
                      for x, y in poly], fill=BRASS_LIGHT + (255,))


def render(size, radius_frac, background=None):
    """Рисует эмблему так, чтобы самая дальняя точка лежала на расстоянии
    radius_frac * size от центра холста (это нужно, чтобы эмблема не
    обрезалась круглой маской лаунчера или splash screen)."""
    ss = 4 if size <= 512 else 3
    big = size * ss

    polys = [gear_points(*g) for g in GEARS]
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

    for index, (gear, poly) in enumerate(zip(GEARS, polys)):
        cx, cy, radius, teeth, _ = gear
        pts = [tr(p) for p in poly]
        cc = tr((cx, cy))
        r_px = radius * scale

        mask = Image.new('L', (big, big), 0)
        md = ImageDraw.Draw(mask)
        md.polygon(pts, fill=255)
        if index != 0:  # у малых шестерёнок отверстие (evenOdd, как в приложении)
            hole = r_px * 0.32
            md.ellipse([cc[0] - hole, cc[1] - hole, cc[0] + hole, cc[1] + hole], fill=0)
        base.paste(grad, (0, 0), mask)

        d = ImageDraw.Draw(base)
        d.line(pts + [pts[0]], fill=LEATHER_DEEP + (255,), width=edge_w, joint='curve')

        if index == 0:
            # Ступица: изумрудный диск с латунным ободком и цифрами 42.
            hub = r_px * 0.66
            d.ellipse([cc[0] - hub, cc[1] - hub, cc[0] + hub, cc[1] + hub],
                      fill=EMERALD_DEEP + (255,), outline=BRASS + (255,),
                      width=max(2, int(r_px * 0.06)))
            draw_logo(d, cc, hub * 1.42)
        else:
            # Болт в отверстии: шляпка меди и косой шлиц.
            bolt = r_px * 0.22
            d.ellipse([cc[0] - bolt, cc[1] - bolt, cc[0] + bolt, cc[1] + bolt],
                      fill=COPPER + (255,), outline=LEATHER_DEEP + (255,),
                      width=max(1, int(r_px * 0.02)))
            dx, dy = math.cos(0.6) * bolt * 0.65, math.sin(0.6) * bolt * 0.65
            d.line([cc[0] - dx, cc[1] - dy, cc[0] + dx, cc[1] + dy],
                   fill=LEATHER_DEEP + (255,), width=max(1, int(bolt * 0.18)))

    return base.resize((size, size), Image.LANCZOS)


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
        icon = render(px, 0.40, background=EMERALD)
        # тонкая латунная рамка по краю
        ImageDraw.Draw(icon).rounded_rectangle(
            [0, 0, px - 1, px - 1], radius=int(px * 0.2),
            outline=BRASS + (255,), width=max(1, px // 48))
        save(rounded(icon), f'mipmap-{density}', 'ic_launcher.png')

    for density, px in adaptive.items():
        # безопасная зона адаптивной иконки: круг диаметром 66% холста
        save(render(px, 0.30), f'mipmap-{density}', 'ic_launcher_foreground.png')

    # splash: 288 dp * 3 = 864 px; видимый круг 192 dp = 576 px (радиус 1/3 холста)
    save(render(864, 0.30), 'drawable-xxhdpi', 'splash_icon.png')


if __name__ == '__main__':
    main()
