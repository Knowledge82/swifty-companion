import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/projects_section.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';

import 'fixtures.dart';
import 'test_app.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester) {
    final profile = UserProfile.fromJson(sampleUserJson()..remove('image'));
    return tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProjectsSection(groups: profile.finishedProjectsByCategory()),
          ),
        ),
      ),
    );
  }

  testWidgets('по умолчанию все группы свёрнуты: видны только заголовки',
      (tester) async {
    await pumpSection(tester);

    expect(find.text('Common Core · 3'), findsOneWidget);
    expect(find.text('Piscina · 1'), findsOneWidget);
    for (final name in ['push_swap', 'ft_printf', 'libft', 'c-piscine-shell-00']) {
      expect(find.text(name), findsNothing, reason: name);
    }
  });

  testWidgets('название раздела цвета окиси', (tester) async {
    await pumpSection(tester);

    final title = tester.widget<Text>(find.text('Proyectos completados'));
    expect(title.style?.color, sectionTitleColor);
    expect(sectionTitleColor, oxide);
  });

  testWidgets('тап по заголовку раскрывает группу, повторный сворачивает',
      (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();
    expect(find.text('push_swap'), findsOneWidget);
    expect(find.text('libft'), findsOneWidget);

    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();
    expect(find.text('push_swap'), findsNothing);
    expect(find.text('libft'), findsNothing);
  });

  testWidgets('группы раскрываются независимо друг от друга', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Piscina · 1'));
    await tester.pumpAndSettle();

    expect(find.text('c-piscine-shell-00'), findsOneWidget);
    expect(find.text('push_swap'), findsNothing); // Common Core остался свёрнут
  });

  testWidgets('проваленные проекты видны после раскрытия', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();

    expect(find.text('ft_printf'), findsOneWidget);
    expect(find.text('Suspendido · 2024-05-01'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('стрелка поворачивается при раскрытии', (tester) async {
    await pumpSection(tester);

    double turns() => tester
        .widget<AnimatedRotation>(find.byType(AnimatedRotation).first)
        .turns;

    expect(turns(), 0);
    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();
    expect(turns(), 0.5);
  });

  testWidgets('заголовок группы не ниже 48 пикселей: удобно попасть пальцем',
      (tester) async {
    await pumpSection(tester);

    final inkWell = find.ancestor(
      of: find.text('Common Core · 3'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(48));
  });

  testWidgets('без проектов: сообщение, заголовков групп нет', (tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: ProjectsSection(groups: {}))),
    );

    expect(find.text('Aún no hay proyectos completados'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('крупный шрифт на узком экране: заголовок не переполняется',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);

    final profile = UserProfile.fromJson(sampleUserJson()..remove('image'));
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProjectsSection(groups: profile.finishedProjectsByCategory()),
          ),
        ),
        textScale: 2,
      ),
    );
    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
