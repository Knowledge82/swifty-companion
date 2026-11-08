import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/data/user_repository.dart';
import 'package:swifty_companion/ui/error_banner.dart';
import 'package:swifty_companion/ui/search_screen.dart';
import 'package:swifty_companion/ui/steampunk/gears.dart';

import 'fake_api.dart';
import 'fixtures.dart';
import 'test_app.dart';

/// A profile without a photo: in widget tests `Image.network` does not go to
/// the network, and there is no need to check it here (the placeholder is
/// checked in profile_screen_test).
Map<String, dynamic> _userWithoutImage() => sampleUserJson()..remove('image');

void main() {
  Future<void> pumpScreen(WidgetTester tester, FakeApi fake) {
    return tester.pumpWidget(
      testApp(
        SearchScreen(
          repository: UserRepository(fake.api),
          photoLoader: fake.photos,
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String login) async {
    await tester.enterText(find.byType(TextField), login);
    await tester.tap(find.byType(FilledButton));
  }

  FakeApi okApi() => FakeApi(
        onUser: (request, attempt) async => jsonResponse(_userWithoutImage()),
      );

  testWidgets('empty input: an error under the field and no requests',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester, fake);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Introduce un login'), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
    expect(fake.tokenCalls, 0);
    expect(fake.userRequests, isEmpty);
  });

  testWidgets('invalid characters: an error under the field and no requests',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester, fake);

    await search(tester, 'a b');
    await tester.pump();

    expect(find.textContaining('Solo letras latinas'), findsOneWidget);
    expect(fake.userRequests, isEmpty);
  });

  testWidgets('success: the profile opens, back returns to the search',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester, fake);

    await search(tester, '  JDoe ');
    await tester.pumpAndSettle();

    expect(fake.userRequests.single.url.path, '/v2/users/jdoe');
    expect(find.text('Jane Doe'), findsOneWidget);

    // Not `tester.pageBack()`: it looks for the 'Back' tooltip, and in Spanish
    // the tooltip is called 'Atrás'.
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('login not found: a banner, we stay on the search screen',
      (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({'error': 'x'}, 404),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'nobody');
    await tester.pumpAndSettle();

    expect(find.text('No se ha encontrado ningún usuario con ese login.'), findsOneWidget);
    expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('no network: a banner about the connection', (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async =>
          throw const SocketException('offline'),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión a internet'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('429 with Retry-After: the banner shows the waiting time',
      (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async =>
          jsonResponse({}, 429, {'retry-after': '30'}),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pumpAndSettle();

    expect(find.textContaining('Puedes reintentar en 30 s.'), findsOneWidget);
  });

  testWidgets('an error in our code: a general message, the app is alive',
      (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async => throw StateError('bug'),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pumpAndSettle();

    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('loading: an indicator, the field and button are blocked, one request',
      (tester) async {
    final gate = Completer<void>();
    final fake = FakeApi(
      onUser: (request, attempt) async {
        await gate.future;
        return jsonResponse(_userWithoutImage());
      },
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Buscar'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    // A repeated tap during loading sends nothing.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(fake.userRequests, hasLength(1));
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('typing a character removes the old error', (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({}, 404),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'nobody');
    await tester.pumpAndSettle();
    expect(find.byType(ErrorBanner), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody2');
    await tester.pump();

    expect(find.byType(ErrorBanner), findsNothing);
  });

  testWidgets('after an error the search can be repeated and succeed',
      (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async => attempt == 1
          ? jsonResponse({}, 500)
          : jsonResponse(_userWithoutImage()),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pumpAndSettle();
    expect(find.byType(ErrorBanner), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(fake.userRequests, hasLength(2));
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('steampunk: the search screen has a gear emblem', (tester) async {
    await pumpScreen(tester, okApi());

    expect(find.byType(GearEmblem), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
