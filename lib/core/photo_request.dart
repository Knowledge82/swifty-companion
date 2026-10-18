import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Заголовки, с которыми приложение просит у CDN картинку профиля.
///
/// Причина: CDN интры отвечал `403 Forbidden` на запросы приложения (по всем
/// пяти адресам), а в браузере те же адреса открываются. Первая гипотеза:
/// CDN отсекает стандартный `User-Agent` Dart (`Dart/3.x (dart:io)`).
/// Поэтому представляемся как мобильный Chrome. Это обход фильтра на стороне
/// CDN, поэтому он применяется **только к картинкам** с этого CDN, а не к API.
///
/// `Accept` без `avif`/`webp` нарочно: Flutter умеет их не во всех случаях,
/// а нам нужен обычный png/jpeg.
const Map<String, String> photoRequestHeaders = {
  'User-Agent': _browserUserAgent,
  'Accept': 'image/png,image/jpeg,image/*;q=0.8',
};

const String _browserUserAgent =
    'Mozilla/5.0 (Linux; Android 14; SM-A336B) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

const Map<String, String?> _probeVariants = {
  'UA по умолчанию (Dart)': null,
  'UA приложения': 'SwiftyCompanion/1.0 (Flutter; school project)',
  'UA браузера': _browserUserAgent,
};

/// ВРЕМЕННАЯ отладочная проба (только в debug): повторяет запрос картинки
/// тремя способами и печатает, что ответил CDN (код, сервер, начало тела).
/// Нужна, чтобы по одному запуску понять, что именно CDN не нравится.
/// Когда фото заработает, этот метод и его вызов в `ProfileAvatar` удаляем.
Future<void> probePhoto(String url) async {
  if (!kDebugMode) {
    return;
  }
  for (final entry in _probeVariants.entries) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final agent = entry.value;
      if (agent != null) {
        client.userAgent = agent;
      }
      final request = await client.getUrl(Uri.parse(url));
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final chunks = await response.toList();
      final bytes = chunks.expand((chunk) => chunk).toList();
      final status = response.statusCode;
      final snippet = status == 200
          ? ''
          : ', начало ответа: "${String.fromCharCodes(bytes.take(160)).replaceAll(RegExp(r'\s+'), ' ')}"';
      debugPrint(
        'Проба фото [${entry.key}]: код $status, '
        'тип=${response.headers.contentType}, '
        'сервер=${response.headers.value('server')}, '
        '${bytes.length} байт$snippet',
      );
    } catch (e) {
      debugPrint('Проба фото [${entry.key}]: ошибка $e');
    } finally {
      client.close(force: true);
    }
  }
}
