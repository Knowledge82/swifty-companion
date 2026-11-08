import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/api_exception.dart';
import '../core/login.dart';
import '../models/user_profile.dart';

/// Source of student data: turns a login into a [UserProfile].
/// Screens talk only to it and know nothing about HTTP and JSON.
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  /// Loads a profile by login. Throws [ApiException] (and only it).
  Future<UserProfile> fetchUser(String rawLogin) async {
    // A safety net in case the screen forgot to check the input. Such a login
    // cannot exist, and there is no point in spending a network request on it.
    if (validateLogin(rawLogin) != null) {
      throw const NotFoundException();
    }
    final login = normalizeLogin(rawLogin);

    final json = await _api.getJson([apiVersion, 'users', login]);
    try {
      return UserProfile.fromJson(json);
    } on FormatException {
      // For example, the response has no `login` field.
      throw const UnexpectedResponseException();
    }
  }
}
