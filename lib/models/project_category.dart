import 'project_result.dart';

/// Раздел, в который попадает завершённый проект на экране профиля.
/// Порядок значений = порядок показа на экране.
///
/// [piscineReloaded] это отдельный проект «C Piscine Reloaded»: он идёт после
/// Piscine и до Common Core и не входит ни в то, ни в другое, поэтому у него
/// свой раздел (пустой раздел на экране не показывается).
enum ProjectCategory { outerCore, commonCore, piscine, piscineReloaded }

/// Префиксы slug, которые отбрасываются перед сравнением.
///
/// `42cursus-` у проектов основного курса; `42next-` у проектов новой
/// программы Common Core (например `42next-born2beroot`, `42next-push_swap`,
/// `42next-exam-rank-02`). Список читает и `tool/dump_projects.py`, поэтому
/// каждый префикс должен быть отдельным строковым литералом в одинарных кавычках.
const List<String> slugPrefixes = ['42cursus-', '42next-'];

/// Проекты Common Core (по slug, без префиксов из [slugPrefixes]).
///
/// Список составлен по программе школы и по реальным выгрузкам из API
/// и может не совпасть с реальными slug: именно поэтому он вынесен в одну
/// константу, чтобы поправить его в одном месте (см. docs/12, разделы 9 и 21).
/// Серии `cpp-module-NN`, `exam-rank-NN` и `python-module-NN` ловятся
/// шаблонами ниже.
const Set<String> commonCoreSlugs = {
  'libft',
  'get_next_line',
  'ft_printf',
  'born2beroot',
  'netwhat',
  'push_swap',
  'so_long',
  'minitalk',
  'pipex',
  'fdf',
  'fract-ol',
  'fractol',
  'philosophers',
  'minishell',
  'minirt',
  'cub3d',
  'netpractice',
  'ft_irc',
  'webserv',
  'inception',
  'ft_containers',
  'ft_transcendence',
  // Коллективное резюме: на том же последнем круге, что и ft_transcendence.
  '42_collaborative_resume',
  // Новая программа Common Core (с модулями Python). Список по выгрузке
  // профиля студента, который ещё не дошёл до Outer Core: все эти проекты
  // он прошёл внутри Common Core. Если у кого-то окажется, что один из них
  // на самом деле Outer Core, достаточно убрать его отсюда.
  'a-maze-ing',
  'agent-smith',
  'call-me-maybe',
  'codexion',
  'exam-atonement',
  'fly-in',
  'pac-man',
  'rag-against-the-machine',
  'the-answer-protocol',
};

final RegExp _cppModule = RegExp(r'^cpp-module-\d{2}$');
final RegExp _examRank = RegExp(r'^exam-rank-\d{2}$');
final RegExp _pythonModule = RegExp(r'^python-module-\d{2}$');

/// Приводит slug к сравнимому виду: нижний регистр, без префикса из
/// [slugPrefixes] (в API проекты бывают записаны и с префиксом, и без).
String normalizeSlug(String slug) {
  final lower = slug.trim().toLowerCase();
  for (final prefix in slugPrefixes) {
    if (lower.startsWith(prefix)) {
      return lower.substring(prefix.length);
    }
  }
  return lower;
}

/// В какой раздел попадает проект.
///
/// 1. slug содержит `piscine` и `reloaded` -> отдельный раздел Reloaded;
/// 2. slug начинается с `c-piscine` или `piscine` -> Piscina;
/// 3. slug в [commonCoreSlugs] или подходит под `cpp-module-NN`/`exam-rank-NN`/
///    `python-module-NN` -> Common Core;
/// 4. всё остальное (включая проект без slug) -> Outer Core.
///
/// Reloaded проверяется раньше Piscina: его slug (`c-piscine-reloaded`)
/// начинается так же, как у бассейна, и иначе он попал бы туда.
///
/// Так новый, ещё не известный проект по умолчанию окажется в Outer Core,
/// а не потеряется.
ProjectCategory categoryOf(ProjectResult project) {
  final raw = project.slug;
  if (raw == null) {
    return ProjectCategory.outerCore;
  }
  final slug = normalizeSlug(raw);
  if (slug.contains('piscine') && slug.contains('reloaded')) {
    return ProjectCategory.piscineReloaded;
  }
  if (slug.startsWith('c-piscine') || slug.startsWith('piscine')) {
    return ProjectCategory.piscine;
  }
  if (commonCoreSlugs.contains(slug) ||
      _cppModule.hasMatch(slug) ||
      _examRank.hasMatch(slug) ||
      _pythonModule.hasMatch(slug)) {
    return ProjectCategory.commonCore;
  }
  return ProjectCategory.outerCore;
}
