import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/models/project_category.dart';
import 'package:swifty_companion/models/project_result.dart';
import 'package:swifty_companion/models/user_profile.dart';

import 'fixtures.dart';

void main() {
  ProjectCategory of(String? slug) => categoryOf(ProjectResult(slug: slug));

  group('categoryOf', () {
    test('бассейн: slug начинается с c-piscine или piscine', () {
      for (final slug in [
        'c-piscine-shell-00',
        'c-piscine-c-05',
        'c-piscine-exam-00',
        'c-piscine-rush-00',
        'c-piscine-bsq',
        'piscine-c-00',
      ]) {
        expect(of(slug), ProjectCategory.piscine, reason: slug);
      }
    });

    test('Common Core: известные проекты', () {
      for (final slug in [
        'libft',
        'get_next_line',
        'ft_printf',
        'born2beroot',
        'push_swap',
        'so_long',
        'minitalk',
        'pipex',
        'fdf',
        'fract-ol',
        'philosophers',
        'minishell',
        'minirt',
        'cub3d',
        'netpractice',
        'ft_irc',
        'webserv',
        'inception',
      ]) {
        expect(of(slug), ProjectCategory.commonCore, reason: slug);
      }
    });

    test('Reloaded: отдельный раздел, не бассейн и не Common Core', () {
      expect(of('c-piscine-reloaded'), ProjectCategory.piscineReloaded);
      expect(of('42cursus-c-piscine-reloaded'), ProjectCategory.piscineReloaded);
      expect(of('C-Piscine-Reloaded'), ProjectCategory.piscineReloaded);
      // and the ordinary piscine is still a piscine
      expect(of('c-piscine-c-00'), ProjectCategory.piscine);
    });

    test('коллективное резюме относится к Common Core', () {
      expect(of('42_collaborative_resume'), ProjectCategory.commonCore);
    });

    test('Common Core: серии cpp-module и exam-rank', () {
      for (var i = 0; i <= 9; i++) {
        expect(of('cpp-module-0$i'), ProjectCategory.commonCore);
      }
      for (var i = 2; i <= 6; i++) {
        expect(of('exam-rank-0$i'), ProjectCategory.commonCore);
      }
    });

    test('префикс 42cursus- и регистр не мешают', () {
      expect(of('42cursus-libft'), ProjectCategory.commonCore);
      expect(of('42cursus-ft_printf'), ProjectCategory.commonCore);
      expect(of('42cursus-exam-rank-03'), ProjectCategory.commonCore);
      expect(of('LibFT'), ProjectCategory.commonCore);
      expect(of('  libft '), ProjectCategory.commonCore);
    });

    test('настоящие slug из интры (вывод скрипта проверки): разложены верно', () {
      // This is how they are recorded in the API for a real student: some with
      // the 42cursus- prefix, some without; the piscine and the "reload" with
      // cursus 66.
      const expected = {
        '42cursus-ft_printf': ProjectCategory.commonCore,
        '42cursus-get_next_line': ProjectCategory.commonCore,
        '42cursus-libft': ProjectCategory.commonCore,
        '42cursus-minishell': ProjectCategory.commonCore,
        '42cursus-philosophers': ProjectCategory.commonCore,
        '42cursus-push_swap': ProjectCategory.commonCore,
        'born2beroot': ProjectCategory.commonCore,
        'cub3d': ProjectCategory.commonCore,
        'ft_transcendence': ProjectCategory.commonCore,
        'inception': ProjectCategory.commonCore,
        'minitalk': ProjectCategory.commonCore,
        'netpractice': ProjectCategory.commonCore,
        'so_long': ProjectCategory.commonCore,
        'webserv': ProjectCategory.commonCore,
        '42_collaborative_resume': ProjectCategory.commonCore,
        '42cursus-ft_hangouts': ProjectCategory.outerCore,
        'c-piscine-c-00': ProjectCategory.piscine,
        'c-piscine-reloaded': ProjectCategory.piscineReloaded,
        'c-piscine-shell-01': ProjectCategory.piscine,
      };
      expected.forEach((slug, category) {
        expect(of(slug), category, reason: slug);
      });
    });

    test('новая программа Common Core: префикс 42next- и серии', () {
      // The same projects as in the old program, but with a different prefix.
      expect(of('42next-born2beroot'), ProjectCategory.commonCore);
      expect(of('42next-push_swap'), ProjectCategory.commonCore);
      expect(of('42NEXT-Push_Swap'), ProjectCategory.commonCore);
      for (var i = 2; i <= 6; i++) {
        expect(of('42next-exam-rank-0$i'), ProjectCategory.commonCore);
      }
      // Python modules: two digits, 00...10 (and a reserve for future numbers).
      for (var i = 0; i <= 10; i++) {
        final n = i.toString().padLeft(2, '0');
        expect(of('python-module-$n'), ProjectCategory.commonCore, reason: n);
      }
      // The prefix must not "glue together" different things.
      expect(of('42next-swifty-companion'), ProjectCategory.outerCore);
      expect(of('42next-libft-extra'), ProjectCategory.outerCore);
    });

    test('настоящие slug студента новой программы (выгрузка из API)', () {
      // The student has not reached Outer Core yet: none of his projects must
      // end up in that section. Piscine/Reloaded stay as they were.
      const commonCore = [
        '42cursus-ft_printf',
        '42cursus-get_next_line',
        '42cursus-libft',
        'inception',
        'netpractice',
        '42next-born2beroot',
        '42next-exam-rank-02',
        '42next-exam-rank-03',
        '42next-exam-rank-04',
        '42next-exam-rank-05',
        '42next-push_swap',
        'a-maze-ing',
        'agent-smith',
        'call-me-maybe',
        'codexion',
        'exam-atonement',
        'fly-in',
        'pac-man',
        'python-module-00',
        'python-module-01',
        'python-module-02',
        'python-module-03',
        'python-module-04',
        'python-module-05',
        'python-module-06',
        'python-module-07',
        'python-module-08',
        'python-module-09',
        'python-module-10',
        'rag-against-the-machine',
        'the-answer-protocol',
      ];
      for (final slug in commonCore) {
        expect(of(slug), ProjectCategory.commonCore, reason: slug);
      }
      expect(of('c-piscine-bsq'), ProjectCategory.piscine);
      expect(of('c-piscine-final-exam'), ProjectCategory.piscine);
      expect(of('c-piscine-reloaded'), ProjectCategory.piscineReloaded);
    });

    test('всё неизвестное, включая проект без slug, уходит в Outer Core', () {
      expect(of('swifty-companion'), ProjectCategory.outerCore);
      expect(of('mobile-0'), ProjectCategory.outerCore);
      expect(of('libft-extra'), ProjectCategory.outerCore); // does not match as a whole
      expect(of('cpp-module-0'), ProjectCategory.outerCore); // two digits are needed
      expect(of('python-module-1'), ProjectCategory.outerCore); // same here
      expect(of('python-module-00-extra'), ProjectCategory.outerCore);
      expect(of('agent-smith-2'), ProjectCategory.outerCore); // only as a whole
      expect(of(null), ProjectCategory.outerCore);
    });
  });

  group('finishedProjectsByCategory', () {
    test('все разделы всегда есть, в порядке показа', () {
      final grouped = const UserProfile(login: 'x').finishedProjectsByCategory();
      expect(grouped.keys.toList(), ProjectCategory.values);
      expect(grouped.values.every((list) => list.isEmpty), isTrue);
    });

    test('проекты разложены по разделам, внутри новые сверху', () {
      final grouped =
          UserProfile.fromJson(sampleUserJson()).finishedProjectsByCategory();

      expect(grouped[ProjectCategory.outerCore], isEmpty);
      expect(
        grouped[ProjectCategory.commonCore]!.map((p) => p.name),
        ['push_swap', 'ft_printf', 'libft'],
      );
      expect(
        grouped[ProjectCategory.piscine]!.map((p) => p.name),
        ['c-piscine-shell-00'],
      );
    });

    test('экзамены бассейна в статусе in_progress попадают в Piscina', () {
      // Real records of the old intake: status in_progress, but a result
      // exists.
      final json = sampleUserJson();
      (json['projects_users'] as List).addAll([
        {
          'status': 'in_progress',
          'validated?': false,
          'final_mark': 20,
          'marked_at': '2024-05-03T10:00:00.000Z',
          'cursus_ids': [9],
          'project': {'slug': 'c-piscine-exam-00', 'name': 'C Piscine Exam 00'},
        },
        {
          'status': 'in_progress',
          'validated?': true,
          'final_mark': 24,
          'marked_at': '2024-05-17T10:00:00.000Z',
          'cursus_ids': [9],
          'project': {'slug': 'c-piscine-final-exam', 'name': 'C Piscine Final Exam'},
        },
      ]);
      final grouped = UserProfile.fromJson(json).finishedProjectsByCategory();
      expect(
        grouped[ProjectCategory.piscine]!.map((p) => p.name),
        ['C Piscine Final Exam', 'C Piscine Exam 00', 'c-piscine-shell-00'],
      );
    });

    test('незавершённые проекты не попадают ни в один раздел', () {
      final grouped =
          UserProfile.fromJson(sampleUserJson()).finishedProjectsByCategory();
      final all = grouped.values.expand((list) => list).map((p) => p.name);
      expect(all, isNot(contains('minishell')));
    });
  });
}
