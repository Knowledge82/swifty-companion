import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/splash_screen.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_widgets.dart';

import 'fake_api.dart';
import 'test_app.dart';

/// Картинка, которая никогда не загружается: проверяем страховочный таймер.
class _NeverLoadedImage extends ImageProvider<_NeverLoadedImage> {
  const _NeverLoadedImage();

  @override
  Future<_NeverLoadedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_NeverLoadedImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverLoadedImage key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

void main() {
  final png = Uint8List.fromList(tinyPng);

  Widget app({
    Duration duration = const Duration(seconds: 3),
    Duration fadeIn = const Duration(milliseconds: 700),
    Duration fadeOut = const Duration(milliseconds: 600),
    bool disableAnimations = false,
    bool waitForImage = false,
    ImageProvider? image,
  }) {
    return testApp(
      SplashScreen(
        next: const Scaffold(body: Text('next-screen')),
        duration: duration,
        fadeIn: fadeIn,
        fadeOut: fadeOut,
        waitForImage: waitForImage,
        image: image ?? MemoryImage(png),
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

    await tester.pump(const Duration(milliseconds: 400)); // 750 > 700
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
    // Общее время 3000, угасание последние 600: начинается на 2400.
    await tester.pump(const Duration(milliseconds: 2700));

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
    await tester.pump(const Duration(milliseconds: 500)); // дошла смена кадра

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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('next-screen'), findsOneWidget);
  });

  testWidgets(
      'часы ждут картинку: пока она не готова, заставка прозрачна; '
      'страховочный таймер всё равно запускает проявление', (tester) async {
    await tester.pumpWidget(
      app(waitForImage: true, image: const _NeverLoadedImage()),
    );

    await tester.pump(const Duration(milliseconds: 1000));
    expect(introOpacity(tester), 0); // ждём, время проявления не тратится

    await tester.pump(const Duration(milliseconds: 600)); // ждали 1600 > 1500
    await tester.pump(const Duration(milliseconds: 350));
    expect(introOpacity(tester), greaterThan(0)); // проявление пошло

    await tester.pump(const Duration(seconds: 5)); // доиграть до конца
    await tester.pump(const Duration(milliseconds: 500)); // смена экрана
    expect(find.text('next-screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('уход с экрана во время ожидания картинки гасит таймер',
      (tester) async {
    await tester.pumpWidget(
      app(waitForImage: true, image: const _NeverLoadedImage()),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    // Если бы таймер остался, тест упал бы с «Timer is still pending».
    expect(tester.takeException(), isNull);
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

  test('фон заставки: один сплошной очень тёмный цвет, но не чисто чёрный', () {
    expect(splashBackgroundColor.a, 1); // сплошной, без прозрачности
    expect(splashBackgroundColor.computeLuminance(), lessThan(0.02)); // очень тёмный
    expect(splashBackgroundColor.computeLuminance(), greaterThan(0.003)); // не чёрный
  });

  testWidgets('на заставке нет узорного фона: шестерёнок и труб',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.byType(SteampunkBackdrop), findsNothing);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, splashBackgroundColor);
  });

  testWidgets('телефон в портрете: картинка целиком по ширине, сверху и снизу фон',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    final size = tester.getSize(find.byType(Image));
    expect(size.width, 400); // по ширине экрана: бока не обрезаются
    expect(size.height, closeTo(400 / splashImageAspect, 0.001)); // 600
    expect(size.height, lessThan(900)); // сверху и снизу остаётся фон

    // Картинка по центру по вертикали: полосы фона равны.
    final rect = tester.getRect(find.byType(Image));
    expect(rect.top, closeTo(900 - rect.bottom, 0.001));

    // Растушёвка ровно одна, и это вертикальная: градиент идёт сверху вниз.
    final masks = tester.widgetList<ShaderMask>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(ShaderMask),
    ));
    expect(masks, hasLength(1));
    expect(masks.single.blendMode, BlendMode.dstIn);
  });

  test('длина перехода в фон разумна: от 5 до 30 % размера картинки', () {
    expect(splashFeather, inInclusiveRange(0.05, 0.30));
  });

  testWidgets('широкий экран: по высоте, по бокам тёмный фон и растушёванные края',
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

  testWidgets('экран с теми же пропорциями, что у картинки: масок нет',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    expect(tester.getSize(find.byType(Image)), const Size(400, 600));
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
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
