import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/login.dart';
import '../models/user_profile.dart';

/// Источник данных о студентах: превращает логин в [UserProfile].
/// Экраны общаются только с ним и ничего не знают про HTTP и JSON.
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  /// Загружает профиль по логину. Бросает [ApiException] (и только её).
  Future<UserProfile> fetchUser(String rawLogin) async {
    // Страховка на случай, если экран забыл проверить ввод. Такой логин
    // существовать не может, и сетевой запрос на него тратить незачем.
    if (validateLogin(rawLogin) != null) {
      throw const NotFoundException();
    }
    final login = normalizeLogin(rawLogin);

    final json = await _api.getJson(['v2', 'users', login]);
    try {
      return UserProfile.fromJson(json);
    } on FormatException {
      // Например, в ответе нет поля login.
      throw const UnexpectedResponseException();
    }
  }
}
