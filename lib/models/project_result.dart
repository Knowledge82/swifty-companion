import '../core/json_reader.dart';

/// Итог проекта по полю `validated?`.
enum ProjectOutcome { passed, failed, unknown }

/// Запись о проекте студента (элемент `projects_users`).
class ProjectResult {
  const ProjectResult({
    this.id,
    required this.name,
    this.slug,
    this.status,
    this.validated,
    this.finalMark,
    this.date,
    this.cursusIds = const [],
  });

  factory ProjectResult.fromJson(Map<String, dynamic> json) {
    final project = readMap(json['project']);
    final slug = readString(project?['slug']);
    return ProjectResult(
      id: readInt(json['id']),
      name: readString(project?['name']) ?? slug ?? 'Без названия',
      slug: slug,
      status: readString(json['status']),
      // Ключ в JSON действительно называется «validated?» с вопросом.
      validated: readBool(json['validated?']),
      finalMark: readInt(json['final_mark']),
      date: readDate(json['marked_at']) ??
          readDate(json['updated_at']) ??
          readDate(json['created_at']),
      cursusIds:
          readList(json['cursus_ids']).map(readInt).whereType<int>().toList(),
    );
  }

  final int? id;
  final String name;
  final String? slug;

  /// Сырой статус: `finished`, `in_progress` и другие.
  final String? status;

  /// `true` сдан, `false` провален, `null` неизвестно.
  final bool? validated;
  final int? finalMark;

  /// Дата для сортировки: `marked_at`, иначе `updated_at`, иначе `created_at`.
  final DateTime? date;
  final List<int> cursusIds;

  /// «Завершён» определяем только по статусу (см. docs/03, раздел 8.3).
  bool get isFinished => status == 'finished';

  ProjectOutcome get outcome {
    if (validated == true) {
      return ProjectOutcome.passed;
    }
    if (validated == false) {
      return ProjectOutcome.failed;
    }
    return ProjectOutcome.unknown;
  }
}
