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

    test('всё неизвестное, включая проект без slug, уходит в Outer Core', () {
      expect(of('swifty-companion'), ProjectCategory.outerCore);
      expect(of('mobile-0'), ProjectCategory.outerCore);
      expect(of('libft-extra'), ProjectCategory.outerCore); // не совпадает целиком
      expect(of('cpp-module-0'), ProjectCategory.outerCore); // нужно две цифры
      expect(of(null), ProjectCategory.outerCore);
    });
  });

  group('finishedProjectsByCategory', () {
    test('все три раздела всегда есть, в порядке показа', () {
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

    test('незавершённые проекты не попадают ни в один раздел', () {
      final grouped =
          UserProfile.fromJson(sampleUserJson()).finishedProjectsByCategory();
      final all = grouped.values.expand((list) => list).map((p) => p.name);
      expect(all, isNot(contains('minishell')));
    });
  });
}
