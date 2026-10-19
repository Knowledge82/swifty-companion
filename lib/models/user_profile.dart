import '../core/json_reader.dart';
import 'cursus_progress.dart';
import 'project_category.dart';
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
    this.imageUrls = const [],
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
      imageUrls: _pickImageUrls(readMap(json['image'])),
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

  /// В кампусе ли студент сейчас. API не даёт отдельного признака «онлайн»:
  /// `location` это рабочее место, за которым студент залогинен (например,
  /// `c1r2s3`), и `null`, когда его нет в кампусе. Поэтому онлайн = место есть.
  /// Отличить «нет в кампусе» от «место скрыто» по ответу нельзя.
  bool get isOnline => location != null;
  final int? wallet;
  final int? correctionPoints;
  final String? poolMonth;
  final String? poolYear;

  /// Адреса фото в порядке предпочтения (без повторов, только https).
  /// Их несколько на случай, если какая-то версия картинки на CDN не отдаётся:
  /// экран пробует их по очереди.
  final List<String> imageUrls;

  /// Самое предпочтительное фото или `null`, если подходящих адресов нет.
  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

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

  /// Завершённые проекты по разделам (Outer Core, Common Core, Piscina).
  /// В карте всегда все три раздела, в порядке [ProjectCategory.values];
  /// внутри раздела порядок тот же, что в [finishedProjects]: новые сверху.
  Map<ProjectCategory, List<ProjectResult>> finishedProjectsByCategory() {
    final grouped = <ProjectCategory, List<ProjectResult>>{
      for (final category in ProjectCategory.values) category: <ProjectResult>[],
    };
    for (final project in finishedProjects()) {
      grouped[categoryOf(project)]!.add(project);
    }
    return grouped;
  }
}

/// Сколько адресов фото хранить: основной и один запасной.
/// Запасной нужен на случай, если CDN не отдаёт первую версию. Остальные
/// версии (`small`, `micro`) не нужны: на крупном фото они выглядели бы
/// размытой кашей, а заглушка с инициалами лучше. Лишние адреса не грузятся
/// (экран пробует следующий, только если предыдущий не загрузился), но так
/// меньше шансов впустую потратить лимит запросов к API.
const int maxPhotoUrls = 2;

/// Фото: `medium`, `link`, `large` в таком порядке, не больше [maxPhotoUrls].
/// Берём только https, потому что Android по умолчанию блокирует http-трафик.
/// Повторяющиеся адреса отбрасываем.
List<String> _pickImageUrls(Map<String, dynamic>? image) {
  final versions = readMap(image?['versions']);
  final candidates = <Object?>[
    versions?['medium'],
    image?['link'],
    versions?['large'],
  ];
  final result = <String>[];
  for (final candidate in candidates) {
    final url = readString(candidate);
    if (url != null && url.startsWith('https://') && !result.contains(url)) {
      result.add(url);
      if (result.length == maxPhotoUrls) {
        break;
      }
    }
  }
  return result;
}
