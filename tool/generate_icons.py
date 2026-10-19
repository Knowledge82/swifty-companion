#!/usr/bin/env python3
"""Рисует иконку приложения и картинку для splash screen в нашем стимпанк-стиле.

Запуск из корня проекта (нужны Pillow и numpy):

    pip install --break-system-packages pillow numpy
    python3 tool/generate_icons.py

Что создаётся в android/app/src/main/res:
  mipmap-*/ic_launcher.png              обычная иконка (Android до 8.0)
  mipmap-*/ic_launcher_foreground.png   передний слой адаптивной иконки (Android 8.0+)
  drawable-xxhdpi/splash_icon.png       статичная картинка splash (Android до 12)
  drawable/splash_icon_vector.xml       векторная эмблема splash (цепочка из 7 шестерёнок)
  drawable/splash_icon_animated.xml     её анимация: шестерёнки вращаются (Android 12+)

Иконка приложения: три сцепленные латунные шестерёнки, на большой ступица
со знаком школы 42. Рисунок не менялся с итерации 3, обновлены только цвета
под актуальную палитру (орех вместо изумруда, см. lib/ui/steampunk/steampunk_theme.dart).

Splash: цепочка из семи шестерёнок четырёх размеров, та же, что GearEmblem
в lib/ui/steampunk/gears.dart (раскладка берётся из tool/emblem_layout.py).

Знак 42 берётся из файла tool/42_logo.svg (его предоставил владелец
проекта) и рисуется как есть: многоугольники из файла, без переделок.
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emblem_layout  # noqa: E402  (раскладка цепочки шестерёнок)

RES = os.path.join('android', 'app', 'src', 'main', 'res')

BRASS_LIGHT = (0xE6, 0xC8, 0x78)
BRASS = (0xC8, 0xA0, 0x4A)
COPPER = (0xB8, 0x73, 0x33)
# Палитра как в steampunk_theme.dart (итерация 5б): орех вместо изумруда.
WALNUT = (0x2A, 0x1B, 0x12)
WALNUT_DEEP = (0x1B, 0x11, 0x0B)
LEATHER_DEEP = (0x17, 0x0E, 0x09)

LOGO_SVG = os.path.join('tool', '42_logo.svg')

# Длительность одного прохода анимации splash, секунд. Скорость вращения не зависит
# от неё (большая шестерёнка делает 83 градуса в секунду).
ANIM_SECONDS = 60


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
GEARS = [  # рисунок ИКОНКИ (не менялся)
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


def chain_gears():
    """Цепочка из семи шестерёнок для splash: (cx, cy, r, зубья, поворот)."""
    placed = emblem_layout.place(emblem_layout.CHILDREN)
    return placed, [(g['c'][0], g['c'][1], g['r'], g['z'], g['phase']) for g in placed]


def render(size, radius_frac, background=None, gears=None):
    """Рисует эмблему так, чтобы самая дальняя точка лежала на расстоянии
    radius_frac * size от центра холста (это нужно, чтобы эмблема не
    обрезалась круглой маской лаунчера или splash screen)."""
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
        if index != 0:  # у малых шестерёнок отверстие (evenOdd, как в приложении)
            hole = r_px * 0.32
            md.ellipse([cc[0] - hole, cc[1] - hole, cc[0] + hole, cc[1] + hole], fill=0)
        base.paste(grad, (0, 0), mask)

        d = ImageDraw.Draw(base)
        d.line(pts + [pts[0]], fill=LEATHER_DEEP + (255,), width=edge_w, joint='curve')

        if index == 0:
            # Ступица: тёмный диск с латунным ободком и цифрами 42.
            hub = r_px * 0.66
            d.ellipse([cc[0] - hub, cc[1] - hub, cc[0] + hub, cc[1] + hub],
                      fill=WALNUT_DEEP + (255,), outline=BRASS + (255,),
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


def fmt(v):
    """Число для XML: две цифры после запятой, без хвоста нулей."""
    return ('%.2f' % v).rstrip('0').rstrip('.')


def circle_path(cx, cy, r):
    """Контур круга в pathData: две дуги."""
    return (f'M{fmt(cx - r)},{fmt(cy)} a{fmt(r)},{fmt(r)} 0 1,0 {fmt(2 * r)},0 '
            f'a{fmt(r)},{fmt(r)} 0 1,0 {fmt(-2 * r)},0 Z')


def hex_color(rgb):
    return '#%02X%02X%02X' % rgb


def write_animated_splash(placed, chain):
    """Векторная эмблема splash и её анимация для Android 12+.

    Идея: каждая шестерёнка это <group> со своим pivot в центре; AnimatedVectorDrawable
    вращает группы. Угол поворота шестерёнки = передаточное число × угол большой,
    поэтому зацепление не нарушается в любой момент. Знак 42 лежит в отдельной
    группе без анимации.

    ПОЧЕМУ НЕТ ЗАЦИКЛИВАНИЯ. Раньше анимация длилась 1 с и повторялась: большая
    поворачивалась на три шага зубьев, остальные на три своих зуба, так что ЗУБЬЯ
    в конце цикла совпадали с началом. Но у малых шестерёнок есть болт со шлицем
    (отвёрточной прорезью), и он совпадает с исходным положением только при
    повороте на целое число оборотов (точнее, на 180 градусов). Три зуба это 216
    градусов у шестерёнки на 5 зубьев, 154 на 7, 120 на 9: на стыке повторов шлиц
    «соскакивал». Поэтому теперь ОДИН длинный проход (ANIM_SECONDS) без повтора:
    скорость вращения та же, а скачка нет, потому что сброса в начало нет вовсе
    (сплэш виден секунды, а не минуту).
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
           '<!-- СОЗДАНО tool/generate_icons.py, руками не править. Векторная эмблема splash:',
           '     цепочка из семи шестерёнок; анимация в splash_icon_animated.xml. -->',
           f'<vector {ns}',
           f'    android:width="{fmt(viewport)}dp" android:height="{fmt(viewport)}dp"',
           f'    android:viewportWidth="{fmt(viewport)}" android:viewportHeight="{fmt(viewport)}">']
    for index, (gear, poly) in enumerate(zip(chain, polys)):
        cx, cy, radius, teeth, _ = gear
        c = tr((cx, cy))
        r_px = radius * scale
        d = 'M' + ' L'.join(f'{fmt(x)},{fmt(y)}' for x, y in (tr(p) for p in poly)) + ' Z'
        if index != 0:
            d += ' ' + circle_path(c[0], c[1], r_px * 0.36)  # отверстие (evenOdd)
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
        if index != 0:  # болт в отверстии: медная шляпка и косой шлиц
            bolt = r_px * 0.27
            dx, dy = math.cos(0.6) * bolt * 0.65, math.sin(0.6) * bolt * 0.65
            out += [f'        <path android:pathData="{circle_path(c[0], c[1], bolt)}" '
                    f'android:fillColor="{hex_color(COPPER)}" android:strokeColor="{stroke}" '
                    'android:strokeWidth="0.8" />',
                    f'        <path android:pathData="M{fmt(c[0] - dx)},{fmt(c[1] - dy)} '
                    f'L{fmt(c[0] + dx)},{fmt(c[1] + dy)}" android:strokeColor="{stroke}" '
                    f'android:strokeWidth="{fmt(max(0.8, bolt * 0.18))}" android:strokeLineCap="round" />']
        out.append('    </group>')

    # Ступица со знаком 42: без анимации, поверх большой шестерёнки.
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

    # Анимация: один длинный проход, линейно, без повтора (см. docstring).
    step = 3 * 360.0 / chain[0][3]  # градусов в секунду у большой (три зуба за секунду)
    anim = ['<?xml version="1.0" encoding="utf-8"?>',
            '<!-- СОЗДАНО tool/generate_icons.py, руками не править. Анимированный значок splash',
            '     Android 12+: каждая шестерёнка вращается с передаточным числом цепочки. -->',
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
        # тонкая латунная рамка по краю
        ImageDraw.Draw(icon).rounded_rectangle(
            [0, 0, px - 1, px - 1], radius=int(px * 0.2),
            outline=BRASS + (255,), width=max(1, px // 48))
        save(rounded(icon), f'mipmap-{density}', 'ic_launcher.png')

    for density, px in adaptive.items():
        # безопасная зона адаптивной иконки: круг диаметром 66% холста
        save(render(px, 0.30), f'mipmap-{density}', 'ic_launcher_foreground.png')

    # splash: 288 dp * 3 = 864 px; видимый круг 192 dp = 576 px (радиус 1/3 холста).
    # Статичная картинка для Android до 12: цепочка из семи шестерёнок.
    placed, chain = chain_gears()
    save(render(864, 0.30, gears=chain), 'drawable-xxhdpi', 'splash_icon.png')
    write_animated_splash(placed, chain)


if __name__ == '__main__':
    main()
