import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'json_reader.dart';

/// Выполняет запрос с ограничением по времени и переводит сетевые сбои
/// в [NetworkException]. Запрос передаётся функцией, чтобы исключение,
/// брошенное при самом создании запроса, тоже попало под перехват.
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

/// Читает заголовок `Retry-After` в секундах. Если его нет или он не число,
/// возвращает `null`. (Вариант заголовка с датой не поддерживаем.)
Duration? parseRetryAfter(Map<String, String> headers) {
  final seconds = int.tryParse(headers['retry-after'] ?? '');
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds);
}

/// Разбирает тело ответа как JSON-объект.
///
/// Тело декодируется как **UTF-8 явно** (`bodyBytes`), а не через `response.body`:
/// `body` берёт кодировку из заголовка `Content-Type`, а если там нет `charset`,
/// подставляет latin1, и имена вроде «José» превращаются в кракозябры.
/// Любая неожиданность (не UTF-8, не JSON, не объект) даёт [UnexpectedResponseException].
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
