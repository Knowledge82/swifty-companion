import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/splash_screen.dart';

import 'fake_api.dart';
import 'test_app.dart';

void main() {
  final png = Uint8List.fromList(tinyPng);

  Widget app({Duration duration = const Duration(seconds: 2)}) {
    return testApp(
      SplashScreen(
        next: const Scaffold(body: Text('next-screen')),
        duration: duration,
        image: MemoryImage(png),
      ),
    );
  }

  testWidgets('сначала заставка: название и картинка, следующего экрана нет',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Swifty Companion'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('next-screen'), findsNothing);
  });

  testWidgets('до конца времени следующий экран не открывается', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 1900)); // таймер на 2000

    expect(find.text('next-screen'), findsNothing);
    expect(find.text('Swifty Companion'), findsOneWidget);
  });

  testWidgets('по истечении времени заставка сменяется следующим экраном',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2)); // сработал таймер
    await tester.pump(const Duration(milliseconds: 700)); // дошла смена кадра

    expect(find.text('next-screen'), findsOneWidget);
    expect(find.text('Swifty Companion'), findsNothing);
  });

  testWidgets('касание пропускает заставку', (tester) async {
    await tester.pumpWidget(app(duration: const Duration(minutes: 5)));

    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('next-screen'), findsOneWidget);
  });

  testWidgets('уход с экрана раньше времени не оставляет таймера и ошибок',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });

  testWidgets('края растушёваны: две маски по альфа-каналу', (tester) async {
    await tester.pumpWidget(app());

    final masks = tester.widgetList<ShaderMask>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(ShaderMask),
    ));
    expect(masks.length, greaterThanOrEqualTo(2));
    expect(masks.every((m) => m.blendMode == BlendMode.dstIn), isTrue);
  });

  testWidgets('картинка вписана с сохранением пропорций', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    final size = tester.getSize(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(AspectRatio),
    ));
    expect(size.width / size.height, closeTo(splashImageAspect, 0.001));
    expect(size.width, 400); // по ширине экрана, сверху и снизу свободное место
  });

  test('файл картинки на месте и объявлен в pubspec.yaml', () {
    expect(File(splashImageAsset).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains(splashImageAsset));
  });
}
