import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/core/login.dart';
import 'package:swifty_companion/l10n/app_strings.dart';
import 'package:swifty_companion/ui/config_error_screen.dart';

import 'test_app.dart';

void main() {
  const errors = <ApiException>[
    NetworkException(),
    NetworkException.timeout(),
    AuthException(),
    NotFoundException(),
    RateLimitException(),
    ServerException(),
    UnexpectedResponseException(),
  ];

  for (final code in ['es', 'en']) {
    group('словарь "$code"', () {
      final strings = AppStrings.forLocale(Locale(code));

      test('у каждой ошибки непустой уникальный текст', () {
        final texts = errors.map(strings.errorText).toList();
        expect(texts.every((t) => t.isNotEmpty), isTrue);
        expect(texts.toSet().length, texts.length);
      });

      test('у каждой проблемы логина свой непустой текст', () {
        final texts = LoginProblem.values.map(strings.loginProblemText).toList();
        expect(texts.every((t) => t.isNotEmpty), isTrue);
        expect(texts.toSet().length, texts.length);
      });

      test('Retry-After дописывается числом секунд', () {
        final text =
            strings.errorText(const RateLimitException(retryAfter: Duration(seconds: 42)));
        expect(text, contains('42'));
        expect(text, startsWith(strings.errorText(const RateLimitException())));
      });
    });
  }

  test('испанский и английский словари действительно разные', () {
    final es = AppStrings.forLocale(const Locale('es'));
    final en = AppStrings.forLocale(const Locale('en'));
    expect(es.searchButton, isNot(en.searchButton));
    expect(es.notFoundError, isNot(en.notFoundError));
  });

  group('выбор языка по языку телефона', () {
    Future<String> searchLabelFor(WidgetTester tester, Locale locale) async {
      late String label;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Builder(builder: (context) {
            label = AppStrings.of(context).searchButton;
            return const SizedBox();
          }),
        ),
      );
      return label;
    }

    testWidgets('es-ES → испанский', (tester) async {
      expect(await searchLabelFor(tester, const Locale('es', 'ES')), 'Buscar');
    });

    testWidgets('en-US → английский', (tester) async {
      expect(await searchLabelFor(tester, const Locale('en', 'US')), 'Search');
    });

    testWidgets('русский и любой другой → испанский по умолчанию', (tester) async {
      expect(await searchLabelFor(tester, const Locale('ru')), 'Buscar');
      expect(await searchLabelFor(tester, const Locale('de', 'DE')), 'Buscar');
    });
  });

  group('экран ошибки конфигурации', () {
    testWidgets('показывает недостающие переменные', (tester) async {
      await tester.pumpWidget(
        const ConfigErrorApp(missingKeys: ['FT_UID', 'FT_SECRET']),
      );
      // Имена переменных одинаковы в обоих языках, поэтому от языка не зависим.
      expect(find.textContaining('FT_UID, FT_SECRET'), findsOneWidget);
    });

    testWidgets('нечитаемый .env', (tester) async {
      await tester.pumpWidget(const ConfigErrorApp(unreadable: true));
      expect(find.textContaining('.env'), findsWidgets);
    });
  });

  testWidgets('testApp подключает встроенные переводы Flutter', (tester) async {
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Text(MaterialLocalizations.of(context).backButtonTooltip),
        ),
      ),
    );
    expect(find.text('Atrás'), findsOneWidget);
  });
}
