import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swifty_companion/core/api_client.dart';
import 'package:swifty_companion/core/config.dart';
import 'package:swifty_companion/core/token_service.dart';
import 'package:swifty_companion/data/photo_loader.dart';

import 'fixtures.dart';

const testConfig = AppConfig(clientId: 'test-uid', clientSecret: 'test-secret');

/// A JSON response in UTF-8 (like the real server). The body is given as bytes:
/// the `Response(String)` constructor encodes to latin1 and would fail on
/// Cyrillic.
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

/// A minimal real 1x1 PNG (so that the decoder can parse it if it wants to).
final List<int> tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

typedef UserHandler = Future<http.Response> Function(
  http.Request request,
  int attempt,
);

Future<http.Response> _okUser(http.Request request, int attempt) async {
  return jsonResponse(sampleUserJson());
}

Future<http.Response> _okPhoto(http.Request request, int attempt) async {
  return http.Response.bytes(
    tinyPng,
    200,
    headers: {'content-type': 'image/png'},
  );
}

/// A fake 42 API server: answers the token request and the profile requests.
/// It counts how many times it was asked and remembers the profile requests.
///
/// It issues tokens in order: `tok-1`, `tok-2`, ...
class FakeApi {
  FakeApi({UserHandler? onUser, UserHandler? onPhoto, this.tokenStatus = 200})
      : onUser = onUser ?? _okUser,
        onPhoto = onPhoto ?? _okPhoto;

  /// How to answer profile requests; `attempt` is the request number, from one.
  final UserHandler onUser;

  /// How to answer photo requests (CDN); by default 200 and a tiny PNG.
  final UserHandler onPhoto;

  /// The status code of the token endpoint (200 means issue a token).
  final int tokenStatus;

  int tokenCalls = 0;
  final List<http.Request> userRequests = [];
  final List<http.Request> photoRequests = [];

  /// Everything the token service and the client wrote to their debug log.
  final List<String> logs = [];

  late final MockClient client = MockClient(_handle);
  late final TokenService tokens =
      TokenService(config: testConfig, client: client, onLog: logs.add);
  late final ApiClient api = ApiClient(tokenService: tokens, client: client, onLog: logs.add);
  late final PhotoLoader photos =
      PhotoLoader(tokenService: tokens, client: client, onLog: logs.add);

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
    if (request.url.host == 'cdn.intra.42.fr') {
      photoRequests.add(request);
      return onPhoto(request, photoRequests.length);
    }
    userRequests.add(request);
    return onUser(request, userRequests.length);
  }
}
