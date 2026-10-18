import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/profile_avatar.dart';

import 'fake_api.dart';
import 'test_app.dart';

void main() {
  final png = Uint8List.fromList(tinyPng);

  Widget avatar(List<String> urls, Future<Uint8List> Function(String) load) {
    return testApp(
      Scaffold(
        body: Center(
          child: ProfileAvatar(urls: urls, loadPhoto: load, initials: 'JD'),
        ),
      ),
    );
  }

  testWidgets('нет адресов: сразу заглушка, загрузка не вызывается', (tester) async {
    var calls = 0;
    await tester.pumpWidget(avatar([], (url) async {
      calls++;
      return png;
    }));

    expect(find.text('JD'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('пока фото грузится — индикатор', (tester) async {
    final gate = Completer<Uint8List>();
    await tester.pumpWidget(avatar(['u1'], (url) => gate.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('JD'), findsNothing);

    gate.complete(png);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('первый адрес загрузился: показывается картинка', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(avatar(['u1', 'u2'], (url) async {
      asked.add(url);
      return png;
    }));
    await tester.pump();

    expect(asked, ['u1']);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('JD'), findsNothing);
  });

  testWidgets('первый адрес упал: пробуется второй', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(avatar(['u1', 'u2'], (url) async {
      asked.add(url);
      if (url == 'u1') {
        throw StateError('403');
      }
      return png;
    }));
    await tester.pump();

    expect(asked, ['u1', 'u2']);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('упали все адреса: заглушка с инициалами', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(avatar(['u1', 'u2', 'u3'], (url) async {
      asked.add(url);
      throw StateError('403');
    }));
    await tester.pump();

    expect(asked, ['u1', 'u2', 'u3']);
    expect(find.byType(Image), findsNothing);
    expect(find.text('JD'), findsOneWidget);
  });
}
