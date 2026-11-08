import '../core/json_reader.dart';
import 'skill.dart';

/// Identifier of the main cursus in the `cursus.slug` field.
const String mainCursusSlug = '42cursus';

/// A student's progress in one cursus (an element of `cursus_users`).
class CursusProgress {
  const CursusProgress({
    this.cursusId,
    this.name,
    this.slug,
    required this.level,
    this.beginAt,
    this.endAt,
    this.skills = const [],
  });

  factory CursusProgress.fromJson(Map<String, dynamic> json) {
    final cursus = readMap(json['cursus']);
    return CursusProgress(
      cursusId: readInt(json['cursus_id']) ?? readInt(cursus?['id']),
      name: readString(cursus?['name']),
      slug: readString(cursus?['slug']),
      level: roundLevel(readDouble(json['level']) ?? 0),
      beginAt: readDate(json['begin_at']),
      endAt: readDate(json['end_at']),
      skills: readObjects(json['skills'], Skill.fromJson),
    );
  }

  final int? cursusId;
  final String? name;
  final String? slug;

  /// Overall level of the cursus, rounded to two decimals (12.44).
  final double level;
  final DateTime? beginAt;
  final DateTime? endAt;
  final List<Skill> skills;
}

/// Picks the main cursus: first `42cursus` by slug, otherwise the cursus with
/// the highest level (for example, when the student has only the piscine).
/// An empty list gives `null`.
CursusProgress? pickMainCursus(List<CursusProgress> cursuses) {
  if (cursuses.isEmpty) {
    return null;
  }
  for (final cursus in cursuses) {
    if (cursus.slug == mainCursusSlug) {
      return cursus;
    }
  }
  return cursuses.reduce((best, next) => next.level > best.level ? next : best);
}
