import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/splash_screen.dart';

import 'fake_api.dart';
import 'test_app.dart';

void main() {
  final png = Uint8List.fromList(tinyPng);

  Widget app({
    Duration duration = const Duration(seconds: 3),
    Duration fadeIn = const Duration(milliseconds: 800),
    Duration fadeOut = const Duration(milliseconds: 700),
    bool disableAnimations = false,
  }) {
    return testApp(
      SplashScreen(
        next: const Scaffold(body: Text('next-screen')),
        duration: duration,
        fadeIn: fadeIn,
        fadeOut: fadeOut,
        image: MemoryImage(png),
      ),
      disableAnimations: disableAnimations,
    );
  }

  /// Текущая прозрачность заставки (свой FadeTransition заставки, а не тот,
  /// которым AnimatedSwitcher плавно меняет экраны).
  double introOpacity(WidgetTester tester) {
    final fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('splash-fade')),
    );
    return fade.opacity.value;
  }

  testWidgets('сначала заставка: название и картинка, следующего экрана нет',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Swifty Companion'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('next-screen'), findsNothing);
  });

  testWidgets('fade-in: в начале прозрачно, к концу появления полностью видно',
      (tester) async {
    await tester.pumpWidget(app());
    expect(introOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 400));
    final middle = introOpacity(tester);
    expect(middle, greaterThan(0));
    expect(middle, lessThan(1));

    await tester.pump(const Duration(milliseconds: 450)); // 850 > 800
    expect(introOpacity(tester), 1);
  });

  testWidgets('в середине заставка держится полностью видимой', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 1500));

    expect(introOpacity(tester), 1);
    expect(find.text('next-screen'), findsNothing);
  });

  testWidgets('fade-out: перед концом картинка гаснет', (tester) async {
    await tester.pumpWidget(app());
    // Общее время 3000, угасание последние 700: начинается на 2300.
    await tester.pump(const Duration(milliseconds: 2650));

    final value = introOpacity(tester);
    expect(value, greaterThan(0));
    expect(value, lessThan(1));
    expect(find.text('next-screen'), findsNothing);
  });

  testWidgets('по истечении времени заставка сменяется следующим экраном',
      (tester) async {
    await tester.pumpWidget(app());
    // Контроллер считает себя завершённым только когда время ПРЕВЫСИЛО
    // длительность (строго больше), поэтому берём чуть больше 3 секунд.
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump(const Duration(milliseconds: 700)); // дошла смена кадра

    expect(find.text('next-screen'), findsOneWidget);
    expect(find.text('Swifty Companion'), findsNothing);
  });

  testWidgets('«убрать анимации»: без плавности, картинка сразу видна',
      (tester) async {
    await tester.pumpWidget(app(disableAnimations: true));

    expect(introOpacity(tester), 1);
  });

  testWidgets('касание пропускает заставку', (tester) async {
    await tester.pumpWidget(app(duration: const Duration(minutes: 5)));

    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('next-screen'), findsOneWidget);
  });

  testWidgets('уход с экрана раньше времени не оставляет анимации и ошибок',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('фон заставки тёмный, но не чисто чёрный', (tester) async {
    for (final color in splashBackdropColors) {
      expect(color.computeLuminance(), lessThan(0.08)); // тёмный
      expect(color.computeLuminance(), greaterThan(0.005)); // не чёрный
    }
  });

  testWidgets('телефон в портрете: картинка вписана по высоте и обрезана по бокам',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    final size = tester.getSize(find.byType(Image));
    expect(size.height, 900); // по высоте экрана
    expect(size.width, closeTo(900 * splashImageAspect, 0.001)); // шире экрана
    expect(size.width, greaterThan(400));
    // Вылезающее за экран обрезается: полос по бокам нет, растушёвки тоже.
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
  });

  testWidgets('широкий экран: по бокам тёмный фон и растушёванные края',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    final size = tester.getSize(find.byType(Image));
    expect(size.height, 600);
    expect(size.width, closeTo(600 * splashImageAspect, 0.001));
    expect(size.width, lessThan(1200));

    final masks = tester.widgetList<ShaderMask>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(ShaderMask),
    ));
    expect(masks, hasLength(1)); // только по горизонтали
    expect(masks.single.blendMode, BlendMode.dstIn);
  });

  group('FeatheredEdges', () {
    Future<int> maskCount(WidgetTester tester,
        {bool horizontal = true, bool vertical = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeatheredEdges(
            horizontal: horizontal,
            vertical: vertical,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      return tester.widgetList(find.byType(ShaderMask)).length;
    }

    testWidgets('обе оси: две маски', (tester) async {
      expect(await maskCount(tester), 2);
    });

    testWidgets('одна ось: одна маска', (tester) async {
      expect(await maskCount(tester, vertical: false), 1);
      expect(await maskCount(tester, horizontal: false), 1);
    });

    testWidgets('ни одной оси: масок нет', (tester) async {
      expect(await maskCount(tester, horizontal: false, vertical: false), 0);
    });
  });

  test('файл картинки на месте и объявлен в pubspec.yaml', () {
    expect(File(splashImageAsset).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains(splashImageAsset));
  });
}
