import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/steampunk/gears.dart';
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
      // 100 (эмблема) + 2 * 9 (кольцо по умолчанию)
      expect(tester.getSize(find.byType(BrassRing)), const Size(118, 118));
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

    testWidgets('полоса с узором: высота и вставка в AppBar', (tester) async {
      expect(const GearStrip().preferredSize.height, GearStrip.height);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            appBar: AppBar(title: const Text('t'), bottom: const GearStrip()),
          ),
        ),
      );

      expect(find.byType(GearStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
