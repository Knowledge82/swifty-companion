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

  testWidgets('no addresses: placeholder at once, loading is not called', (tester) async {
    var calls = 0;
    await tester.pumpWidget(avatar([], (url) async {
      calls++;
      return png;
    }));

    expect(find.text('JD'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('while the photo loads: an indicator', (tester) async {
    final gate = Completer<Uint8List>();
    await tester.pumpWidget(avatar(['u1'], (url) => gate.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('JD'), findsNothing);

    gate.complete(png);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the first address loaded: the image is shown', (tester) async {
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

  testWidgets('the first address failed: the second is tried', (tester) async {
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

  testWidgets('all addresses failed: a placeholder with initials', (tester) async {
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
