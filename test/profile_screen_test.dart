import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/profile_avatar.dart';
import 'package:swifty_companion/ui/profile_screen.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';

import 'fixtures.dart';
import 'test_app.dart';

/// Коэффициент контрастности WCAG (как в steampunk_test.dart).
double contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

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

  /// Проекты по умолчанию свёрнуты: раскрываем группу касанием на заголовок.
  Future<void> expandGroup(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
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

    // Проекты свёрнуты, поэтому виден только телефон ("hidden"). Место (null)
    // не N/A: его строки нет, а в кампусе ли студент, говорит строка «Estado».
    expect(find.text('N/A'), findsNWidgets(1));

    // Раскрыли группу: добавился итог проекта без оценки.
    await expandGroup(tester, 'Piscina · 1');
    expect(find.text('N/A'), findsNWidgets(2));
  });

  testWidgets('минимальный профиль не ломает экран', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    // имя, email, телефон, уровень, кошелёк, очки (места нет: строка скрыта)
    expect(find.text('N/A'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  group('Статус (лампочка) и рабочее место', () {
    BoxDecoration lampOf(WidgetTester tester) => tester
        .widget<Container>(find.byKey(const ValueKey('online-lamp')))
        .decoration! as BoxDecoration;

    testWidgets('нет места: серая лампочка, «Fuera del campus», строки места нет',
        (tester) async {
      await pumpProfile(tester, sampleUserJson()..remove('image'));

      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Fuera del campus'), findsOneWidget);
      expect(find.text('En el campus'), findsNothing);
      expect(lampOf(tester).color, offlineGray);
      expect(lampOf(tester).boxShadow, isNull); // погашена: свечения нет
      expect(find.text('Puesto'), findsNothing);
    });

    testWidgets('есть место: зелёная светящаяся лампочка и само место ниже',
        (tester) async {
      final json = sampleUserJson()..remove('image');
      json['location'] = 'c1r2s3';
      await pumpProfile(tester, json);

      expect(find.text('En el campus'), findsOneWidget);
      expect(find.text('Fuera del campus'), findsNothing);
      expect(lampOf(tester).color, onlineGreen);
      expect(lampOf(tester).boxShadow, isNotEmpty); // свечение
      expect(find.text('Puesto'), findsOneWidget);
      expect(find.text('c1r2s3'), findsOneWidget);

      // Место ниже строки «Estado».
      expect(
        tester.getTopLeft(find.text('c1r2s3')).dy,
        greaterThan(tester.getTopLeft(find.text('Estado')).dy),
      );
    });

    testWidgets('для чтения с экрана статус одной фразой', (tester) async {
      final handle = tester.ensureSemantics();
      final json = sampleUserJson()..remove('image');
      json['location'] = 'c1r2s3';
      await pumpProfile(tester, json);

      expect(find.bySemanticsLabel('Estado: En el campus'), findsOneWidget);
      handle.dispose();
    });

    test('лампочка различима на панели (не ниже 3:1 для значков)', () {
      expect(contrast(onlineGreen, walnut), greaterThanOrEqualTo(3));
      expect(contrast(offlineGray, walnut), greaterThanOrEqualTo(3));
    });
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

  testWidgets('проекты: сданные и проваленные, по разделам, новые сверху',
      (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // Заголовки групп со счётчиком; пустая группа Outer Core не показывается.
    expect(find.text('Common Core · 3'), findsOneWidget);
    expect(find.text('Piscina · 1'), findsOneWidget);
    expect(find.textContaining('Outer Core'), findsNothing);

    await expandGroup(tester, 'Common Core · 3');
    await expandGroup(tester, 'Piscina · 1');

    expect(find.text('Aprobado · 2024-06-01'), findsOneWidget); // push_swap
    expect(find.text('Suspendido · 2024-05-01'), findsOneWidget); // ft_printf
    expect(find.text('Sin resultado · 2024-04-01'), findsOneWidget);
    expect(find.text('Aprobado · 2024-03-01'), findsOneWidget); // libft
    expect(find.text('minishell'), findsNothing); // не завершён

    // Внутри Common Core новые сверху, Piscina ниже.
    final y = [
      for (final name in ['push_swap', 'ft_printf', 'libft', 'c-piscine-shell-00'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(y, [...y]..sort());
  });

  testWidgets('порядок разделов: Outer Core, Common Core, Piscina, Reloaded',
      (tester) async {
    final json = sampleUserJson()..remove('image');
    (json['projects_users'] as List).add({
      'id': 50,
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2020-01-01T10:00:00.000Z', // самый старый: порядок не от даты
      'cursus_ids': [21],
      'project': {'id': 50, 'name': 'Swifty Companion', 'slug': 'swifty-companion'},
    });
    (json['projects_users'] as List).add({
      'id': 51,
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2025-01-01T10:00:00.000Z', // самый новый: порядок не от даты
      'cursus_ids': [66],
      'project': {'id': 51, 'name': 'C-piscine-reloaded', 'slug': 'c-piscine-reloaded'},
    });
    await pumpProfile(tester, json);

    expect(find.text('Outer Core · 1'), findsOneWidget);
    expect(find.text('Piscina Reloaded · 1'), findsOneWidget);
    final y = [
      for (final title in [
        'Outer Core · 1',
        'Common Core · 3',
        'Piscina · 1',
        'Piscina Reloaded · 1',
      ])
        tester.getTopLeft(find.text(title)).dy,
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
    expect(find.text('Common Core · 3'), findsOneWidget);
    await expandGroup(tester, 'Common Core · 3');
    expect(find.text('Passed · 2024-06-01'), findsOneWidget);
    expect(find.text('Piscine · 1'), findsOneWidget);
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
    // Содержимое прокручивается: раскрываем группы и долистываем до проектов.
    await expandGroup(tester, 'Outer Core · 1');
    await expandGroup(tester, 'Common Core · 3');
    await tester.scrollUntilVisible(find.text('libft'), 300);
    expect(find.textContaining('Очень длинное название'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('фото крупное: 224 на обычном экране', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(224, 224));
  });

  testWidgets('на узком экране фото уменьшается и не вылезает', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.reset);

    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // 280 - 2*24 (поля) = 232 ширины содержимого, минус 2*13 кольца.
    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(206, 206));
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
