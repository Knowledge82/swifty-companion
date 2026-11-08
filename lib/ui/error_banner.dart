import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../l10n/app_strings.dart';

/// A block with a request error message: an icon by kind of error + text.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error});

  final ApiException error;

  /// A `switch` over a sealed class must cover all kinds of errors: if you add
  /// a new kind in api_exception.dart, the project will not compile until you
  /// add it here too.
  IconData get _icon => switch (error) {
        NetworkException() => Icons.wifi_off,
        AuthException() => Icons.lock_outline,
        NotFoundException() => Icons.person_off_outlined,
        RateLimitException() => Icons.hourglass_empty,
        ServerException() => Icons.cloud_off,
        UnexpectedResponseException() => Icons.error_outline,
      };

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
                AppStrings.of(context).errorText(error),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
