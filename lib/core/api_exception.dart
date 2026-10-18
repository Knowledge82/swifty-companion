/// Все ошибки работы с API 42 в одном закрытом (sealed) семействе.
///
/// `sealed` значит: подклассы объявлены только в этом файле, поэтому
/// компилятор знает полный список и требует учесть каждый случай в `switch`.
/// Забыть обработать новый вид ошибки не получится.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Описание для разработчика (логи, отладка, тесты). Пользователю
  /// показывается не оно, а перевод из `AppStrings.errorText`: так язык
  /// ошибки совпадает с языком интерфейса.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Нет сети, DNS не отвечает или сервер не ответил за отведённое время.
final class NetworkException extends ApiException {
  const NetworkException()
      : isTimeout = false,
        super('Нет соединения с интернетом. Проверьте сеть и повторите.');

  const NetworkException.timeout()
      : isTimeout = true,
        super('Сервер не ответил вовремя. Повторите попытку позже.');

  /// `true`, если сеть есть, но сервер не ответил за отведённое время.
  /// Интерфейс по этому признаку выбирает текст.
  final bool isTimeout;
}

/// Приложение не смогло авторизоваться: неверные ключи или отклонённый токен.
final class AuthException extends ApiException {
  const AuthException()
      : super('Не удалось авторизоваться в API 42. Проверьте ключи в .env.');
}

/// Логин не найден (HTTP 404). Используется с этапа 4.
final class NotFoundException extends ApiException {
  const NotFoundException() : super('Пользователь с таким логином не найден.');
}

/// Превышен лимит запросов (HTTP 429).
final class RateLimitException extends ApiException {
  const RateLimitException({this.retryAfter})
      : super('Слишком много запросов. Подождите немного и повторите.');

  /// Сколько просит подождать сервер (заголовок `Retry-After`), если сказал.
  final Duration? retryAfter;
}

/// Сервер API недоступен или сломан (HTTP 5xx).
final class ServerException extends ApiException {
  const ServerException()
      : super('Сервер API 42 сейчас недоступен. Повторите позже.');
}

/// Ответ пришёл, но он не такой, как ожидалось: не JSON, нет нужных полей,
/// неожиданный код.
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException()
      : super('Получен неожиданный ответ от сервера.');
}
