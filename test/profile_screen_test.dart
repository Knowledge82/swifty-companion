import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/profile_screen.dart';

import 'fixtures.dart';
import 'test_app.dart';

void main() {
  Future<void> pumpProfile(WidgetTester tester, Map<String, dynamic> json) {
    return tester.pumpWidget(
      testApp(ProfileScreen(profile: UserProfile.fromJson(json))),
    );
  }

  testWidgets('показывает основные поля профиля', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('jdoe'), findsOneWidget); // заголовок
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jdoe@example.com'), findsOneWidget);
    expect(find.text('3.00'), findsOneWidget); // уровень 42cursus
    expect(find.text('42'), findsOneWidget); // кошелёк
    expect(find.text('5'), findsOneWidget); // очки оценки
  });

  testWidgets('скрытое и пустое выводится как N/A', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // телефон ("hidden") и место (null)
    expect(find.text('N/A'), findsNWidgets(2));
  });

  testWidgets('минимальный профиль не ломает экран', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    // имя, email, телефон, место, уровень, кошелёк, очки
    expect(find.text('N/A'), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('без фото показывается заглушка', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
