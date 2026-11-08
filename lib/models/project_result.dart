import '../core/json_reader.dart';

/// Outcome of a project by the `validated?` field.
enum ProjectOutcome { passed, failed, unknown }

/// A record about a student's project (an element of `projects_users`).
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
      // The key in the JSON really is called "validated?", with a question
      // mark.
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
  /// Project name, otherwise the slug, otherwise `null` (the interface
  /// substitutes its own text).
  final String? name;
  final String? slug;

  /// Raw status: `finished`, `in_progress` and others.
  final String? status;

  /// `true` passed, `false` failed, `null` unknown.
  final bool? validated;
  final int? finalMark;

  /// Date for sorting: `marked_at`, otherwise `updated_at`, otherwise
  /// `created_at`.
  final DateTime? date;
  final List<int> cursusIds;

  /// Raw status `finished` (see docs/03, section 8.3).
  bool get isFinished => status == 'finished';

  /// This is an exam: the slug contains `exam` (`c-piscine-exam-00`,
  /// `c-piscine-final-exam`, `exam-rank-03`, `42next-exam-rank-02`). Every exam
  /// has its own status logic.
  bool get isExam => slug?.toLowerCase().contains('exam') ?? false;

  /// There is a result: both whether the project is passed and the mark are
  /// known.
  bool get hasResult => validated != null && finalMark != null;

  /// Whether the record counts as a "completed project".
  ///
  /// An ordinary project: only `status == finished`. An exam: also
  /// `in_progress` if it already has a result. In the API, piscine exams of
  /// students from the old intake stay `in_progress` forever (an exam can be
  /// retaken every week, so the record is never closed), although the mark and
  /// `validated?` are set in it. There is no such rule for ordinary projects:
  /// for a project in progress (including one being retaken) the previous mark
  /// must not look like a result.
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
