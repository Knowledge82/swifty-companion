// The parent:

/// All errors of working with the 42 API in one closed (sealed) family.
///
/// `sealed` means: this is an abstract class, and its direct subclasses are
/// declared only in this file. The compiler knows the full list and requires
/// every case to be handled in a `switch`. Forgetting to handle a new kind of
/// error is impossible.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Description for the developer (logs, debugging, tests). The user is not
  /// shown this but the translation from `AppStrings.errorText`, so the
  /// language of the error matches the language of the interface.
  final String message;

  // `$` inserts a value into a string. `runtimeType` is the real type of the
  // object at run time, so the result is, for example,
  // `NetworkException: <message>`.
  @override
  String toString() => '$runtimeType: $message';
}

// The subclasses:

// 1. No network, DNS does not answer, or the server did not respond in time.

// `final class` means "I cannot be extended or implemented outside this file".
// This keeps the family closed, and nobody outside can add their own "network
// error".
final class NetworkException extends ApiException {
  const NetworkException()
      : isTimeout = false,
        super('Нет соединения с интернетом. Проверьте сеть и повторите.');

  const NetworkException.timeout()
      : isTimeout = true,
        super('Сервер не ответил вовремя. Повторите попытку позже.');

  /// `true` if the network is there but the server did not respond in time.
  /// The interface picks the text based on this flag.
  final bool isTimeout;
}

// 2. The app could not authorize: wrong keys or a rejected token.
final class AuthException extends ApiException {
  const AuthException()
      : super('Не удалось авторизоваться в API 42. Проверьте ключи в .env.');
}

// 3. Login not found (HTTP 404). Used since stage 4.
final class NotFoundException extends ApiException {
  const NotFoundException() : super('Пользователь с таким логином не найден.');
}

// 4. Rate limit exceeded (HTTP 429).
final class RateLimitException extends ApiException {
  const RateLimitException({this.retryAfter})
      : super('Слишком много запросов. Подождите немного и повторите.');

  /// How long the server asks us to wait (the `Retry-After` header), if it
  /// said.
  final Duration? retryAfter;
}

// 5. The API server is unavailable or broken (HTTP 5xx).
final class ServerException extends ApiException {
  const ServerException()
      : super('Сервер API 42 сейчас недоступен. Повторите позже.');
}

// 6. A response arrived, but not the one expected: not JSON, required fields
// missing, unexpected status code.
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException()
      : super('Получен неожиданный ответ от сервера.');
}
