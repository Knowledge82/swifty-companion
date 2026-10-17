import '../core/json_reader.dart';
import 'skill.dart';

/// Идентификатор основного курса в поле `cursus.slug`.
const String mainCursusSlug = '42cursus';

/// Прогресс студента в одном курсе (элемент `cursus_users`).
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

  /// Общий уровень курса, округлённый до двух знаков (12.44).
  final double level;
  final DateTime? beginAt;
  final DateTime? endAt;
  final List<Skill> skills;
}

/// Выбирает основной курс: сначала `42cursus` по slug, иначе курс с самым
/// высоким уровнем (например, у студента только бассейн). Пустой список даёт `null`.
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
