import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Показывается вместо приложения, если `.env` не прочитан или не заполнен.
///
/// Это отдельное `MaterialApp`, поэтому делегаты локализации подключаются
/// здесь заново. Вместо готового текста экран получает «что именно случилось»
/// (`missingKeys` или `unreadable`) и сам подбирает фразу на нужном языке.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({
    super.key,
    this.missingKeys = const [],
    this.unreadable = false,
  });

  /// Каких переменных не хватает в `.env`.
  final List<String> missingKeys;

  /// Файл `.env` вообще не удалось прочитать из ассетов.
  final bool unreadable;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
