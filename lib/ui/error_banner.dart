import 'package:flutter/material.dart';

import '../core/api_exception.dart';

/// Блок с сообщением об ошибке запроса: значок по виду ошибки + текст.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error});

  final ApiException error;

  /// `switch` по sealed-классу обязан охватить все виды ошибок: добавишь
  /// новый вид в api_exception.dart — и пока не добавишь его сюда,
  /// проект не скомпилируется.
  IconData get _icon => switch (error) {
        NetworkException() => Icons.wifi_off,
        AuthException() => Icons.lock_outline,
        NotFoundException() => Icons.person_off_outlined,
        RateLimitException() => Icons.hourglass_empty,
        ServerException() => Icons.cloud_off,
        UnexpectedResponseException() => Icons.error_outline,
      };

  String get _text {
    final e = error;
    if (e is RateLimitException && e.retryAfter != null) {
      return '${e.message} Повторить можно через ${e.retryAfter!.inSeconds} с.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _text,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
