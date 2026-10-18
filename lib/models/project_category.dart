import 'project_result.dart';

/// Раздел, в который попадает завершённый проект на экране профиля.
/// Порядок значений = порядок показа на экране.
///
/// [piscineReloaded] это отдельный проект «C Piscine Reloaded»: он идёт после
/// Piscine и до Common Core и не входит ни в то, ни в другое, поэтому у него
/// свой раздел (пустой раздел на экране не показывается).
enum ProjectCategory { outerCore, commonCore, piscine, piscineReloaded }

/// Проекты Common Core (по slug, без префикса `42cursus-`).
///
/// Список составлен по программе школы и может не совпасть с реальными
/// slug в API: именно поэтому он вынесен в одну константу, чтобы
/// поправить его в одном месте (см. docs/12, раздел про проверку).
/// Серии `cpp-module-NN` и `exam-rank-NN` ловятся шаблонами ниже.
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
};

final RegExp _cppModule = RegExp(r'^cpp-module-\d{2}$');
final RegExp _examRank = RegExp(r'^exam-rank-\d{2}$');

/// Приводит slug к сравнимому виду: нижний регистр, без префикса `42cursus-`
/// (в API проекты основного курса бывают записаны и так, и так).
String normalizeSlug(String slug) {
  final lower = slug.trim().toLowerCase();
  const prefix = '42cursus-';
  return lower.startsWith(prefix) ? lower.substring(prefix.length) : lower;
}

/// В какой раздел попадает проект.
///
/// 1. slug содержит `piscine` и `reloaded` -> отдельный раздел Reloaded;
/// 2. slug начинается с `c-piscine` или `piscine` -> Piscina;
/// 3. slug в [commonCoreSlugs] или подходит под `cpp-module-NN`/`exam-rank-NN` -> Common Core;
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
      _examRank.hasMatch(slug)) {
    return ProjectCategory.commonCore;
  }
  return ProjectCategory.outerCore;
}
