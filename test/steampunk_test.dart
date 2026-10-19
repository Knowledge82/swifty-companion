import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/splash_screen.dart' show splashBackgroundColor;
import 'package:swifty_companion/ui/steampunk/gear_motion.dart';
import 'package:swifty_companion/ui/steampunk/gears.dart';
import 'package:swifty_companion/ui/steampunk/pipes.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_widgets.dart';

import 'test_app.dart';

/// Коэффициент контрастности WCAG: (светлый + 0.05) / (тёмный + 0.05).
double contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('палитра', () {
    // Фон панелей (орех) и экрана/AppBar (тёмная кожа). Текст и значки на них.
    final pairs = <(String, Color, Color, double)>[
      ('основной текст на панели', steampunkColors.onSurface, steampunkColors.surface, 7),
      ('основной текст на фоне', steampunkColors.onSurface, leatherDeep, 7),
      ('подписи на панели', steampunkColors.onSurfaceVariant, steampunkColors.surface, 4.5),
      ('латунь на панели', steampunkColors.primary, steampunkColors.surface, 4.5),
      ('латунь на фоне (AppBar)', steampunkColors.primary, leatherDeep, 4.5),
      ('«сдан» на панели', steampunkColors.tertiary, steampunkColors.surface, 4.5),
      ('«провален» на панели', steampunkColors.error, steampunkColors.surface, 4.5),
      ('текст кнопки', steampunkColors.onPrimary, steampunkColors.primary, 4.5),
      ('текст ошибки', steampunkColors.onErrorContainer, steampunkColors.errorContainer, 4.5),
      ('названия разделов (окись) на панели', sectionTitleColor, steampunkColors.surface, 4.5),
      ('подпись поля ввода', mutedBrass, walnutDeep, 4.5),
      ('инициалы на заглушке фото (крупный текст)', mutedBrass, walnutLight, 3),
    ];

    for (final (name, foreground, background, minimum) in pairs) {
      test('контраст: $name не ниже $minimum:1', () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(minimum));
      });
    }

    // Итерация 9: панель была темнее центра фона и сливалась с ним (1,13:1).
    // Теперь она светлее фона во ВСЕХ точках радиального градиента, и
    // выделяется оттенком, а не одной только рамкой.
    test('панель светлее фона везде: и в центре, и по краям градиента', () {
      for (final background in backdropColors) {
        expect(
          walnut.computeLuminance(),
          greaterThan(background.computeLuminance()),
          reason: '$background',
        );
      }
      expect(contrast(walnut, backdropColors.first), greaterThanOrEqualTo(1.25));
      expect(contrast(walnut, backdropColors.last), greaterThanOrEqualTo(1.3));
    });

    test('заглушка фото отличается от панели, поле ввода темнее панели', () {
      expect(contrast(walnutLight, walnut), greaterThanOrEqualTo(1.2));
      expect(walnutDeep.computeLuminance(), lessThan(walnut.computeLuminance()));
    });

    test('заставка и AppBar не изменились: общий край фона leatherDeep', () {
      expect(backdropColors.last, leatherDeep);
      expect(splashBackgroundColor, leatherDeep);
    });

    test('тема собирается и тёмная', () {
      final theme = buildSteampunkTheme();
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, leatherDeep);
    });
  });

  group('gearPath', () {
    const center = Offset(100, 100);

    test('зубья в пределах радиуса, в центре отверстие', () {
      final path = gearPath(center: center, radius: 50, teeth: 10);
      final bounds = path.getBounds();

      expect(bounds.left, greaterThanOrEqualTo(49.9));
      expect(bounds.right, lessThanOrEqualTo(150.1));
      expect(bounds.top, greaterThanOrEqualTo(49.9));
      expect(bounds.bottom, lessThanOrEqualTo(150.1));

      expect(path.contains(center), isFalse); // отверстие
      expect(path.contains(center + const Offset(25, 0)), isTrue); // тело
      expect(path.contains(center + const Offset(60, 0)), isFalse); // снаружи
    });
  });

  group('рисование', () {
    test('GearsPainter рисует на холсте без ошибок, в том числе на пустом', () {
      const painter = GearsPainter(color: brass);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      painter.paint(canvas, Size.zero);
      recorder.endRecording().dispose();
    });

    test('окисленные шестерёнки: смена цвета окиси тоже перерисовывает', () {
      const base = GearsPainter(color: brass);
      expect(base.shouldRepaint(const GearsPainter(color: brass, patina: copper)), isTrue);
    });

    test('shouldRepaint: только при смене цвета или зерна', () {
      const base = GearsPainter(color: brass);
      expect(base.shouldRepaint(const GearsPainter(color: brass)), isFalse);
      expect(base.shouldRepaint(const GearsPainter(color: copper)), isTrue);
      expect(base.shouldRepaint(const GearsPainter(color: brass, seed: 1)), isTrue);
    });

    testWidgets('фон и панель показывают содержимое и не зацикливают анимацию',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: SteampunkBackdrop(
              child: Center(child: BrassPanel(child: Text('hola'))),
            ),
          ),
        ),
      );
      // Если бы узор анимировался бесконечно, pumpAndSettle не вернулся бы.
      await tester.pumpAndSettle();

      expect(find.text('hola'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('эмблема и кольцо рисуются', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: Center(
              child: BrassRing(child: GearEmblem(size: 100)),
            ),
          ),
        ),
      );

      expect(find.byType(GearEmblem), findsOneWidget);
      // 100 (эмблема) + 2 * 13 (кольцо по умолчанию)
      expect(tester.getSize(find.byType(BrassRing)), const Size(126, 126));
    });

    testWidgets('панели любых размеров рисуются без ошибок, в том числе крошечные',
        (tester) async {
      for (final side in [20.0, 59.0, 61.0, 120.0, 400.0]) {
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: const BrassPanel(padding: EdgeInsets.zero, child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'сторона $side');
      }
    });

    testWidgets('латунная линия: высота и вставка в AppBar', (tester) async {
      expect(const BrassLine().preferredSize.height, BrassLine.height);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            appBar: AppBar(title: const Text('t'), bottom: const BrassLine()),
          ),
        ),
      );

      expect(find.byType(BrassLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('PipesPainter рисует трубы и кабели, на крошечном окне ничего не рисует', () {
      const painter = PipesPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      painter.paint(canvas, const Size(100, 100));
      painter.paint(canvas, Size.zero);
      recorder.endRecording().dispose();
      expect(painter.shouldRepaint(const PipesPainter()), isFalse);
    });

    testWidgets('угловая шестерня: центр в правом нижнем углу, видна четверть',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(const Scaffold(body: SteampunkBackdrop(child: SizedBox()))),
      );

      final gear = find.byType(CornerGear);
      expect(gear, findsOneWidget);
      // Центр шестерни ровно в углу экрана 400 × 800.
      expect(tester.getCenter(gear), const Offset(400, 800));
      // Радиус: 46 % короткой стороны, но не меньше 100 и не больше 260.
      expect(tester.getSize(gear), const Size(2 * 184, 2 * 184));
    });
  });

  group('эмблема: цепочка из семи шестерёнок четырёх размеров', () {
    final gears = placeEmblemGears();

    test('их семь, большая первая и ведущая', () {
      expect(gears, hasLength(7));
      expect(gears.first.isBig, isTrue);
      expect(gears.first.parent, -1);
      expect(gears.skip(1).every((g) => !g.isBig), isTrue);
    });

    test('четыре разных размера: не «одна большая и четыре одинаковых»', () {
      final radii = gears.map((g) => g.radius).toSet();
      expect(radii, hasLength(4));
      // Большая заметно крупнее остальных, самая малая заметно мельче.
      expect(gears.first.radius, greaterThan(radii.reduce(math.max) - 1e-9));
      expect(gears.first.radius / radii.reduce(math.min), greaterThan(2));
    });

    test('цепочка несимметрична: ветвление и глубина больше двух', () {
      int depth(int i) => gears[i].parent < 0 ? 0 : 1 + depth(gears[i].parent);
      expect(List.generate(gears.length, depth).reduce(math.max), greaterThanOrEqualTo(3));

      // Ветвление: у кого-то из шестерёнок не меньше двух «детей»; и есть
      // шестерёнка, у которой дети в цепочке свои (не звезда вокруг одной).
      final children = <int, int>{};
      for (final g in gears.skip(1)) {
        children[g.parent] = (children[g.parent] ?? 0) + 1;
      }
      expect(children.values.reduce(math.max), greaterThanOrEqualTo(2));
      expect(children.keys.where((i) => i != 0), isNotEmpty);
    });

    test('все помещаются в квадрат эмблемы с полем', () {
      for (final g in gears) {
        expect(g.center.dx - g.radius, greaterThanOrEqualTo(0.02));
        expect(g.center.dy - g.radius, greaterThanOrEqualTo(0.02));
        expect(g.center.dx + g.radius, lessThanOrEqualTo(0.98));
        expect(g.center.dy + g.radius, lessThanOrEqualTo(0.98));
      }
    });

    test('каждая зацеплена со своим родителем: вершина зуба заходит во впадину, но не глубже', () {
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        final distance = (g.center - p.center).distance;
        // Вершина зуба одной шестерёнки не заходит глубже впадины другой
        // (впадина на 0.8 радиуса) и всё же сцеплена: оси ближе, чем сумма радиусов.
        expect(distance, greaterThanOrEqualTo(p.radius + 0.8 * g.radius - 1e-9));
        expect(distance, greaterThanOrEqualTo(g.radius + 0.8 * p.radius - 1e-9));
        expect(distance, lessThan(p.radius + g.radius));
      }
    });

    test('несцепленные шестерёнки не касаются друг друга', () {
      for (var i = 0; i < gears.length; i++) {
        for (var j = i + 1; j < gears.length; j++) {
          if (gears[j].parent == i || gears[i].parent == j) {
            continue; // сцепленная пара
          }
          final distance = (gears[i].center - gears[j].center).distance;
          expect(distance, greaterThan(gears[i].radius + gears[j].radius + 0.02),
              reason: 'шестерёнки $i и $j');
        }
      }
    });

    test('шаг зубьев у всех близок: зубья помещаются во впадины соседей', () {
      // Шаг = длина дуги по внешнему радиусу на один зуб.
      final pitches = [
        for (final g in gears) 2 * math.pi * g.radius / g.teeth,
      ];
      final lowest = pitches.reduce(math.min);
      final highest = pitches.reduce(math.max);
      expect(highest / lowest, lessThan(1.15));
    });

    test('скорости обратно пропорциональны числу зубьев, соседи крутятся навстречу', () {
      expect(gears.first.ratio, 1);
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        expect(g.ratio.sign, -p.ratio.sign);
        // Линейная скорость на делительной окружности одинакова: ω₁·z₁ = -ω₂·z₂.
        expect(g.ratio * g.teeth, closeTo(-p.ratio * p.teeth, 1e-9));
        // Для любой шестерёнки модуль скорости зависит только от числа зубьев.
        expect(g.ratio.abs() * g.teeth, closeTo(emblemBigTeeth.toDouble(), 1e-9));
      }
    });

    test('зубья входят во впадины в любой момент вращения (для всей цепочки)', () {
      // Условие сцепления: в точке касания «доля зуба» родителя плюс «доля
      // зуба» ребёнка равна 0.5 (mod 1): зуб против впадины.
      final omega = 2 * math.pi / emblemRevolutionSeconds;
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        final alpha = math.atan2(
          g.center.dy - p.center.dy,
          g.center.dx - p.center.dx,
        );
        for (final t in [0.0, 1.7, 9.3, 36.0, 123.456]) {
          final thetaParent = p.phase + p.ratio * omega * t;
          final thetaChild = g.phase + g.ratio * omega * t;
          final fractionParent = (alpha - thetaParent) * p.teeth / (2 * math.pi);
          final fractionChild =
              (alpha + math.pi - thetaChild) * g.teeth / (2 * math.pi);
          final sum = (fractionParent + fractionChild) % 1;
          expect(sum, closeTo(0.5, 1e-9),
              reason: 'шестерёнка на ${g.teeth} зубьев, t=$t');
        }
      }
    });

    test('геометрия: контуры сцепленных пар не пересекаются в любой момент', () {
      // Самая надёжная проверка: берём настоящие контуры (gearPath) и считаем,
      // не попадает ли точка внутрь обоих. Выборка точек сетки в области
      // пересечения кругов пары.
      const scale = 1000.0;
      final omega = 2 * math.pi / emblemRevolutionSeconds;
      for (final t in [0.0, 3.1, 11.0, 47.5]) {
        Path pathOf(PlacedGear g) => gearPath(
              center: g.center * scale,
              radius: g.radius * scale,
              teeth: g.teeth,
              rotation: g.phase + g.ratio * omega * t,
              holeRatio: 0,
            );
        for (final g in gears.skip(1)) {
          final a = pathOf(gears[g.parent]);
          final b = pathOf(g);
          final mid = (g.center + gears[g.parent].center) * (scale / 2);
          var bothInside = 0;
          for (var dx = -90.0; dx <= 90; dx += 3) {
            for (var dy = -90.0; dy <= 90; dy += 3) {
              final point = mid + Offset(dx, dy);
              if (a.contains(point) && b.contains(point)) {
                bothInside++;
              }
            }
          }
          expect(bothInside, 0, reason: 'зубья «наехали», t=$t, зубьев: ${g.teeth}');
        }
      }
    });
  });

  group('вращение', () {
    Widget scene({required bool disableAnimations}) => testApp(
          const Scaffold(
            body: Center(child: GearEmblem(size: 120)),
          ),
          disableAnimations: disableAnimations,
        );

    testWidgets('по умолчанию шестерёнки крутятся: кадры планируются', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('«убрать анимации» в системе: шестерёнки стоят', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle(); // не зависает
    });

    testWidgets('animate: false останавливает вращение', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: Center(child: GearEmblem(animate: false))),
          disableAnimations: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('часы идут вместе со временем',
        (tester) async {
      final seen = <double>[];
      Widget clock({required bool enabled}) => testApp(
            GearClock(
              enabled: enabled,
              builder: (context, seconds) {
                seconds.addListener(() => seen.add(seconds.value));
                return const SizedBox();
              },
            ),
            disableAnimations: false,
          );

      await tester.pumpWidget(clock(enabled: true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(seen, isNotEmpty);
      expect(seen.last, greaterThan(0.9));
    });

    testWidgets('уход с экрана освобождает часы без ошибок', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
