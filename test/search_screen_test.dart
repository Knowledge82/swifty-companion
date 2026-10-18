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

/// Профиль без фото: в тестах виджетов `Image.network` не ходит в сеть,
/// и нам незачем проверять его здесь (заглушка проверяется в profile_screen_test).
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

  testWidgets('пустой ввод: ошибка под полем и ни одного запроса',
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

  testWidgets('неверные символы: ошибка под полем и ни одного запроса',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester, fake);

    await search(tester, 'a b');
    await tester.pump();

    expect(find.textContaining('Solo letras latinas'), findsOneWidget);
    expect(fake.userRequests, isEmpty);
  });

  testWidgets('успех: открывается профиль, назад возвращает на поиск',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester, fake);

    await search(tester, '  JDoe ');
    await tester.pumpAndSettle();

    expect(fake.userRequests.single.url.path, '/v2/users/jdoe');
    expect(find.text('Jane Doe'), findsOneWidget);

    // Не `tester.pageBack()`: он ищет подсказку 'Back', а при испанском
    // языке подсказка называется 'Atrás'.
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('логин не найден: баннер, остаёмся на экране поиска',
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

  testWidgets('нет сети: баннер про соединение', (tester) async {
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

  testWidgets('429 с Retry-After: в баннере указано время ожидания',
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

  testWidgets('ошибка в нашем коде: общее сообщение, приложение живо',
      (tester) async {
    final fake = FakeApi(
      onUser: (request, attempt) async => throw StateError('баг'),
    );
    await pumpScreen(tester, fake);

    await search(tester, 'jdoe');
    await tester.pumpAndSettle();

    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('загрузка: индикатор, поле и кнопка заблокированы, запрос один',
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

    // Повторное нажатие во время загрузки ничего не отправляет.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(fake.userRequests, hasLength(1));
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('ввод символа убирает старую ошибку', (tester) async {
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

  testWidgets('после ошибки можно повторить поиск и получить успех',
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

  testWidgets('стимпанк: на экране поиска есть эмблема из шестерёнок', (tester) async {
    await pumpScreen(tester, okApi());

    expect(find.byType(GearEmblem), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
