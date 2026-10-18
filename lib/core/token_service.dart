import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'config.dart';
import 'json_reader.dart';

const String apiBaseUrl = 'https://api.intra.42.fr';

/// Выдаёт токен доступа к API 42 (OAuth2, Client Credentials).
///
/// Правила:
/// 1. Токен запрашивается **один раз** и хранится в памяти, пока не истечёт.
/// 2. Если токен просят несколько мест одновременно, запрос уходит **один**,
///    все получают один и тот же результат.
/// 3. Срок жизни берётся из `expires_in` с запасом (по умолчанию минута).
///    После истечения следующий вызов сам получает новый токен (бонус задания).
/// 4. Токен и секрет никогда не попадают в логи, сообщения об ошибках и адрес запроса.
class TokenService {
  // Приватные именованные параметры (Dart 3.12+): `this._config` означает
  // параметр с публичным именем `config`, который сразу кладётся в поле `_config`.
  TokenService({
    required this._config,
    http.Client? client,
    DateTime Function()? now,
    this._requestTimeout = const Duration(seconds: 15),
    this._safetyMargin = const Duration(seconds: 60),
    this._defaultLifetime = const Duration(hours: 1),
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final AppConfig _config;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration _requestTimeout;
  final Duration _safetyMargin;
  final Duration _defaultLifetime;

  String? _token;
  DateTime? _expiresAt;

  /// Запрос токена, который сейчас в полёте (если есть).
  Future<String>? _pending;

  /// Возвращает действующий токен: из памяти или, если его нет, из сети.
  Future<String> getToken() {
    final cached = _validCachedToken();
    if (cached != null) {
      return Future.value(cached);
    }
    // Если запрос уже идёт, присоединяемся к нему, а не создаём второй.
    return _pending ??= _fetchAndStore().whenComplete(() {
      _pending = null;
    });
  }

  /// Забывает токен, который сервер отверг (HTTP 401).
  ///
  /// Передаётся именно **тот токен, с которым сделан неудачный запрос**.
  /// Если за это время в памяти уже появился новый токен (другой запрос успел
  /// обновить), он остаётся нетронутым.
  void invalidate(String failedToken) {
    if (_token == failedToken) {
      _token = null;
      _expiresAt = null;
    }
  }

  String? _validCachedToken() {
    final token = _token;
    final expiresAt = _expiresAt;
    if (token == null || expiresAt == null) {
      return null;
    }
    if (_now().isBefore(expiresAt.subtract(_safetyMargin))) {
      return token;
    }
    return null;
  }

  Future<String> _fetchAndStore() async {
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$apiBaseUrl/oauth/token'),
        // Map превращается в форму application/x-www-form-urlencoded.
        // Секрет идёт в теле запроса, а не в адресе.
        body: {
          'grant_type': 'client_credentials',
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
        },
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw const NetworkException.timeout();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    final status = response.statusCode;
    if (status == 200) {
      return _storeFromBody(response.body);
    }
    if (status == 400 || status == 401 || status == 403) {
      throw const AuthException();
    }
    if (status == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      throw RateLimitException(
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
    }
    if (status >= 500) {
      throw const ServerException();
    }
    throw const UnexpectedResponseException();
  }

  String _storeFromBody(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const UnexpectedResponseException();
    }
    final json = readMap(decoded);
    final token = json?['access_token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException();
    }
    final seconds = readInt(json?['expires_in']);
    final lifetime =
        (seconds != null && seconds > 0) ? Duration(seconds: seconds) : _defaultLifetime;

    _token = token;
    _expiresAt = _now().add(lifetime);
    return token;
  }
}
