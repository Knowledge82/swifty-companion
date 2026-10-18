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

/// Один вариант пробного запроса: имя для журнала, User-Agent и заголовки.
class _ProbeVariant {
  const _ProbeVariant(this.name, {this.userAgent, this.headers = const {}});

  final String name;
  final String? userAgent;
  final Map<String, String> headers;
}

/// Заголовки, которые браузер шлёт, когда адрес картинки вводят в адресную строку.
const Map<String, String> _navigationHeaders = {
  'Accept': 'text/html,application/xhtml+xml,image/png,image/*;q=0.8,*/*;q=0.5',
  'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
  'Upgrade-Insecure-Requests': '1',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'none',
};

/// Заголовки, которые браузер шлёт, когда картинку грузит страница интры.
const Map<String, String> _embeddedHeaders = {
  'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
  'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
  'Referer': 'https://profile.intra.42.fr/',
  'Sec-Fetch-Dest': 'image',
  'Sec-Fetch-Mode': 'no-cors',
  'Sec-Fetch-Site': 'same-site',
};

const List<_ProbeVariant> _probeVariants = [
  _ProbeVariant('1 UA Dart по умолчанию'),
  _ProbeVariant('2 UA браузера', userAgent: _browserUserAgent),
  _ProbeVariant(
    '3 как адресная строка браузера',
    userAgent: _browserUserAgent,
    headers: _navigationHeaders,
  ),
  _ProbeVariant(
    '4 как картинка на странице интры (Referer profile.intra.42.fr)',
    userAgent: _browserUserAgent,
    headers: _embeddedHeaders,
  ),
  _ProbeVariant(
    '5 только Referer intra.42.fr',
    userAgent: _browserUserAgent,
    headers: {'Referer': 'https://intra.42.fr/'},
  ),
];

/// ВРЕМЕННАЯ отладочная проба (только в debug): повторяет запрос картинки
/// несколькими способами и печатает, что ответил CDN (код, сервер, кэш,
/// начало тела). Нужна, чтобы по одному запуску понять, что именно CDN
/// не нравится. Когда фото заработает, этот метод и его вызов в
/// `ProfileAvatar` удаляем.
Future<void> probePhoto(String url) async {
  if (!kDebugMode) {
    return;
  }
  for (final variant in _probeVariants) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final agent = variant.userAgent;
      if (agent != null) {
        client.userAgent = agent;
      }
      final request = await client.getUrl(Uri.parse(url));
      for (final header in variant.headers.entries) {
        request.headers.set(header.key, header.value);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final chunks = await response.toList();
      final bytes = chunks.expand((chunk) => chunk).toList();
      final status = response.statusCode;
      final snippet = status == 200
          ? ''
          : ', начало ответа: "${String.fromCharCodes(bytes.take(100)).replaceAll(RegExp(r'\s+'), ' ')}"';
      debugPrint(
        'Проба фото [${variant.name}]: код $status, '
        'тип=${response.headers.contentType}, '
        'сервер=${response.headers.value('server')}, '
        'cf-cache=${response.headers.value('cf-cache-status')}, '
        '${bytes.length} байт$snippet',
      );
    } catch (e) {
      debugPrint('Проба фото [${variant.name}]: ошибка $e');
    } finally {
      client.close(force: true);
    }
  }
}
