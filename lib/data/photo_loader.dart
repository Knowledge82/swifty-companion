import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/api_constants.dart';
import '../core/api_exception.dart';
import '../core/http_helpers.dart';
import '../core/token_service.dart';

/// A function that returns the image bytes for an address. The screen gets
/// exactly this and not the whole [PhotoLoader], so tests can plug in any stub.
typedef PhotoFetcher = Future<Uint8List> Function(String url);

/// Loads the profile photo from the intra CDN.
///
/// Why a separate class: the CDN serves images only with a token
/// (`Authorization: Bearer`), just like the API. A plain `Image.network` does
/// not add the token and gets `403`. So we download the bytes ourselves and
/// show them through `Image.memory`.
///
/// Security: the token goes **only** to hosts from [photoHosts] and only over
/// https. The photo address is taken from the server response, and without a
/// check a foreign address could steal our token.
class PhotoLoader {
  PhotoLoader({
    required this._tokenService,
    http.Client? client,
    this._requestTimeout = const Duration(seconds: 15),
    this._maxBytes = 5 * 1024 * 1024,
    this._maxCached = 20,
    this._onLog,
  }) : _client = client ?? http.Client();

  final TokenService _tokenService;
  final http.Client _client;
  final Duration _requestTimeout;
  final int _maxBytes;
  final int _maxCached;
  final void Function(String message)? _onLog;

  /// Photos that are already downloaded. A `Map` in Dart remembers insertion
  /// order, so the first key is the oldest entry and it can be dropped on
  /// overflow.
  final Map<String, Uint8List> _cache = {};

  /// Returns the image bytes. Throws [ApiException] if it did not work.
  Future<Uint8List> load(String url) async {
    final uri = _checkedUri(url);
    final cached = _cache[url];
    if (cached != null) {
      return cached;
    }

    final token = await _tokenService.getToken();
    final watch = Stopwatch()..start();
    final response = await guardedRequest(
      () => _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'image/png,image/jpeg,image/*;q=0.8',
        },
      ),
      _requestTimeout,
    );
    _onLog?.call(
      'GET ${uri.host}/…/${uri.pathSegments.last} → ${response.statusCode}, '
      '${response.bodyBytes.length} байт, ${watch.elapsedMilliseconds} мс',
    );

    final bytes = _bytesOrThrow(response);
    _cache[url] = bytes;
    if (_cache.length > _maxCached) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  /// Lets through only https to the allowed hosts with the standard port.
  /// `Uri.parse` itself deals with tricks like
  /// `https://cdn.intra.42.fr@evil.com/` (the host there will be `evil.com`,
  /// and the check rejects it).
  Uri _checkedUri(String url) {
    final uri = Uri.tryParse(url);
    final allowed = uri != null &&
        uri.scheme == 'https' &&
        photoHosts.contains(uri.host) &&
        (!uri.hasPort || uri.port == 443) &&
        uri.pathSegments.isNotEmpty;
    if (!allowed) {
      throw const UnexpectedResponseException();
    }
    return uri;
  }

  Uint8List _bytesOrThrow(http.Response response) {
    final status = response.statusCode;
    if (status == 200) {
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxBytes) {
        throw const UnexpectedResponseException();
      }
      return bytes;
    }
    // We do not try again with a new token: a 403 from the CDN may be a real
    // refusal, and extra token requests are forbidden by the rule "do not
    // create a token for every request". The photo is not critical.
    if (status == 401 || status == 403) {
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
    throw const UnexpectedResponseException();
  }
}
