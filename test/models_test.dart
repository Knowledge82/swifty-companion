import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';
import 'package:swifty_companion/models/cursus_progress.dart';
import 'package:swifty_companion/models/project_result.dart';
import 'package:swifty_companion/models/skill.dart';
import 'package:swifty_companion/models/user_profile.dart';

import 'fixtures.dart';

void main() {
  group('skillPercent', () {
    test('считает долю от 20', () {
      expect(skillPercent(10), 50);
      expect(skillPercent(0), 0);
      expect(skillPercent(20), 100);
      expect(skillPercent(9.63), closeTo(48.15, 1e-9));
    });

    test('ограничена диапазоном 0..100', () {
      expect(skillPercent(25), 100);
      expect(skillPercent(-3), 0);
    });

    test('нулевой максимум не делит на ноль', () {
      expect(skillPercent(5, maxLevel: 0), 0);
    });
  });

  group('Skill.fromJson', () {
    test('убирает шум плавающей точки', () {
      final skill = Skill.fromJson({'id': 1, 'name': 'Unix', 'level': 3.4699999999999998});
      expect(skill.level, 3.47);
    });

    test('целый уровень становится double', () {
      expect(Skill.fromJson({'name': 'Web', 'level': 7}).level, 7.0);
    });

    test('нет названия и уровня — запасные значения', () {
      final skill = Skill.fromJson({'level': 'abc'});
      expect(skill.name, 'Без названия');
      expect(skill.level, 0);
    });

    test('процент берётся из функции skillPercent', () {
      final skill = Skill.fromJson({'name': 'Rigor', 'level': 9.63});
      expect(skill.percent, skillPercent(9.63));
    });
  });

  group('ProjectResult.fromJson', () {
    test('сданный и проваленный проекты', () {
      final json = sampleUserJson();
      final projects = UserProfile.fromJson(json).projects;
      final libft = projects.firstWhere((p) => p.name == 'libft');
      final printf = projects.firstWhere((p) => p.name == 'ft_printf');

      expect(libft.outcome, ProjectOutcome.passed);
      expect(libft.finalMark, 100);
      expect(printf.outcome, ProjectOutcome.failed);
      expect(printf.finalMark, 0);
    });

    test('без названия берётся slug, без итога — unknown и null', () {
      final project = ProjectResult.fromJson({
        'status': 'finished',
        'validated?': null,
        'final_mark': null,
        'project': {'slug': 'c-piscine-shell-00'},
      });
      expect(project.name, 'c-piscine-shell-00');
      expect(project.outcome, ProjectOutcome.unknown);
      expect(project.finalMark, isNull);
    });

    test('совсем пустая запись не падает', () {
      final project = ProjectResult.fromJson({});
      expect(project.name, 'Без названия');
      expect(project.isFinished, isFalse);
      expect(project.cursusIds, isEmpty);
    });

    test('дата: marked_at, иначе updated_at, иначе created_at', () {
      expect(
        ProjectResult.fromJson({
          'marked_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-02-01T00:00:00.000Z',
        }).date,
        DateTime.parse('2024-01-01T00:00:00.000Z'),
      );
      expect(
        ProjectResult.fromJson({'updated_at': '2024-02-01T00:00:00.000Z'}).date,
        DateTime.parse('2024-02-01T00:00:00.000Z'),
      );
      expect(
        ProjectResult.fromJson({'created_at': '2024-03-01T00:00:00.000Z'}).date,
        DateTime.parse('2024-03-01T00:00:00.000Z'),
      );
    });
  });

  group('pickMainCursus', () {
    CursusProgress make(String slug, double level) =>
        CursusProgress(slug: slug, level: level);

    test('пустой список — null', () {
      expect(pickMainCursus([]), isNull);
    });

    test('42cursus выбирается по slug, даже если уровень ниже', () {
      final main = pickMainCursus([make('c-piscine', 5), make('42cursus', 3)]);
      expect(main?.slug, '42cursus');
    });

    test('без 42cursus берётся курс с наибольшим уровнем', () {
      final main = pickMainCursus([make('a', 1), make('b', 5), make('c', 2)]);
      expect(main?.slug, 'b');
    });
  });

  group('UserProfile.fromJson', () {
    test('скрытый телефон становится null и показывается как N/A', () {
      final profile = UserProfile.fromJson(sampleUserJson());
      expect(profile.phone, isNull);
      expect(profile.phone.orNA, 'N/A');
      expect(profile.location, isNull);
    });

    test('обычные поля читаются', () {
      final profile = UserProfile.fromJson(sampleUserJson());
      expect(profile.login, 'jdoe');
      expect(profile.displayName, 'Jane Doe');
      expect(profile.email, 'jdoe@example.com');
      expect(profile.wallet, 42);
      expect(profile.correctionPoints, 5);
      expect(profile.poolMonth, 'september');
      expect(profile.poolYear, '2023');
    });

    test('без login — FormatException', () {
      expect(() => UserProfile.fromJson({}), throwsFormatException);
      expect(
        () => UserProfile.fromJson({'login': 'hidden'}),
        throwsFormatException,
      );
    });

    test('минимальный профиль (только login) не падает', () {
      final profile = UserProfile.fromJson({'login': 'x'});
      expect(profile.email, isNull);
      expect(profile.imageUrl, isNull);
      expect(profile.mainCursus, isNull);
      expect(profile.cursuses, isEmpty);
      expect(profile.finishedProjects(), isEmpty);
    });

    test('фото: medium, иначе link, иначе другие, http отвергается', () {
      expect(
        UserProfile.fromJson(sampleUserJson()).imageUrl,
        'https://example.com/medium.jpg',
      );
      expect(
        UserProfile.fromJson({
          'login': 'x',
          'image': {'link': 'https://example.com/link.jpg', 'versions': {}},
        }).imageUrl,
        'https://example.com/link.jpg',
      );
      expect(
        UserProfile.fromJson({
          'login': 'x',
          'image': {'link': 'http://example.com/insecure.jpg'},
        }).imageUrl,
        isNull,
      );
    });

    test('основной курс — 42cursus и его скиллы разобраны', () {
      final main = UserProfile.fromJson(sampleUserJson()).mainCursus;
      expect(main?.slug, '42cursus');
      expect(main?.cursusId, 21);
      expect(main?.skills.map((s) => s.name), ['Rigor', 'Web', 'Без названия']);
    });

    test('скилл с шумом в бассейне округлён', () {
      final profile = UserProfile.fromJson(sampleUserJson());
      final piscine = profile.cursuses.firstWhere((c) => c.slug == 'c-piscine');
      expect(piscine.skills.single.level, 3.47);
    });

    test('мусорный элемент в списке проектов пропущен', () {
      final profile = UserProfile.fromJson(sampleUserJson());
      expect(profile.projects.length, 5);
    });

    test('finishedProjects: только завершённые, включая проваленные, новые сверху', () {
      final names = UserProfile.fromJson(sampleUserJson())
          .finishedProjects()
          .map((p) => p.name)
          .toList();
      expect(names, ['push_swap', 'ft_printf', 'c-piscine-shell-00', 'libft']);
    });

    test('незавершённый проект не попадает в список, даже если validated? == true', () {
      final names = UserProfile.fromJson(sampleUserJson())
          .finishedProjects()
          .map((p) => p.name);
      expect(names, isNot(contains('minishell')));
    });

    test('finishedProjects с фильтром по курсу', () {
      final names = UserProfile.fromJson(sampleUserJson())
          .finishedProjects(cursusId: 21)
          .map((p) => p.name)
          .toList();
      expect(names, ['push_swap', 'ft_printf', 'libft']);
    });
  });
}
