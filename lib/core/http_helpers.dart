import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'json_reader.dart';

/// Runs a request with a time limit and turns network failures into
/// [NetworkException]. The request is passed as a function so that an exception
/// thrown while the request is being created is caught as well.
Future<http.Response> guardedRequest(
  Future<http.Response> Function() send,
  Duration timeout,
) async {
  try {
    return await send().timeout(timeout);
  } on TimeoutException {
    throw const NetworkException.timeout();
  } on SocketException {
    throw const NetworkException();
  } on http.ClientException {
    throw const NetworkException();
  }
}

/// Reads the `Retry-After` header in seconds. If it is missing or not a number,
/// returns `null`. (The date form of the header is not supported.)
Duration? parseRetryAfter(Map<String, String> headers) {
  final seconds = int.tryParse(headers['retry-after'] ?? '');
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds);
}

/// Parses the response body as a JSON object.
///
/// The body is decoded as **UTF-8 explicitly** (`bodyBytes`), not through
/// `response.body`: `body` takes the encoding from the `Content-Type` header,
/// and if there is no `charset` there it falls back to latin1, so names like
/// "José" turn into garbage. Anything unexpected (not UTF-8, not JSON, not an
/// object) results in [UnexpectedResponseException].
Map<String, dynamic> decodeJsonObject(http.Response response) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    throw const UnexpectedResponseException();
  }
  final map = readMap(decoded);
  if (map == null) {
    throw const UnexpectedResponseException();
  }
  return map;
}
