import 'cursus_progress.dart';
import 'project_category.dart';
import 'project_result.dart';

/// Slug of the cursus "C Piscine" (the ordinary piscine).
///
/// The slugs of the cursuses are matched exactly, so each constant is a
/// separate string literal (`tool/dump_projects.py` reads them from here).
const String piscineCursusSlug = 'c-piscine';

/// Slug of the cursus "C Piscine Reloaded".
const String piscineReloadedCursusSlug = 'c-piscine-reloaded';

/// A group on the profile screen into which completed projects are put.
///
/// Two kinds:
/// - [KnownSection]: one of the four sections we know in advance (Outer Core,
///   Common Core, Piscina, Piscina Reloaded); its title is translated;
/// - [CursusSection]: a section of some other cursus (for example "Discovery
///   Piscine - Cybersecurity"); its title is the cursus name straight from the
///   API, because we cannot know such cursuses in advance.
///
/// The class is `sealed`: a `switch` over it must handle both kinds, so a new
/// kind of section cannot be forgotten in the interface.
sealed class ProjectSection {
  const ProjectSection();
}

/// One of the four known sections, see [ProjectCategory].
final class KnownSection extends ProjectSection {
  const KnownSection(this.category);

  final ProjectCategory category;

  // `==` and `hashCode` are needed because sections are keys of a `Map` and
  // members of a `Set`: without them two equal sections would be different
  // keys.
  @override
  bool operator ==(Object other) =>
      other is KnownSection && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

/// A section built from a cursus that has no section of its own in
/// [ProjectCategory]. Two sections are equal if the cursus is the same.
final class CursusSection extends ProjectSection {
  const CursusSection({required this.cursusId, required this.name});

  final int cursusId;

  /// The name of the cursus as the API gives it.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CursusSection && other.cursusId == cursusId;

  @override
  int get hashCode => cursusId.hashCode;
}

/// Which section a project goes into: **first by cursus, then by slug**.
///
/// 1. The project has a cursus (from `cursus_ids`) that the student really
///    has (`cursus_users`) and that is not the main `42cursus`: then the cursus
///    decides.
///    - `c-piscine` -> Piscina;
///    - `c-piscine-reloaded` -> Piscina Reloaded;
///    - any other cursus (Discovery Piscines, future piscines of Outer Core)
///      -> a [CursusSection] with the name of the cursus.
/// 2. Otherwise (the project is only in `42cursus`, or nothing is known about
///    its cursus) the slug rules of [categoryOf] decide. They are the only way
///    to tell Common Core from Outer Core: both live in the same `42cursus`.
///
/// If a project belongs to several cursuses, the first suitable one in the
/// order of `cursus_ids` wins. A cursus without both a name and a slug cannot
/// be shown, so it is skipped.
ProjectSection sectionOf(ProjectResult project, List<CursusProgress> cursuses) {
  for (final id in project.cursusIds) {
    final cursus = _findCursus(cursuses, id);
    if (cursus == null) {
      continue;
    }
    final slug = cursus.slug?.toLowerCase();
    if (slug == mainCursusSlug) {
      continue;
    }
    if (slug == piscineCursusSlug) {
      return const KnownSection(ProjectCategory.piscine);
    }
    if (slug == piscineReloadedCursusSlug) {
      return const KnownSection(ProjectCategory.piscineReloaded);
    }
    final name = cursus.name ?? cursus.slug;
    if (name != null) {
      return CursusSection(cursusId: id, name: name);
    }
  }
  return KnownSection(categoryOf(project));
}

CursusProgress? _findCursus(List<CursusProgress> cursuses, int id) {
  for (final cursus in cursuses) {
    if (cursus.cursusId == id) {
      return cursus;
    }
  }
  return null;
}

/// Orders the cursus sections for display: by the date the student started the
/// cursus (the oldest first); a cursus without a date goes last; on a tie, by
/// name. Returns a new list, the argument is not changed.
List<CursusSection> orderCursusSections(
  Iterable<CursusSection> sections,
  List<CursusProgress> cursuses,
) {
  DateTime? beginOf(CursusSection section) =>
      _findCursus(cursuses, section.cursusId)?.beginAt;

  final result = sections.toList();
  result.sort((a, b) {
    final first = beginOf(a);
    final second = beginOf(b);
    if (first != null && second != null) {
      final byDate = first.compareTo(second);
      if (byDate != 0) {
        return byDate;
      }
    } else if (first != null) {
      return -1;
    } else if (second != null) {
      return 1;
    }
    return a.name.compareTo(b.name);
  });
  return result;
}
