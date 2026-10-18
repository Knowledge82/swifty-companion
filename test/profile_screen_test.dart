import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/profile_screen.dart';

import 'fixtures.dart';
import 'test_app.dart';

void main() {
  Future<void> pumpProfile(WidgetTester tester, Map<String, dynamic> json) {
    return tester.pumpWidget(
      testApp(
        ProfileScreen(
          profile: UserProfile.fromJson(json),
          // Профили в этих тестах без фото, загрузка не должна вызываться.
          loadPhoto: (url) => Future.error(StateError('не должно вызываться: $url')),
        ),
      ),
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

    // телефон ("hidden"), место (null) и итог проекта без оценки
    expect(find.text('N/A'), findsNWidgets(3));
  });

  testWidgets('минимальный профиль не ломает экран', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    // имя, email, телефон, место, уровень, кошелёк, очки
    expect(find.text('N/A'), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('скиллы: уровень и процент, сильные сверху', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('Rigor'), findsOneWidget);
    expect(find.text('9.63 · 48 %'), findsOneWidget); // 9.63 / 20
    expect(find.text('7.00 · 35 %'), findsOneWidget);
    expect(find.text('Sin nombre'), findsOneWidget); // скилл без названия
    expect(find.text('0.00 · 0 %'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rigor')).dy,
      lessThan(tester.getTopLeft(find.text('Web')).dy),
    );
    expect(find.textContaining('nivel ÷ 20'), findsOneWidget);
  });

  testWidgets('проекты: сданные и проваленные, новые сверху', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('Aprobado · 2024-06-01'), findsOneWidget); // push_swap
    expect(find.text('Suspendido · 2024-05-01'), findsOneWidget); // ft_printf
    expect(find.text('Sin resultado · 2024-04-01'), findsOneWidget);
    expect(find.text('Aprobado · 2024-03-01'), findsOneWidget); // libft
    expect(find.text('minishell'), findsNothing); // не завершён

    final y = [
      for (final name in ['push_swap', 'ft_printf', 'c-piscine-shell-00', 'libft'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(y, [...y]..sort());
  });

  testWidgets('нет скиллов и проектов: понятные сообщения', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    expect(find.text('Sin habilidades todavía'), findsOneWidget);
    expect(find.text('Aún no hay proyectos completados'), findsOneWidget);
  });

  testWidgets('английский язык: заголовки разделов', (tester) async {
    await tester.pumpWidget(
      testApp(
        ProfileScreen(
          profile: UserProfile.fromJson(sampleUserJson()..remove('image')),
          loadPhoto: (url) => Future.error(StateError('нет')),
        ),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Completed projects'), findsOneWidget);
    expect(find.text('Passed · 2024-06-01'), findsOneWidget);
  });

  testWidgets('узкий экран и крупный шрифт: ничего не переполняется',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);

    final json = sampleUserJson()..remove('image');
    (json['projects_users'] as List).add({
      'id': 99,
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2024-07-01T10:00:00.000Z',
      'cursus_ids': [21],
      'project': {
        'id': 99,
        'name': 'Очень длинное название проекта, которое обязано перенестись на несколько строк, а не вылезти за край экрана',
        'slug': 'long',
      },
    });
    await tester.pumpWidget(
      testApp(
        ProfileScreen(
          profile: UserProfile.fromJson(json),
          loadPhoto: (url) => Future.error(StateError('нет')),
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    // Содержимое прокручивается: до последнего проекта можно долистать.
    await tester.scrollUntilVisible(find.text('libft'), 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('без фото в заглушке инициалы имени', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('JD'), findsOneWidget); // Jane Doe
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('без имени инициал берётся из логина', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    expect(find.text('X'), findsOneWidget);
  });
}
