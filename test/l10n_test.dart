import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
    group('dictionary "$code"', () {
      final strings = AppStrings.forLocale(Locale(code));

      test('every error has a non-empty unique text', () {
        final texts = errors.map(strings.errorText).toList();
        expect(texts.every((t) => t.isNotEmpty), isTrue);
        expect(texts.toSet().length, texts.length);
      });

      test('every login problem has its own non-empty text', () {
        final texts = LoginProblem.values.map(strings.loginProblemText).toList();
        expect(texts.every((t) => t.isNotEmpty), isTrue);
        expect(texts.toSet().length, texts.length);
      });

      test('Retry-After is appended as a number of seconds', () {
        final text =
            strings.errorText(const RateLimitException(retryAfter: Duration(seconds: 42)));
        expect(text, contains('42'));
        expect(text, startsWith(strings.errorText(const RateLimitException())));
      });
    });
  }

  test('the Spanish and English dictionaries really differ', () {
    final es = AppStrings.forLocale(const Locale('es'));
    final en = AppStrings.forLocale(const Locale('en'));
    expect(es.searchButton, isNot(en.searchButton));
    expect(es.notFoundError, isNot(en.notFoundError));
  });

  group('language choice by the phone language', () {
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

    testWidgets('es-ES gives Spanish', (tester) async {
      expect(await searchLabelFor(tester, const Locale('es', 'ES')), 'Buscar');
    });

    testWidgets('en-US gives English', (tester) async {
      expect(await searchLabelFor(tester, const Locale('en', 'US')), 'Search');
    });

    testWidgets('Russian and any other language give Spanish by default', (tester) async {
      expect(await searchLabelFor(tester, const Locale('ru')), 'Buscar');
      expect(await searchLabelFor(tester, const Locale('de', 'DE')), 'Buscar');
    });
  });

  group('configuration error screen', () {
    testWidgets('shows the missing variables', (tester) async {
      await tester.pumpWidget(
        const ConfigErrorApp(missingKeys: ['FT_UID', 'FT_SECRET']),
      );
      // The variable names are the same in both languages, so we do not depend
      // on the language.
      expect(find.textContaining('FT_UID, FT_SECRET'), findsOneWidget);
    });

    testWidgets('unreadable .env', (tester) async {
      await tester.pumpWidget(const ConfigErrorApp(unreadable: true));
      expect(find.textContaining('.env'), findsWidgets);
    });
  });

  testWidgets('testApp plugs in the built-in Flutter translations', (tester) async {
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
