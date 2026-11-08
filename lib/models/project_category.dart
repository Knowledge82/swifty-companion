import 'project_result.dart';

/// The section a completed project goes into on the profile screen. The order
/// of the values = the order of display on the screen.
///
/// [piscineReloaded] is a separate project, "C Piscine Reloaded": it comes
/// after the Piscine and before Common Core and belongs to neither, so it has
/// its own section (an empty section is not shown on the screen).
enum ProjectCategory { outerCore, commonCore, piscine, piscineReloaded }

/// Slug prefixes that are dropped before comparing.
///
/// `42cursus-` for projects of the main cursus; `42next-` for projects of the
/// new Common Core program (for example `42next-born2beroot`,
/// `42next-push_swap`, `42next-exam-rank-02`). The list is also read by
/// `tool/dump_projects.py`, so every prefix must be a separate string literal
/// in single quotes.
const List<String> slugPrefixes = ['42cursus-', '42next-'];

/// Common Core projects (by slug, without the prefixes from [slugPrefixes]).
///
/// The list was compiled from the school program and from real API dumps and
/// may not match the real slugs: that is exactly why it is kept in one
/// constant, so it can be fixed in one place (see docs/12, sections 9 and 21).
/// The series `cpp-module-NN`, `exam-rank-NN` and `python-module-NN` are caught
/// by the patterns below.
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
  // Collective resume: on the same last circle as ft_transcendence.
  '42_collaborative_resume',
  // The new Common Core program (with Python modules). The list comes from the
  // profile dump of a student who has not reached Outer Core yet: he passed all
  // these projects inside Common Core. If it turns out that one of them is
  // really Outer Core, it is enough to remove it from here.
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

/// Brings a slug to a comparable form: lower case, without the prefix from
/// [slugPrefixes] (in the API projects appear both with and without the
/// prefix).
String normalizeSlug(String slug) {
  final lower = slug.trim().toLowerCase();
  for (final prefix in slugPrefixes) {
    if (lower.startsWith(prefix)) {
      return lower.substring(prefix.length);
    }
  }
  return lower;
}

/// Which section a project goes into.
///
/// 1. the slug contains `piscine` and `reloaded` -> the separate Reloaded
///    section;
/// 2. the slug starts with `c-piscine` or `piscine` -> Piscina;
/// 3. the slug is in [commonCoreSlugs] or matches
///    `cpp-module-NN`/`exam-rank-NN`/ `python-module-NN` -> Common Core;
/// 4. everything else (including a project without a slug) -> Outer Core.
///
/// Reloaded is checked before Piscina: its slug (`c-piscine-reloaded`) starts
/// the same way as the piscine's, and otherwise it would end up there.
///
/// This way a new, not yet known project lands in Outer Core by default instead
/// of getting lost.
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
