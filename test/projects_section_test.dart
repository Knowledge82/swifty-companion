import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
            child: ProjectsSection(groups: profile.finishedProjectsBySection()),
          ),
        ),
      ),
    );
  }

  testWidgets('by default all groups are collapsed: only the headers are visible',
      (tester) async {
    await pumpSection(tester);

    expect(find.text('Common Core · 3'), findsOneWidget);
    expect(find.text('Piscina · 1'), findsOneWidget);
    for (final name in ['push_swap', 'ft_printf', 'libft', 'c-piscine-shell-00']) {
      expect(find.text(name), findsNothing, reason: name);
    }
  });

  testWidgets('the section title has the oxide color', (tester) async {
    await pumpSection(tester);

    final title = tester.widget<Text>(find.text('Proyectos completados'));
    expect(title.style?.color, sectionTitleColor);
    // Not the "pure" oxide: on the light panel it lacked contrast (docs/12
    // §22).
    expect(sectionTitleColor, isNot(oxide));
  });

  testWidgets('a tap on the header expands the group, another one collapses it',
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

  testWidgets('groups expand independently of each other', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Piscina · 1'));
    await tester.pumpAndSettle();

    expect(find.text('c-piscine-shell-00'), findsOneWidget);
    expect(find.text('push_swap'), findsNothing); // Common Core stayed collapsed
  });

  testWidgets('failed projects are visible after expanding', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();

    expect(find.text('ft_printf'), findsOneWidget);
    expect(find.text('Suspendido · 2024-05-01'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('the arrow rotates on expanding', (tester) async {
    await pumpSection(tester);

    double turns() => tester
        .widget<AnimatedRotation>(find.byType(AnimatedRotation).first)
        .turns;

    expect(turns(), 0);
    await tester.tap(find.text('Common Core · 3'));
    await tester.pumpAndSettle();
    expect(turns(), 0.5);
  });

  testWidgets('a group header is at least 48 pixels tall: easy to hit with a finger',
      (tester) async {
    await pumpSection(tester);

    final inkWell = find.ancestor(
      of: find.text('Common Core · 3'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(48));
  });

  testWidgets(
      'a section of another cursus: its title is the cursus name from the API, '
      'after the known sections', (tester) async {
    final json = sampleUserJson()..remove('image');
    (json['cursus_users'] as List).add({
      'cursus_id': 68,
      'level': 7.77,
      'begin_at': '2026-06-15T00:00:00.000Z',
      'cursus': {
        'id': 68,
        'name': 'Discovery Piscine - Cybersecurity',
        'slug': 'discovery-piscine-cybersecurity',
      },
    });
    (json['projects_users'] as List).add({
      'status': 'finished',
      'validated?': true,
      'final_mark': 100,
      'marked_at': '2026-06-16T10:00:00.000Z',
      'cursus_ids': [68],
      'project': {'slug': 'shell-0-0', 'name': 'Shell-0-0'},
    });
    final profile = UserProfile.fromJson(json);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProjectsSection(groups: profile.finishedProjectsBySection()),
          ),
        ),
      ),
    );

    final discovery = find.text('Discovery Piscine - Cybersecurity · 1');
    expect(discovery, findsOneWidget);
    // Collapsed like the others, and below the known sections.
    expect(find.text('Shell-0-0'), findsNothing);
    expect(
      tester.getTopLeft(discovery).dy,
      greaterThan(tester.getTopLeft(find.text('Piscina · 1')).dy),
    );

    await tester.tap(discovery);
    await tester.pumpAndSettle();
    expect(find.text('Shell-0-0'), findsOneWidget);
  });

  testWidgets('no projects: a message, no group headers', (tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: ProjectsSection(groups: {}))),
    );

    expect(find.text('Aún no hay proyectos completados'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('large font on a narrow screen: the header does not overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);

    final profile = UserProfile.fromJson(sampleUserJson()..remove('image'));
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ProjectsSection(groups: profile.finishedProjectsBySection()),
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
