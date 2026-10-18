import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    // Фон панелей (изумруд) и экрана/AppBar (тёмная кожа). Текст и значки на них.
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
      ('подпись поля ввода', mutedBrass, emeraldDeep, 4.5),
      ('инициалы на заглушке фото (крупный текст)', mutedBrass, emeraldLight, 3),
    ];

    for (final (name, foreground, background, minimum) in pairs) {
      test('контраст: $name не ниже $minimum:1', () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(minimum));
      });
    }

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

  group('эмблема из пяти шестерёнок', () {
    final gears = placeEmblemGears();

    test('их пять, большая первая', () {
      expect(gears, hasLength(5));
      expect(gears.first.isBig, isTrue);
      expect(gears.skip(1).every((g) => !g.isBig), isTrue);
    });

    test('все помещаются в квадрат эмблемы', () {
      for (final g in gears) {
        expect(g.center.dx - g.radius, greaterThanOrEqualTo(0));
        expect(g.center.dy - g.radius, greaterThanOrEqualTo(0));
        expect(g.center.dx + g.radius, lessThanOrEqualTo(1));
        expect(g.center.dy + g.radius, lessThanOrEqualTo(1));
      }
    });

    test('малые зацеплены с большой: вершина зуба заходит во впадину, но не глубже', () {
      final big = gears.first;
      for (final g in gears.skip(1)) {
        final distance = (g.center - big.center).distance;
        // Вершина зуба одной шестерёнки не заходит глубже впадины другой
        // (впадина на 0.8 радиуса) и всё же сцеплена: оси ближе, чем сумма радиусов.
        expect(distance, greaterThanOrEqualTo(big.radius + 0.8 * g.radius - 1e-9));
        expect(distance, greaterThanOrEqualTo(g.radius + 0.8 * big.radius - 1e-9));
        expect(distance, lessThan(big.radius + g.radius));
      }
    });

    test('малые шестерёнки не задевают друг друга', () {
      final small = gears.skip(1).toList();
      for (var i = 0; i < small.length; i++) {
        for (var j = i + 1; j < small.length; j++) {
          final distance = (small[i].center - small[j].center).distance;
          expect(distance, greaterThan(small[i].radius + small[j].radius),
              reason: 'шестерёнки $i и $j');
        }
      }
    });

    test('скорости обратно пропорциональны числу зубьев и направлены навстречу', () {
      final big = gears.first;
      for (final g in gears.skip(1)) {
        expect(g.ratio, lessThan(0));
        // Линейная скорость на делительной окружности одинакова: ω₁·z₁ = -ω₂·z₂.
        expect(g.ratio * g.teeth, closeTo(-emblemBigTeeth.toDouble(), 1e-9));
        expect(big.ratio, 1);
      }
    });

    test('зубья входят во впадины в любой момент вращения', () {
      // Условие сцепления: в точке касания «доля зуба» большой шестерёнки
      // плюс «доля зуба» малой равна 0.5 (mod 1): зуб против впадины.
      final big = gears.first;
      final omega = 2 * math.pi / emblemRevolutionSeconds;
      for (final g in gears.skip(1)) {
        final alpha = math.atan2(
          g.center.dy - big.center.dy,
          g.center.dx - big.center.dx,
        );
        for (final t in [0.0, 1.7, 9.3, 36.0, 123.456]) {
          final thetaBig = big.phase + big.ratio * omega * t;
          final thetaSmall = g.phase + g.ratio * omega * t;
          final fractionBig = (alpha - thetaBig) * big.teeth / (2 * math.pi);
          final fractionSmall =
              (alpha + math.pi - thetaSmall) * g.teeth / (2 * math.pi);
          final sum = (fractionBig + fractionSmall) % 1;
          expect(sum, closeTo(0.5, 1e-9), reason: 'шестерёнка ${g.teeth}, t=$t');
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
