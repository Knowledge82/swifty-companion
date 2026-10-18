/// Допустимые символы логина 42. Это наше допущение: логины в интре
/// состоят из латинских букв, цифр и дефиса. Если окажется шире,
/// сервер всё равно ответит 404, а мы просто покажем «не найден».
final RegExp _loginPattern = RegExp(r'^[a-z0-9_-]+$');

/// Приводит ввод к виду, в котором логин уходит в запрос:
/// без пробелов по краям и в нижнем регистре.
String normalizeLogin(String raw) => raw.trim().toLowerCase();

/// Что не так с введённым логином. Тексты для пользователя здесь не хранятся:
/// их выбирает интерфейс по языку (`AppStrings.loginProblemText`).
enum LoginProblem { empty, invalidChars }

/// Возвращает проблему или `null`, если логин годится для запроса.
/// Проверка нужна, чтобы не тратить сетевой запрос на заведомый мусор
/// и не подставлять в адрес запроса произвольные символы (`/`, `?`, `..`).
LoginProblem? validateLogin(String raw) {
  final login = normalizeLogin(raw);
  if (login.isEmpty) {
    return LoginProblem.empty;
  }
  if (!_loginPattern.hasMatch(login)) {
    return LoginProblem.invalidChars;
  }
  return null;
}
