import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swifty_companion/core/api_client.dart';
import 'package:swifty_companion/core/config.dart';
import 'package:swifty_companion/core/token_service.dart';

import 'fixtures.dart';

const testConfig = AppConfig(clientId: 'test-uid', clientSecret: 'test-secret');

/// JSON-ответ в UTF-8 (как у настоящего сервера). Тело отдаём байтами:
/// конструктор `Response(String)` кодирует в latin1 и упал бы на кириллице.
http.Response jsonResponse(
  Object body, [
  int status = 200,
  Map<String, String>? headers,
]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

typedef UserHandler = Future<http.Response> Function(
  http.Request request,
  int attempt,
);

Future<http.Response> _okUser(http.Request request, int attempt) async {
  return jsonResponse(sampleUserJson());
}

/// Поддельный сервер API 42: отвечает на запрос токена и на запросы профиля.
/// Считает, сколько раз его спросили, и запоминает запросы к профилю.
///
/// Токены выдаёт по порядку: `tok-1`, `tok-2`, ...
class FakeApi {
  FakeApi({UserHandler? onUser, this.tokenStatus = 200})
      : onUser = onUser ?? _okUser;

  /// Как отвечать на запросы профиля; `attempt` — номер запроса с единицы.
  final UserHandler onUser;

  /// Код ответа токен-эндпоинта (200 — выдать токен).
  final int tokenStatus;

  int tokenCalls = 0;
  final List<http.Request> userRequests = [];

  /// Всё, что токен-сервис и клиент написали в свой отладочный журнал.
  final List<String> logs = [];

  late final MockClient client = MockClient(_handle);
  late final TokenService tokens =
      TokenService(config: testConfig, client: client, onLog: logs.add);
  late final ApiClient api = ApiClient(tokenService: tokens, client: client, onLog: logs.add);

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.path == '/oauth/token') {
      tokenCalls++;
      if (tokenStatus != 200) {
        return jsonResponse({'error': 'invalid_client'}, tokenStatus);
      }
      return jsonResponse({
        'access_token': 'tok-$tokenCalls',
        'token_type': 'bearer',
        'expires_in': 7200,
      });
    }
    userRequests.add(request);
    return onUser(request, userRequests.length);
  }
}
