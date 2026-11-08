import 'package:http/http.dart' as http;

import 'api_constants.dart';
import 'api_exception.dart';
import 'config.dart';
import 'http_helpers.dart';
import 'json_reader.dart';

/// Provides the access token for the 42 API (OAuth2, Client Credentials).
///
/// Rules:
/// 1. The token is requested **once** and kept in memory until it expires.
/// 2. If several places ask for the token at the same time, **one** request is
///    sent and everybody gets the same result.
/// 3. The lifetime comes from `expires_in` with a safety margin (one minute by
///    default). After expiry the next call gets a new token by itself (the
///    bonus of the assignment).
/// 4. The token and the secret never end up in logs, error messages or the
///    request address.
class TokenService {
  // Private named parameters (Dart 3.12+): `this._config` means a parameter
  // with the public name `config` that is put straight into the field
  // `_config`.
  TokenService({
    required this._config,
    http.Client? client,
    DateTime Function()? now,
    this._requestTimeout = const Duration(seconds: 15),
    this._safetyMargin = const Duration(seconds: 60),
    this._defaultLifetime = const Duration(hours: 1),
    this._onLog,
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final AppConfig _config;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration _requestTimeout;
  final Duration _safetyMargin;
  final Duration _defaultLifetime;

  /// Where to write debug messages (or `null` to stay silent). Neither the
  /// token nor the secret gets into the messages, only facts such as the
  /// lifetime.
  final void Function(String message)? _onLog;

  String? _token;
  DateTime? _expiresAt;

  /// The token request that is in flight right now (if any).
  Future<String>? _pending;

  /// Returns a valid token: from memory or, if there is none, from the network.
  Future<String> getToken() {
    final cached = _validCachedToken();
    if (cached != null) {
      return Future.value(cached);
    }
    // If a request is already running, we join it instead of creating a second
    // one.
    return _pending ??= _fetchAndStore().whenComplete(() {
      _pending = null;
    });
  }

  /// Forgets a token that the server rejected (HTTP 401).
  ///
  /// What is passed is exactly **the token the failed request was made with**.
  /// If a new token has appeared in memory in the meantime (another request
  /// managed to refresh it), it is left untouched.
  void invalidate(String failedToken) {
    if (_token == failedToken) {
      _token = null;
      _expiresAt = null;
      _onLog?.call('Токен отвергнут сервером и сброшен');
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
    final response = await guardedRequest(
      () => _client.post(
        Uri.https(apiHost, '/oauth/token'),
        // The Map becomes an application/x-www-form-urlencoded form.
        // The secret goes in the request body, not in the address.
        body: {
          'grant_type': 'client_credentials',
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
        },
      ),
      _requestTimeout,
    );

    final status = response.statusCode;
    if (status == 200) {
      return _storeFromResponse(response);
    }
    if (status == 400 || status == 401 || status == 403) {
      throw const AuthException();
    }
    if (status == 429) {
      throw RateLimitException(retryAfter: parseRetryAfter(response.headers));
    }
    if (status >= 500) {
      throw const ServerException();
    }
    throw const UnexpectedResponseException();
  }

  String _storeFromResponse(http.Response response) {
    final json = decodeJsonObject(response);
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException();
    }
    final seconds = readInt(json['expires_in']);
    final lifetime =
        (seconds != null && seconds > 0) ? Duration(seconds: seconds) : _defaultLifetime;

    _token = token;
    _expiresAt = _now().add(lifetime);
    _onLog?.call('Получен токен, срок жизни ${lifetime.inSeconds} с');
    return token;
  }
}
