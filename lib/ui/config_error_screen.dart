import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import 'steampunk/steampunk_theme.dart';

/// Shown instead of the app if `.env` could not be read or is not filled in.
///
/// This is a separate `MaterialApp`, so the localization delegates are
/// connected here again. Instead of a ready-made text, the screen gets "what
/// exactly happened" (`missingKeys` or `unreadable`) and picks the phrase in
/// the right language itself.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({
    super.key,
    this.missingKeys = const [],
    this.unreadable = false,
  });

  /// Which variables are missing from `.env`.
  final List<String> missingKeys;

  /// The `.env` file could not be read from the assets at all.
  final bool unreadable;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildSteampunkTheme(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      home: Builder(
        builder: (context) {
          final strings = AppStrings.of(context);
          final details = unreadable
              ? strings.configUnreadable
              : strings.configMissing(missingKeys);
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.configErrorTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(details, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(strings.configHint, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
