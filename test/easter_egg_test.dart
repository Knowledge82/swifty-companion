import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/easter_egg.dart';
import 'package:swifty_companion/ui/profile_screen.dart';

import 'fixtures.dart';
import 'test_app.dart';

void main() {
  group('easterEggFor', () {
    test('известные логины получают надпись', () {
      expect(easterEggFor('vdarsuye'), 'EL PUTO AMO');
      expect(easterEggFor('pdoltu'), 'ЙЕБАНИСТА');
    });

    test('регистр и пробелы не мешают', () {
      expect(easterEggFor('  VDarsuye '), 'EL PUTO AMO');
      expect(easterEggFor('PDOLTU'), 'ЙЕБАНИСТА');
    });

    test('остальным ничего', () {
      expect(easterEggFor('jdoe'), isNull);
      expect(easterEggFor(''), isNull);
      expect(easterEggFor('vdarsuye2'), isNull);
    });

    test('выключатель включён по умолчанию', () {
      // Если поставишь false перед защитой, этот тест напомнит поправить
      // и остальные проверки пасхалок.
      expect(easterEggsEnabled, isTrue);
    });
  });

  group('на экране профиля', () {
    Future<void> pumpAs(WidgetTester tester, String login, {double scale = 1}) {
      final json = sampleUserJson()
        ..remove('image')
        ..['login'] = login;
      return tester.pumpWidget(
        testApp(
          ProfileScreen(
            profile: UserProfile.fromJson(json),
            loadPhoto: (url) => Future.error(StateError('нет')),
          ),
          textScale: scale,
        ),
      );
    }

    testWidgets('vdarsuye: надпись под именем', (tester) async {
      await pumpAs(tester, 'vdarsuye');

      expect(find.text('EL PUTO AMO'), findsOneWidget);
      expect(find.text('ЙЕБАНИСТА'), findsNothing);
      // Именно ПОД именем и над панелью с данными.
      expect(
        tester.getTopLeft(find.text('EL PUTO AMO')).dy,
        greaterThan(tester.getTopLeft(find.text('Jane Doe')).dy),
      );
      expect(
        tester.getTopLeft(find.text('EL PUTO AMO')).dy,
        lessThan(tester.getTopLeft(find.text('jdoe@example.com')).dy),
      );
    });

    testWidgets('pdoltu: своя надпись', (tester) async {
      await pumpAs(tester, 'pdoltu');

      expect(find.text('ЙЕБАНИСТА'), findsOneWidget);
      expect(find.text('EL PUTO AMO'), findsNothing);
    });

    testWidgets('обычный логин: надписей нет', (tester) async {
      await pumpAs(tester, 'jdoe');

      expect(find.byType(EasterEggBadge), findsNothing);
    });

    testWidgets('крупный шрифт на узком экране: надпись не переполняет',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);

      await pumpAs(tester, 'pdoltu', scale: 2);

      expect(find.text('ЙЕБАНИСТА'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
