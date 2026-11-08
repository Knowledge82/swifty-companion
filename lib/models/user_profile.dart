import '../core/json_reader.dart';
import 'cursus_progress.dart';
import 'project_category.dart';
import 'project_result.dart';

/// A student's profile: only what the app shows.
/// Service and sensitive fields of the response (`anonymize_date`,
/// `data_erasure_date`, etc.) are deliberately not parsed.
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

  /// Throws [FormatException] if the response has no `login`: without it this
  /// is not a profile but junk. Everything else is optional.
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
      // In the API the field is named in the singular.
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

  /// Whether the student is on campus now. The API has no separate "online"
  /// flag: `location` is the workstation the student is logged into (for
  /// example, `c1r2s3`), and `null` when they are not on campus. So online = a
  /// place exists. "Not on campus" cannot be told apart from "place hidden" by
  /// the response.
  bool get isOnline => location != null;
  final int? wallet;
  final int? correctionPoints;
  final String? poolMonth;
  final String? poolYear;

  /// Photo addresses in order of preference (no repeats, https only).
  /// There are several in case some version of the image is not served by the
  /// CDN: the screen tries them one by one.
  final List<String> imageUrls;

  /// The most preferred photo, or `null` if there are no suitable addresses.
  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  final List<CursusProgress> cursuses;
  final List<ProjectResult> projects;

  CursusProgress? get mainCursus => pickMainCursus(cursuses);

  /// Completed projects (passed and failed), newest first.
  /// With [cursusId] keeps only the projects of that cursus.
  /// Exams with a result count as completed even with status `in_progress`
  /// (see [ProjectResult.isCompleted]).
  List<ProjectResult> finishedProjects({int? cursusId}) {
    final result = projects
        .where(
          (p) =>
              p.isCompleted &&
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

  /// Completed projects by section (Outer Core, Common Core, Piscina). The map
  /// always has all three sections, in the order of [ProjectCategory.values];
  /// inside a section the order is the same as in [finishedProjects]: newest
  /// first.
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

/// How many photo addresses to keep: the main one and one spare. The spare is
/// needed in case the CDN does not serve the first version. The other versions
/// (`small`, `micro`) are not needed: on a large photo they would look like a
/// blurry mush, and a placeholder with initials is better. The extra addresses
/// are not loaded (the screen tries the next one only if the previous one
/// failed), but this way there is less chance of wasting the API request limit.
const int maxPhotoUrls = 2;

/// Photo: `medium`, `link`, `large` in this order, at most [maxPhotoUrls].
/// We take only https, because Android blocks http traffic by default.
/// Repeated addresses are dropped.
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
