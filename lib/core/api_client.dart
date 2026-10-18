import 'package:http/http.dart' as http;

import 'api_constants.dart';
import 'api_exception.dart';
import 'http_helpers.dart';
import 'token_service.dart';

/// HTTP-клиент для API 42: подставляет токен, повторяет запрос после 401
/// и переводит коды ответа в [ApiException].
///
/// Знает только про «адрес → JSON-объект». Что за JSON и во что его превращать,
/// решает слой выше (репозиторий).
class ApiClient {
  ApiClient({
    required this._tokenService,
    http.Client? client,
    this._requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final TokenService _tokenService;
  final http.Client _client;
  final Duration _requestTimeout;

  /// GET `https://api.intra.42.fr/<segments>` с токеном. Возвращает JSON-объект.
  ///
  /// Части пути передаются **списком**: `Uri` сам кодирует каждую часть
  /// (пробел, `?`, `/` внутри части не изменят структуру адреса).
  Future<Map<String, dynamic>> getJson(List<String> pathSegments) async {
    final uri = Uri(scheme: 'https', host: apiHost, pathSegments: pathSegments);

    var token = await _tokenService.getToken();
    var response = await _get(uri, token);

    if (response.statusCode == 401) {
      // Токен отвергнут раньше срока: забываем именно его, берём новый
      // и повторяем запрос РОВНО один раз.
      _tokenService.invalidate(token);
      token = await _tokenService.getToken();
      response = await _get(uri, token);
    }
    return _handle(response);
  }

  Future<http.Response> _get(Uri uri, String token) {
    return guardedRequest(
      () => _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
      _requestTimeout,
    );
  }

  Map<String, dynamic> _handle(http.Response response) {
    final status = response.statusCode;
    if (status == 200) {
      return decodeJsonObject(response);
    }
    if (status == 401) {
      // Второй 401 подряд: дело не в просроченном токене.
      throw const AuthException();
    }
    if (status == 404) {
      throw const NotFoundException();
    }
    if (status == 429) {
      throw RateLimitException(retryAfter: parseRetryAfter(response.headers));
    }
    if (status >= 500) {
      throw const ServerException();
    }
    // Остальное, в том числе 403: нельзя утверждать, что виноваты ключи.
    throw const UnexpectedResponseException();
  }
}
