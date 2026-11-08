import 'package:http/http.dart' as http;

import 'api_constants.dart';
import 'api_exception.dart';
import 'http_helpers.dart';
import 'token_service.dart';

/// HTTP client for the 42 API: adds the token, retries the request after a 401
/// and turns response codes into [ApiException].
///
/// It only knows "address -> JSON object". What that JSON is and what to turn
/// it into is decided by the layer above (the repository).
class ApiClient {
  ApiClient({
    required this._tokenService,
    http.Client? client,
    this._requestTimeout = const Duration(seconds: 15),
    this._onLog,
  }) : _client = client ?? http.Client();

  final TokenService _tokenService;
  final http.Client _client;
  final Duration _requestTimeout;

  /// Where to write debug messages (or `null` to stay silent). Only the
  /// address, status code, size and time are logged; the token never is.
  final void Function(String message)? _onLog;

  /// GET `https://api.intra.42.fr/<segments>` with the token. Returns a JSON
  /// object.
  ///
  /// Path parts are passed as a **list**: `Uri` encodes each part itself (a
  /// space, `?` or `/` inside a part cannot change the structure of the
  /// address).
  Future<Map<String, dynamic>> getJson(List<String> pathSegments) async {
    final uri = Uri(scheme: 'https', host: apiHost, pathSegments: pathSegments);

    var token = await _tokenService.getToken();
    var response = await _get(uri, token);

    if (response.statusCode == 401) {
      // The token was rejected before its expiry: forget exactly that one, get
      // a new one and repeat the request EXACTLY once.
      _tokenService.invalidate(token);
      token = await _tokenService.getToken();
      response = await _get(uri, token);
    }
    return _handle(response);
  }

  Future<http.Response> _get(Uri uri, String token) async {
    final watch = Stopwatch()..start();
    final response = await guardedRequest(
      () => _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
      _requestTimeout,
    );
    _onLog?.call(
      'GET ${uri.path} → ${response.statusCode}, '
      '${response.bodyBytes.length} байт, ${watch.elapsedMilliseconds} мс',
    );
    return response;
  }

  Map<String, dynamic> _handle(http.Response response) {
    final status = response.statusCode;
    if (status == 200) {
      return decodeJsonObject(response);
    }
    if (status == 401) {
      // A second 401 in a row: the cause is not an expired token.
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
    // Everything else, including 403: we cannot claim the keys are to blame.
    throw const UnexpectedResponseException();
  }
}
