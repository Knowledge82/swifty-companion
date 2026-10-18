import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/api_constants.dart';
import '../core/api_exception.dart';
import '../core/http_helpers.dart';
import '../core/token_service.dart';

/// Функция, которая по адресу возвращает байты картинки. Экран получает именно
/// её, а не весь [PhotoLoader]: так в тестах подставляется любая заглушка.
typedef PhotoFetcher = Future<Uint8List> Function(String url);

/// Загружает фото профиля с CDN интры.
///
/// Зачем отдельный класс: CDN отдаёт картинки только с токеном (`Authorization:
/// Bearer`), как и API. Обычный `Image.network` токен не добавляет и получает
/// `403`. Поэтому мы скачиваем байты сами и показываем их через `Image.memory`.
///
/// Безопасность: токен уходит **только** на хосты из [photoHosts] и только
/// по https. Адрес фото берётся из ответа сервера, и без проверки чужой адрес
/// мог бы утащить наш токен.
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

  /// Уже скачанные фото. `Map` в Dart помнит порядок вставки, поэтому первый
  /// ключ это самая старая запись и её можно выбросить при переполнении.
  final Map<String, Uint8List> _cache = {};

  /// Возвращает байты картинки. Бросает [ApiException], если не получилось.
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

  /// Пропускает только https на разрешённые хосты со стандартным портом.
  /// `Uri.parse` сам разбирает хитрости вроде `https://cdn.intra.42.fr@evil.com/`
  /// (хостом там окажется `evil.com`, и проверка его отклонит).
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
    // Повторять с новым токеном не пытаемся: 403 от CDN может быть и
    // настоящим отказом, а лишние запросы токена нам запрещены правилом
    // «не создавать токен на каждый запрос». Фото не критично.
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
