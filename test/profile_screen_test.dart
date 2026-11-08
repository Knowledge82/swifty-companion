import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/user_profile.dart';
import 'package:swifty_companion/ui/profile_avatar.dart';
import 'package:swifty_companion/ui/profile_screen.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';

import 'fixtures.dart';
import 'test_app.dart';

/// The WCAG contrast ratio (as in steampunk_test.dart).
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
          // The profiles in these tests have no photo, loading must not be
          // called.
          loadPhoto: (url) => Future.error(StateError('must not be called: $url')),
        ),
      ),
    );
  }

  /// Projects are collapsed by default: we expand a group with a tap on its
  /// header.
  Future<void> expandGroup(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the main profile fields', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('jdoe'), findsOneWidget); // title
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jdoe@example.com'), findsOneWidget);
    expect(find.text('3.00'), findsOneWidget); // 42cursus level
    expect(find.text('42'), findsOneWidget); // wallet
    expect(find.text('5'), findsOneWidget); // evaluation points
  });

  testWidgets('hidden and empty values are shown as N/A', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // Projects are collapsed, so only the phone ("hidden") is visible. The
    // place (null) is not N/A: it has no row, and whether the student is on
    // campus is told by the "Estado" row.
    expect(find.text('N/A'), findsNWidgets(1));

    // We expanded the group: a project outcome without a mark was added.
    await expandGroup(tester, 'Piscina · 1');
    expect(find.text('N/A'), findsNWidgets(2));
  });

  testWidgets('a minimal profile does not break the screen', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    // name, email, phone, level, wallet, points (no place: the row is hidden)
    expect(find.text('N/A'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  group('Status (lamp) and workstation', () {
    BoxDecoration lampOf(WidgetTester tester) => tester
        .widget<Container>(find.byKey(const ValueKey('online-lamp')))
        .decoration! as BoxDecoration;

    testWidgets('no place: grey lamp, "Fuera del campus", no place row',
        (tester) async {
      await pumpProfile(tester, sampleUserJson()..remove('image'));

      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Fuera del campus'), findsOneWidget);
      expect(find.text('En el campus'), findsNothing);
      expect(lampOf(tester).color, offlineGray);
      expect(lampOf(tester).boxShadow, isNull); // extinguished: no glow
      expect(find.text('Puesto'), findsNothing);
    });

    testWidgets('there is a place: green glowing lamp and the place below',
        (tester) async {
      final json = sampleUserJson()..remove('image');
      json['location'] = 'c1r2s3';
      await pumpProfile(tester, json);

      expect(find.text('En el campus'), findsOneWidget);
      expect(find.text('Fuera del campus'), findsNothing);
      expect(lampOf(tester).color, onlineGreen);
      expect(lampOf(tester).boxShadow, isNotEmpty); // glow
      expect(find.text('Puesto'), findsOneWidget);
      expect(find.text('c1r2s3'), findsOneWidget);

      // The place is below the "Estado" row.
      expect(
        tester.getTopLeft(find.text('c1r2s3')).dy,
        greaterThan(tester.getTopLeft(find.text('Estado')).dy),
      );
    });

    testWidgets('for screen readers the status is one phrase', (tester) async {
      final handle = tester.ensureSemantics();
      final json = sampleUserJson()..remove('image');
      json['location'] = 'c1r2s3';
      await pumpProfile(tester, json);

      expect(find.bySemanticsLabel('Estado: En el campus'), findsOneWidget);
      handle.dispose();
    });

    test('the lamp is distinguishable on the panel (at least 3:1 for icons)', () {
      expect(contrast(onlineGreen, walnut), greaterThanOrEqualTo(3));
      expect(contrast(offlineGray, walnut), greaterThanOrEqualTo(3));
    });
  });

  testWidgets('skills: level and percentage, strong ones on top', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('Rigor'), findsOneWidget);
    expect(find.text('9.63 · 48 %'), findsOneWidget); // 9.63 / 20
    expect(find.text('7.00 · 35 %'), findsOneWidget);
    expect(find.text('Sin nombre'), findsOneWidget); // a skill without a name
    expect(find.text('0.00 · 0 %'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rigor')).dy,
      lessThan(tester.getTopLeft(find.text('Web')).dy),
    );
    expect(find.textContaining('nivel ÷ 20'), findsOneWidget);
  });

  testWidgets('projects: passed and failed, by section, newest first',
      (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // Group headers with a counter; the empty Outer Core group is not shown.
    expect(find.text('Common Core · 3'), findsOneWidget);
    expect(find.text('Piscina · 1'), findsOneWidget);
    expect(find.textContaining('Outer Core'), findsNothing);

    await expandGroup(tester, 'Common Core · 3');
    await expandGroup(tester, 'Piscina · 1');

    expect(find.text('Aprobado · 2024-06-01'), findsOneWidget); // push_swap
    expect(find.text('Suspendido · 2024-05-01'), findsOneWidget); // ft_printf
    expect(find.text('Sin resultado · 2024-04-01'), findsOneWidget);
    expect(find.text('Aprobado · 2024-03-01'), findsOneWidget); // libft
    expect(find.text('minishell'), findsNothing); // not finished

    // Inside Common Core newest first, Piscina below.
    final y = [
      for (final name in ['push_swap', 'ft_printf', 'libft', 'c-piscine-shell-00'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(y, [...y]..sort());
  });

  testWidgets('section order: Outer Core, Common Core, Piscina, Reloaded',
      (tester) async {
    final json = sampleUserJson()..remove('image');
    (json['projects_users'] as List).add({
      'id': 50,
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2020-01-01T10:00:00.000Z', // the oldest: the order is not by date
      'cursus_ids': [21],
      'project': {'id': 50, 'name': 'Swifty Companion', 'slug': 'swifty-companion'},
    });
    (json['projects_users'] as List).add({
      'id': 51,
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2025-01-01T10:00:00.000Z', // the newest: the order is not by date
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

  testWidgets('no skills and no projects: clear messages', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    expect(find.text('Sin habilidades todavía'), findsOneWidget);
    expect(find.text('Aún no hay proyectos completados'), findsOneWidget);
  });

  testWidgets('English language: section titles', (tester) async {
    await tester.pumpWidget(
      testApp(
        ProfileScreen(
          profile: UserProfile.fromJson(sampleUserJson()..remove('image')),
          loadPhoto: (url) => Future.error(StateError('none')),
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

  testWidgets('narrow screen and large font: nothing overflows',
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
          loadPhoto: (url) => Future.error(StateError('none')),
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    // The content scrolls: we expand the groups and scroll down to the
    // projects.
    await expandGroup(tester, 'Outer Core · 1');
    await expandGroup(tester, 'Common Core · 3');
    await tester.scrollUntilVisible(find.text('libft'), 300);
    expect(find.textContaining('Очень длинное название'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the photo is large: 224 on a normal screen', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(224, 224));
  });

  testWidgets('on a narrow screen the photo shrinks and does not stick out', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.reset);

    await pumpProfile(tester, sampleUserJson()..remove('image'));

    // 280 - 2*24 (margins) = 232 of content width, minus 2*13 of the ring.
    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(206, 206));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a photo the placeholder shows the name initials', (tester) async {
    await pumpProfile(tester, sampleUserJson()..remove('image'));

    expect(find.text('JD'), findsOneWidget); // Jane Doe
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('without a name the initial comes from the login', (tester) async {
    await pumpProfile(tester, {'login': 'x'});

    expect(find.text('X'), findsOneWidget);
  });
}
