import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/cursus_progress.dart';
import 'package:swifty_companion/models/project_category.dart';
import 'package:swifty_companion/models/project_result.dart';
import 'package:swifty_companion/models/project_section.dart';
import 'package:swifty_companion/models/user_profile.dart';

void main() {
  CursusProgress cursus(
    int id,
    String? slug, {
    String? name,
    String? kind,
    DateTime? begin,
  }) =>
      CursusProgress(
        cursusId: id,
        slug: slug,
        name: name,
        kind: kind,
        level: 0,
        beginAt: begin,
      );

  ProjectResult project(String? slug, List<int> cursusIds) =>
      ProjectResult(slug: slug, cursusIds: cursusIds);

  // The cursuses of the student from the real dump (see the last group).
  final studentCursuses = [
    cursus(9, 'c-piscine', name: 'C Piscine'),
    cursus(21, '42cursus', name: '42cursus'),
    cursus(66, 'c-piscine-reloaded', name: 'C-Piscine-Reloaded'),
    cursus(
      68,
      'discovery-piscine-cybersecurity',
      name: 'Discovery Piscine - Cybersecurity',
    ),
  ];

  group('sectionOf: the cursus decides', () {
    test('cursus c-piscine -> Piscina, even if the slug says nothing', () {
      // By slug alone `shell-0-0` would be Outer Core.
      expect(
        sectionOf(project('shell-0-0', [9]), studentCursuses),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('cursus c-piscine-reloaded -> Piscina Reloaded', () {
      expect(
        sectionOf(project('whatever', [66]), studentCursuses),
        const KnownSection(ProjectCategory.piscineReloaded),
      );
    });

    test('the slug of a cursus is compared in any case', () {
      expect(
        sectionOf(project('x', [9]), [cursus(9, 'C-Piscine')]),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('another cursus -> its own section with the name from the API', () {
      final section = sectionOf(project('cellule0-0-tyto', [68]), studentCursuses);

      expect(section, isA<CursusSection>());
      final cursusSection = section as CursusSection;
      expect(cursusSection.cursusId, 68);
      expect(cursusSection.name, 'Discovery Piscine - Cybersecurity');
    });

    test('kind piscine: a piscine of another campus is Piscina', () {
      // c-piscine-brussels (id 64) has kind `piscine` but another slug.
      expect(
        sectionOf(
          project('x', [64]),
          [cursus(64, 'c-piscine-brussels', name: 'C Piscine Brussels', kind: 'piscine')],
        ),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('kind piscine_deprecated: an old piscine is Piscina', () {
      expect(
        sectionOf(
          project('piscine-c-day-00', [4]),
          [cursus(4, 'piscine-c', name: 'Piscine C', kind: 'piscine_deprecated')],
        ),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('the kind is compared in any case', () {
      expect(
        sectionOf(project('x', [4]), [cursus(4, 'a', kind: 'PISCINE')]),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('kind main with another slug (42.zip) is not 42cursus: own section', () {
      final section = sectionOf(
        project('x', [53]),
        [cursus(53, '42-zip', name: '42.zip', kind: 'main')],
      ) as CursusSection;
      expect(section.name, '42.zip');
    });

    test('other kinds are not piscines: Basecamp and Discovery get own sections', () {
      for (final kind in [
        'piscine_community',
        'professional_training',
        'external',
        'test',
      ]) {
        expect(
          sectionOf(
            project('x', [7]),
            [cursus(7, 'some-slug', name: 'Some', kind: kind)],
          ),
          isA<CursusSection>(),
          reason: kind,
        );
      }
    });

    test('kind external does not stop c-piscine-reloaded from being Reloaded', () {
      expect(
        sectionOf(
          project('x', [66]),
          [cursus(66, 'c-piscine-reloaded', kind: 'external')],
        ),
        const KnownSection(ProjectCategory.piscineReloaded),
      );
    });

    test('the second "reloaded" cursus (slug reloaded) gets its own section', () {
      final section = sectionOf(
        project('x', [28]),
        [cursus(28, 'reloaded', name: 'Reloaded', kind: 'external')],
      );
      expect(section, isA<CursusSection>());
    });

    test('without kind the slug c-piscine still works (fallback)', () {
      expect(
        sectionOf(project('x', [9]), [cursus(9, 'c-piscine')]),
        const KnownSection(ProjectCategory.piscine),
      );
    });

    test('a cursus without a name is named by its slug', () {
      final section = sectionOf(
        project('x', [5]),
        [cursus(5, 'some-new-piscine')],
      ) as CursusSection;
      expect(section.name, 'some-new-piscine');
    });
  });

  group('sectionOf: the slug decides when the cursus does not', () {
    test('only the main 42cursus: the slug rules (Common Core / Outer Core)', () {
      expect(
        sectionOf(project('42cursus-libft', [21]), studentCursuses),
        const KnownSection(ProjectCategory.commonCore),
      );
      expect(
        sectionOf(project('42cursus-ft_hangouts', [21]), studentCursuses),
        const KnownSection(ProjectCategory.outerCore),
      );
    });

    test('no cursus_ids at all: the slug rules', () {
      expect(
        sectionOf(project('libft', const []), studentCursuses),
        const KnownSection(ProjectCategory.commonCore),
      );
    });

    test('the student has no such cursus: the slug rules', () {
      // A known limitation: without the cursus in cursus_users there is
      // nothing to name the section after.
      expect(
        sectionOf(project('c-piscine-c-00', [9]), const []),
        const KnownSection(ProjectCategory.piscine),
      );
      expect(
        sectionOf(project('shell-0-0', [68]), const []),
        const KnownSection(ProjectCategory.outerCore),
      );
    });

    test('a cursus with neither name nor slug is skipped', () {
      expect(
        sectionOf(project('libft', [7]), [cursus(7, null)]),
        const KnownSection(ProjectCategory.commonCore),
      );
    });
  });

  group('sectionOf: several cursuses in one project', () {
    test('a cursus other than 42cursus wins over 42cursus', () {
      expect(
        sectionOf(project('libft', [21, 68]), studentCursuses),
        isA<CursusSection>(),
      );
      expect(
        sectionOf(project('libft', [68, 21]), studentCursuses),
        isA<CursusSection>(),
      );
    });

    test('unknown ids are skipped, the first suitable one is used', () {
      final section =
          sectionOf(project('x', [999, 68]), studentCursuses) as CursusSection;
      expect(section.cursusId, 68);
    });

    test('with two suitable cursuses, the first in cursus_ids order wins', () {
      expect(
        sectionOf(project('x', [66, 68]), studentCursuses),
        const KnownSection(ProjectCategory.piscineReloaded),
      );
      expect(
        sectionOf(project('x', [68, 66]), studentCursuses),
        isA<CursusSection>(),
      );
    });
  });

  group('equality of sections (they are keys of a Map)', () {
    test('known sections are equal if the category is the same', () {
      expect(
        const KnownSection(ProjectCategory.piscine),
        const KnownSection(ProjectCategory.piscine),
      );
      expect(
        const KnownSection(ProjectCategory.piscine),
        isNot(const KnownSection(ProjectCategory.commonCore)),
      );
    });

    test('cursus sections are equal if the cursus is the same', () {
      expect(
        const CursusSection(cursusId: 68, name: 'A'),
        const CursusSection(cursusId: 68, name: 'B'),
      );
      expect(
        const CursusSection(cursusId: 68, name: 'A'),
        isNot(const CursusSection(cursusId: 80, name: 'A')),
      );
    });

    test('a known section and a cursus section are never equal', () {
      expect(
        const KnownSection(ProjectCategory.piscine),
        isNot(const CursusSection(cursusId: 9, name: 'C Piscine')),
      );
    });

    test('equal sections are one key', () {
      final map = <ProjectSection, int>{
        const KnownSection(ProjectCategory.piscine): 1,
        const CursusSection(cursusId: 68, name: 'A'): 2,
      };
      expect(map[const KnownSection(ProjectCategory.piscine)], 1);
      expect(map[const CursusSection(cursusId: 68, name: 'other name')], 2);
      expect(map[const CursusSection(cursusId: 80, name: 'A')], isNull);
    });
  });

  group('orderCursusSections', () {
    const python = CursusSection(cursusId: 80, name: 'Python');
    const cyber = CursusSection(cursusId: 68, name: 'Cybersecurity');
    const alpha = CursusSection(cursusId: 1, name: 'Alpha');
    const beta = CursusSection(cursusId: 2, name: 'Beta');

    test('the oldest cursus first', () {
      final cursuses = [
        cursus(68, 'a', begin: DateTime.utc(2026, 6, 15)),
        cursus(80, 'b', begin: DateTime.utc(2026, 5, 18)),
      ];
      expect(orderCursusSections([cyber, python], cursuses), [python, cyber]);
    });

    test('a cursus without a date goes last', () {
      final cursuses = [
        cursus(68, 'a'),
        cursus(80, 'b', begin: DateTime.utc(2026, 5, 18)),
      ];
      expect(orderCursusSections([cyber, python], cursuses), [python, cyber]);
      expect(orderCursusSections([python, cyber], cursuses), [python, cyber]);
    });

    test('on a tie by date, by name', () {
      final day = DateTime.utc(2026, 1, 1);
      final cursuses = [
        cursus(1, 'a', begin: day),
        cursus(2, 'b', begin: day),
      ];
      expect(orderCursusSections([beta, alpha], cursuses), [alpha, beta]);
    });

    test('the argument is not changed', () {
      // Without dates the result is sorted by name: [cyber, python].
      final input = [python, cyber];
      final result = orderCursusSections(input, const []);

      expect(result, [cyber, python]);
      expect(input, [python, cyber]);
    });
  });

  group('a real student on the new Common Core (dump, no login)', () {
    // The records repeat the dump of a student who is in the middle of the new
    // Common Core and has never been in Outer Core. He also took two Discovery
    // Piscines. Before the cursus rule all 24 Discovery projects landed in
    // Outer Core.
    Map<String, dynamic> cursusUser(
      int id,
      String name,
      String slug,
      String kind,
      String begin,
    ) =>
        {
          'cursus_id': id,
          'level': 1.0,
          'begin_at': '${begin}T00:00:00.000Z',
          'cursus': {'id': id, 'name': name, 'slug': slug, 'kind': kind},
        };

    Map<String, dynamic> record(
      String slug,
      String name,
      int cursusId, {
      String status = 'finished',
      bool? validated = true,
      int? mark = 100,
    }) =>
        {
          'status': status,
          'validated?': validated,
          'final_mark': mark,
          'cursus_ids': [cursusId],
          'project': {'slug': slug, 'name': name},
        };

    String two(int i) => i.toString().padLeft(2, '0');

    UserProfile studentProfile() {
      final json = <String, dynamic>{
        'login': 'student',
        'cursus_users': [
          cursusUser(9, 'C Piscine', 'c-piscine', 'piscine', '2026-03-02'),
          cursusUser(21, '42cursus', '42cursus', 'main', '2026-04-13'),
          cursusUser(
            66,
            'C-Piscine-Reloaded',
            'c-piscine-reloaded',
            'external',
            '2026-04-13',
          ),
          cursusUser(
            68,
            'Discovery Piscine - Cybersecurity',
            'discovery-piscine-cybersecurity',
            'professional_training',
            '2026-06-15',
          ),
          cursusUser(
            80,
            'Discovery Piscine - Core Python Programming',
            'discovery-piscine-core-python-programming',
            'professional_training',
            '2026-05-18',
          ),
        ],
        'projects_users': [
          // 42cursus (21): the new Common Core, 22 completed + 1 in progress.
          record('42cursus-ft_printf', 'ft_printf', 21, mark: 125),
          record('42cursus-get_next_line', 'get_next_line', 21, mark: 125),
          record('42cursus-libft', 'Libft', 21),
          record('42next-born2beroot', 'Born2beroot', 21, mark: 125),
          record('42next-exam-rank-02', 'Exam Rank 02', 21),
          record('42next-exam-rank-03', 'Exam Rank 03', 21),
          record('42next-push_swap', 'push_swap', 21, mark: 125),
          record('a-maze-ing', 'A-Maze-ing', 21, mark: 125),
          record(
            'call-me-maybe',
            'Call Me Maybe',
            21,
            status: 'in_progress',
            validated: null,
            mark: null,
          ),
          record('codexion', 'Codexion', 21),
          record('exam-atonement', 'Exam atonement', 21),
          record('fly-in', 'Fly-in', 21, mark: 125),
          for (var i = 0; i <= 10; i++)
            record('python-module-${two(i)}', 'Python Module ${two(i)}', 21),
          // Discovery Piscine - Cybersecurity (68): 14 projects.
          for (var i = 0; i < 4; i++)
            record('cellule0-$i-tyto', 'Cellule0-$i-Tyto', 68),
          for (var i = 0; i < 4; i++)
            record('cellule1-$i-weasel', 'Cellule1-$i-weasel', 68),
          for (var i = 0; i < 4; i++)
            record('cellule2-$i-gecko', 'Cellule2-$i-gecko', 68),
          record('shell-0-0', 'Shell-0-0', 68),
          record('shell-0-1', 'Shell-0-1', 68),
          // Discovery Piscine - Core Python Programming (80): 10 projects.
          for (var i = 0; i < 10; i++)
            record(
              'disco-piscine-python-module-$i',
              'Disco Piscine - Python - Module $i',
              80,
            ),
          // C Piscine (9): 19 projects, including exams and failed rushes.
          for (var i = 0; i <= 9; i++)
            record('c-piscine-c-${two(i)}', 'C Piscine C ${two(i)}', 9),
          record('c-piscine-c-11', 'C Piscine C 11', 9, mark: 85),
          for (var i = 0; i <= 2; i++)
            record('c-piscine-exam-${two(i)}', 'C Piscine Exam ${two(i)}', 9),
          record('c-piscine-final-exam', 'C Piscine Final Exam', 9, mark: 66),
          record('c-piscine-rush-00', 'C Piscine Rush 00', 9,
              validated: false, mark: 0),
          record('c-piscine-rush-02', 'C Piscine Rush 02', 9,
              validated: false, mark: 0),
          record('c-piscine-shell-00', 'C Piscine Shell 00', 9),
          record('c-piscine-shell-01', 'C Piscine Shell 01', 9),
          // C Piscine Reloaded (66).
          record('c-piscine-reloaded', 'C-piscine-reloaded', 66),
        ],
      };
      return UserProfile.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
    }

    String label(ProjectSection section) => switch (section) {
          KnownSection(:final category) => category.name,
          CursusSection(:final name) => name,
        };

    test('sections and their order', () {
      final grouped = studentProfile().finishedProjectsBySection();

      expect(grouped.keys.map(label).toList(), [
        'outerCore',
        'commonCore',
        'piscine',
        'piscineReloaded',
        'Discovery Piscine - Core Python Programming',
        'Discovery Piscine - Cybersecurity',
      ]);
    });

    test('counts: nothing from the Discovery Piscines is in Outer Core', () {
      final grouped = studentProfile().finishedProjectsBySection();

      expect({for (final e in grouped.entries) label(e.key): e.value.length}, {
        'outerCore': 0,
        'commonCore': 22,
        'piscine': 19,
        'piscineReloaded': 1,
        'Discovery Piscine - Core Python Programming': 10,
        'Discovery Piscine - Cybersecurity': 14,
      });
    });

    test('a project in progress is in no section', () {
      final grouped = studentProfile().finishedProjectsBySection();
      final all = grouped.values.expand((list) => list).map((p) => p.name);

      expect(all, isNot(contains('Call Me Maybe')));
    });
  });
}
