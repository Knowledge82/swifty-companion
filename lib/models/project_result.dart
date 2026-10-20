import '../core/json_reader.dart';

/// Итог проекта по полю `validated?`.
enum ProjectOutcome { passed, failed, unknown }

/// Запись о проекте студента (элемент `projects_users`).
class ProjectResult {
  const ProjectResult({
    this.id,
    this.name,
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
      name: readString(project?['name']) ?? slug,
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
  /// Название проекта, иначе slug, иначе `null` (интерфейс подставит свой текст).
  final String? name;
  final String? slug;

  /// Сырой статус: `finished`, `in_progress` и другие.
  final String? status;

  /// `true` сдан, `false` провален, `null` неизвестно.
  final bool? validated;
  final int? finalMark;

  /// Дата для сортировки: `marked_at`, иначе `updated_at`, иначе `created_at`.
  final DateTime? date;
  final List<int> cursusIds;

  /// Сырой статус `finished` (см. docs/03, раздел 8.3).
  bool get isFinished => status == 'finished';

  /// Это экзамен: в slug есть `exam` (`c-piscine-exam-00`, `c-piscine-final-exam`,
  /// `exam-rank-03`, `42next-exam-rank-02`). У каждого экзамена своя логика статуса.
  bool get isExam => slug?.toLowerCase().contains('exam') ?? false;

  /// Есть итог: известно и сдан ли проект, и оценка.
  bool get hasResult => validated != null && finalMark != null;

  /// Попадает ли запись в «завершённые проекты».
  ///
  /// Обычный проект: только `status == finished`. Экзамен: ещё и `in_progress`,
  /// если у него уже есть итог. В API экзамены бассейна у студентов старого
  /// набора навсегда остаются `in_progress` (экзамен можно пересдавать каждую
  /// неделю, поэтому запись не закрывается), хотя оценка и `validated?` в ней
  /// стоят. Для обычных проектов такого правила нет: у проекта в процессе
  /// (в том числе на пересдаче) прошлая оценка не должна выглядеть итогом.
  bool get isCompleted => isFinished || (isExam && hasResult);

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
