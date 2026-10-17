import '../core/json_reader.dart';
import 'cursus_progress.dart';
import 'project_result.dart';

/// Профиль студента: только то, что приложение показывает.
/// Служебные и чувствительные поля ответа (`anonymize_date`, `data_erasure_date`
/// и т. п.) сознательно не разбираются.
class UserProfile {
  const UserProfile({
    this.id,
    required this.login,
    this.displayName,
    this.email,
    this.phone,
    this.location,
    this.wallet,
    this.correctionPoints,
    this.poolMonth,
    this.poolYear,
    this.imageUrl,
    this.cursuses = const [],
    this.projects = const [],
  });

  /// Бросает [FormatException], если в ответе нет `login`: без него это
  /// не профиль, а мусор. Остальное необязательно.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final login = readString(json['login']);
    if (login == null) {
      throw const FormatException('В ответе API нет поля login');
    }
    return UserProfile(
      id: readInt(json['id']),
      login: login,
      displayName: readString(json['displayname']),
      email: readString(json['email']),
      phone: readString(json['phone']),
      location: readString(json['location']),
      wallet: readInt(json['wallet']),
      // В API поле называется в единственном числе.
      correctionPoints: readInt(json['correction_point']),
      poolMonth: readString(json['pool_month']),
      poolYear: readString(json['pool_year']),
      imageUrl: _pickImageUrl(readMap(json['image'])),
      cursuses: readObjects(json['cursus_users'], CursusProgress.fromJson),
      projects: readObjects(json['projects_users'], ProjectResult.fromJson),
    );
  }

  final int? id;
  final String login;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? location;
  final int? wallet;
  final int? correctionPoints;
  final String? poolMonth;
  final String? poolYear;
  final String? imageUrl;
  final List<CursusProgress> cursuses;
  final List<ProjectResult> projects;

  CursusProgress? get mainCursus => pickMainCursus(cursuses);

  /// Завершённые проекты (сданные и проваленные), новые сверху.
  /// С [cursusId] оставляет только проекты этого курса.
  List<ProjectResult> finishedProjects({int? cursusId}) {
    final result = projects
        .where(
          (p) =>
              p.isFinished &&
              (cursusId == null || p.cursusIds.contains(cursusId)),
        )
        .toList();
    result.sort((a, b) {
      final first = a.date;
      final second = b.date;
      if (first == null && second == null) {
        return 0;
      }
      if (first == null) {
        return 1;
      }
      if (second == null) {
        return -1;
      }
      return second.compareTo(first);
    });
    return result;
  }
}

/// Фото: `medium`, иначе `link`, иначе другие размеры. Берём только https,
/// потому что Android по умолчанию блокирует http-трафик.
String? _pickImageUrl(Map<String, dynamic>? image) {
  final versions = readMap(image?['versions']);
  final candidates = <Object?>[
    versions?['medium'],
    image?['link'],
    versions?['large'],
    versions?['small'],
    versions?['micro'],
  ];
  for (final candidate in candidates) {
    final url = readString(candidate);
    if (url != null && url.startsWith('https://')) {
      return url;
    }
  }
  return null;
}
